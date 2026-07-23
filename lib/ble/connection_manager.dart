import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import '../services/log_service.dart';
import 'aes.dart';
import 'constants.dart';
import 'hex.dart';
import 'official_ble_connection_context.dart';
import 'protocol.dart';
import 'qgj_protocol.dart';
import 'tlink_protocol.dart';
import 'parser.dart';

enum ProtocolType { kks, tlink, qgj, unknown }

/// Local connection lifecycle.
///
/// Mapping to official `LoginStatus` (`tlink_ble/LoginStatus.java`):
/// - [disconnected] ≈ DISCONNECTED / BLE_STATE_OFF
/// - [connecting] / [reconnecting] ≈ CONNECTING
/// - [connected] ≈ CONNECTED / READY（GATT up, handshake in flight）
/// - [ready] ≈ **LOGIN** only when [ConnectionManager.isProtocolLoggedIn]
///
/// Do **not** treat raw [ready] alone as official LOGIN for control routing —
/// use [ConnectionManager.isProtocolLoggedIn], which also requires a protocol
/// credential (`token` after standard TokenResponse or QGJ login success).
enum ConnectionState {
  disconnected,
  connecting,
  reconnecting,

  /// GATT connected; token / QGJ login not yet confirmed.
  connected,

  /// Handshake success path; combined with token → official LOGIN.
  ready,
}

enum GattOperationPriority { high, normal, low }

/// 中文文案扩展：把 ConnectionState 枚举映射成统一的连接状态文案。
extension ConnectionStateLabel on ConnectionState {
  String get label => switch (this) {
    ConnectionState.disconnected => '未连接',
    ConnectionState.connecting => '连接中',
    ConnectionState.connected => '已连接',
    ConnectionState.ready => '已连接',
    ConnectionState.reconnecting => '正在重连',
  };
}

class ConnectionManager {
  final _log = LogService();
  BluetoothDevice? _device;
  ProtocolType _protocol = ProtocolType.unknown;
  ProtocolType _lastKnownProtocol = ProtocolType.unknown;
  OfficialBleConnectionContext? _connectionContext;
  ConnectionState _state = ConnectionState.disconnected;
  String? _token;

  /// Explicit protocol-login latch (official LoginStatus.LOGIN).
  /// Set only on KKS token + TLink LOGIN ACK / QGJ login success; cleared on teardown.
  bool _protocolLoggedIn = false;
  ModelType _model = ModelType.KKS;
  int _qgjLoginPassword = 0;
  int _qgjUserId = 0;
  BikeState? _latestBikeState;
  BikeState? _lastPublishedBikeState;
  bool _disposed = false;

  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _feb1Char;
  BluetoothCharacteristic? _feb2Char;
  BluetoothCharacteristic? _feb3Char;
  BluetoothCharacteristic? _fe02Char;
  BluetoothCharacteristic? _fe03Char;
  BluetoothCharacteristic? _fcc1Char;
  BluetoothCharacteristic? _fcc2Char;
  BluetoothCharacteristic? _fbb1Char;
  BluetoothCharacteristic? _fbb2Char;

  Timer? _heartbeatInitialTimer;
  Timer? _heartbeatTimer;
  Timer? _readyWatchdog;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<List<int>>? _gpsNotifySub;
  StreamSubscription<List<int>>? _fbb2NotifySub;

  bool _userDisconnected = false;
  bool _reconnecting = false;
  bool _reconnectCancelled = false;
  bool _disconnectHandled = false;
  int _reconnectAttempt = 0;
  static const _maxReconnectAttempts = 8;

  Completer<bool>? _cmdAckCompleter;
  Completer<bool>? _standardCommandAckCompleter;
  String? _standardPendingCommandType;
  Completer<BikeState?>? _standardStateCompleter;
  Completer<TLinkInductionStatusResponse?>? _tlinkInductionStatusCompleter;
  Completer<bool>? _tlinkInductionSetCompleter;
  Completer<bool>? _tlinkProximityDistanceCompleter;
  final Map<int, Completer<QgjResponse?>> _qgjResponseCompleters = {};
  final Map<GattOperationPriority, List<_QueuedGattOperation<dynamic>>>
  _gattPendingByPriority = {
    for (final priority in GattOperationPriority.values) priority: [],
  };
  _QueuedGattOperation<dynamic>? _activeGattOperation;
  bool _gattRunning = false;

  final _stateController = StreamController<ConnectionState>.broadcast();
  final _responseController = StreamController<ParsedResponse>.broadcast();
  final _bikeStateController = StreamController<BikeState?>.broadcast();
  final _fbb2Controller = StreamController<String>.broadcast();

  Stream<ConnectionState> get stateStream => _stateController.stream;
  Stream<ParsedResponse> get responseStream => _responseController.stream;
  Stream<BikeState?> get bikeStateStream => _bikeStateController.stream;
  Stream<String> get fbb2Stream => _fbb2Controller.stream;
  ConnectionState get state => _state;
  ProtocolType get protocol => _protocol;
  ProtocolType get lastKnownProtocol => _lastKnownProtocol;
  String? get token => _token;
  BluetoothDevice? get device => _device;
  OfficialBleConnectionContext? get connectionContext => _connectionContext;
  BikeState? get latestBikeState => _latestBikeState;
  int get qgjLoginPassword => _qgjLoginPassword;
  int get qgjUserId => _qgjUserId;
  BluetoothCharacteristic? get fcc1Char => _fcc1Char;
  BluetoothCharacteristic? get fcc2Char => _fcc2Char;
  BluetoothCharacteristic? get fbb1Char => _fbb1Char;
  BluetoothCharacteristic? get fbb2Char => _fbb2Char;

  /// Official `LoginStatus.LOGIN` equivalent for control routing.
  ///
  /// True only when the connection is in [ConnectionState.ready] **and** a
  /// protocol credential exists (`token` from standard TokenResponse, or the
  /// QGJ login marker). GATT-only [ConnectionState.connected] is never LOGIN.
  bool get isProtocolLoggedIn =>
      _protocolLoggedIn && _state == ConnectionState.ready && _token != null;

  /// Reason when [isProtocolLoggedIn] is false — feed to channel UI/resolver.
  String get protocolLoginUnavailableReason {
    if (isProtocolLoggedIn) return '';
    return switch (_state) {
      ConnectionState.disconnected => '蓝牙未连接',
      ConnectionState.connecting => '蓝牙连接中',
      ConnectionState.reconnecting => '蓝牙正在重连',
      ConnectionState.connected => '蓝牙未完成协议登录',
      ConnectionState.ready => '蓝牙未完成协议登录',
    };
  }

  void setModel(ModelType model) => _model = model;

  /// Set the selected official vehicle before starting a BLE connection.
  /// Credentials remain in memory for this session only.
  void setOfficialConnectionContext(OfficialBleConnectionContext? context) {
    _connectionContext = context;
    final cipher = context?.cipherModel;
    _model = cipher ?? ModelType.KKS;
    if (context?.stack == OfficialBleStack.qgj) {
      _qgjLoginPassword = context?.selectedPassword ?? 0;
      _qgjUserId = context?.userIdValue ?? 0;
    } else if (context == null) {
      _qgjLoginPassword = 0;
      _qgjUserId = 0;
    }
  }

  void setQgjCredentials({int? password, int? userId}) {
    _qgjLoginPassword = password ?? 0;
    _qgjUserId = userId ?? 0;
  }

  Future<T> runGattOperation<T>(
    Future<T> Function() operation, {
    GattOperationPriority priority = GattOperationPriority.normal,
  }) {
    if (_disposed) {
      return Future<T>.error(StateError('ConnectionManager disposed'));
    }
    final queued = _QueuedGattOperation<T>(operation, priority);
    _gattPendingByPriority[priority]!.add(queued);
    _drainGattQueue();
    return queued.completer.future;
  }

  void _drainGattQueue() {
    if (_gattRunning || !_hasPendingGattOperations) return;
    _gattRunning = true;
    unawaited(
      () async {
        while (_hasPendingGattOperations) {
          final queued = _takeNextGattOperation();
          _activeGattOperation = queued;
          try {
            final result = await queued.operation().timeout(
              BleTimings.gattOperationTimeout,
              onTimeout: () =>
                  throw TimeoutException('GATT operation timed out after 30s'),
            );
            if (!queued.completer.isCompleted) {
              queued.completer.complete(result);
            }
          } catch (e, st) {
            if (!queued.completer.isCompleted) {
              queued.completer.completeError(e, st);
            }
          } finally {
            if (identical(_activeGattOperation, queued)) {
              _activeGattOperation = null;
            }
          }
        }
      }().whenComplete(() {
        _gattRunning = false;
        if (_hasPendingGattOperations) _drainGattQueue();
      }),
    );
  }

  bool get _hasPendingGattOperations =>
      _gattPendingByPriority.values.any((queue) => queue.isNotEmpty);

  _QueuedGattOperation<dynamic> _takeNextGattOperation() {
    for (final priority in GattOperationPriority.values) {
      final queue = _gattPendingByPriority[priority]!;
      if (queue.isNotEmpty) {
        return queue.removeAt(0);
      }
    }
    throw StateError('No pending GATT operation');
  }

  Future<List<int>?> readFeb3() {
    return runGattOperation(() async {
      if (_state != ConnectionState.ready || _feb3Char == null) return null;
      return _feb3Char!.read();
    }, priority: GattOperationPriority.low);
  }

  Future<BikeState?> refreshBikeState() async {
    if (_protocol == ProtocolType.kks) {
      final writeChar = _writeChar;
      final token = _token;
      if (_state != ConnectionState.ready ||
          writeChar == null ||
          token == null) {
        return null;
      }

      return runGattOperation(() async {
        final previous = _standardStateCompleter;
        if (previous != null && !previous.isCompleted) {
          previous.complete(null);
        }
        final completer = Completer<BikeState?>();
        _standardStateCompleter = completer;
        try {
          final frame = buildCommand(
            _model.aesKey,
            CommandCode.readState,
            token,
          );
          await writeChar.write(frame.toList(), withoutResponse: false);
          return await completer.future.timeout(
            BleTimings.commandAckTimeout,
            onTimeout: () => null,
          );
        } finally {
          if (identical(_standardStateCompleter, completer)) {
            _standardStateCompleter = null;
          }
        }
      }, priority: GattOperationPriority.high);
    }

    final data = await readFeb3();
    if (data == null || data.isEmpty) return null;
    final state = BikeState.fromFeb3(data);
    if (state != null) {
      _publishBikeState(state);
    }
    return state;
  }

  Future<void> connect(
    BluetoothDevice device, {
    OfficialBleConnectionContext? context,
  }) async {
    if (_disposed) {
      throw StateError('ConnectionManager disposed');
    }

    // C-1: Cancel any ongoing reconnect loop
    _reconnectCancelled = true;
    if (_reconnecting) {
      // Give the reconnect loop a chance to exit
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    // H-1: Guard against double-invocation
    if (_state == ConnectionState.connecting ||
        _state == ConnectionState.connected ||
        _state == ConnectionState.ready) {
      _log.ble('connect() ignored: already in state $_state');
      return;
    }

    _userDisconnected = false;
    _reconnecting = false;
    _reconnectAttempt = 0;
    _disconnectHandled = false;
    await _clearRuntimeResources(disconnectDevice: false);

    if (context != null) setOfficialConnectionContext(context);

    _device = device;
    _lastKnownProtocol = ProtocolType.unknown;
    _setState(ConnectionState.connecting);
    _reconnectCancelled = false; // C-1: Reset after setup
    _log.ble('连接设备 ${device.platformName}', detail: device.remoteId.toString());

    try {
      // Subscribe BEFORE connecting to not miss early disconnect events
      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          unawaited(_onDisconnected());
        }
      });

      await _connectDeviceWithRetry(
        device,
        timeout: BleTimings.connectTimeout,
        attempts: _connectionContext?.stack == OfficialBleStack.tlink ? 6 : 3,
        retryDelay: _connectionContext?.stack == OfficialBleStack.qgj
            ? const Duration(milliseconds: 300)
            : const Duration(milliseconds: 500),
      );

      _setState(ConnectionState.connected);

      await _ensureKksBond(device);
      await _requestQgjMtu(device);
      await Future<void>.delayed(BleTimings.serviceSetupDelay);
      await _discoverAndSetup();
    } catch (e) {
      _log.ble('连接失败', detail: e.toString(), level: LogLevel.error);
      await _clearRuntimeResources(disconnectDevice: true);
      _resetCharacteristics();
      _setState(ConnectionState.disconnected);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _userDisconnected = true;
    _reconnecting = false;
    _reconnectCancelled = true;
    _reconnectAttempt = 0;
    _cancelHeartbeat();
    _completePendingOperations(StateError('QGJ disconnected'));
    _completePendingGattOperations(StateError('Disconnected by user'));
    await _clearRuntimeResources(disconnectDevice: false);
    try {
      await _device?.disconnect();
    } catch (e) {
      _log.ble('用户断开设备失败', detail: e.toString(), level: LogLevel.debug);
    } finally {
      // Always clear local session so switch-vehicle cannot keep A while selecting B.
      _resetCharacteristics();
      _reset();
    }
  }

  Future<void> _discoverAndSetup() async {
    try {
      final services = await _device!.discoverServices();

      _log.ble(
        '发现 ${services.length} 个服务',
        detail: services.map((s) => s.serviceUuid.toString()).join(', '),
      );

      final hasFeb0 = services.any(
        (s) => s.serviceUuid.toString().contains('feb0'),
      );
      final hasFee5 = services.any(
        (s) => s.serviceUuid.toString().contains('fee5'),
      );

      final expectedStack = _connectionContext?.stack;
      if (expectedStack == OfficialBleStack.qgj && hasFeb0 ||
          expectedStack == null && hasFeb0) {
        _protocol = ProtocolType.qgj;
        _lastKnownProtocol = _protocol;
        _log.ble('识别协议: QGJ (feb0)', level: LogLevel.info);
        await _setupQgj(services);
      } else if (hasFee5 &&
          (expectedStack == null ||
              expectedStack == OfficialBleStack.kks ||
              expectedStack == OfficialBleStack.tlink)) {
        _protocol = expectedStack == OfficialBleStack.tlink
            ? ProtocolType.tlink
            : ProtocolType.kks;
        _lastKnownProtocol = _protocol;
        if (_protocol == ProtocolType.tlink) {
          await _setupTLink(services);
        } else {
          await _setupKks(services);
        }
      } else {
        _protocol = ProtocolType.unknown;
        _log.ble('未识别协议', level: LogLevel.warning);
        if (expectedStack != null) {
          throw StateError(
            'GATT services do not match ${expectedStack.name} model',
          );
        }
      }
    } catch (e) {
      _log.ble('服务发现/设置失败', detail: e.toString(), level: LogLevel.error);
      await _clearRuntimeResources(disconnectDevice: true);
      _resetCharacteristics();
      _setState(ConnectionState.disconnected);
      rethrow;
    }
  }

  Future<void> _setupKks(List<BluetoothService> services) async {
    final service = services.firstWhere(
      (s) => s.serviceUuid.toString().contains('fee5'),
    );

    for (final c in service.characteristics) {
      final uuid = c.characteristicUuid.toString();
      if (uuid.contains('feb5')) _writeChar = c;
      if (uuid.contains('feb6')) _notifyChar = c;
    }

    if (_notifyChar == null || _writeChar == null) {
      throw StateError('KKS fee5 characteristics are incomplete');
    }
    await _enableNotifyOrIndicate(_notifyChar!);
    _notifySub = _notifyChar!.onValueReceived.listen(_onStandardNotify);
    final tokenReq = buildTokenRequest(_model.aesKey);
    await runGattOperation(
      () => _writeChar!.write(tokenReq.toList(), withoutResponse: false),
      priority: GattOperationPriority.high,
    );
  }

  Future<void> _setupTLink(List<BluetoothService> services) async {
    final service = services.firstWhere(
      (s) => s.serviceUuid.toString().contains('fee5'),
    );
    final hasDeviceInfo = services.any(
      (s) => s.serviceUuid.toString().contains('180a'),
    );
    if (!hasDeviceInfo ||
        !services.any((s) => s.serviceUuid.toString().contains('fcc0'))) {
      throw StateError('TLink GATT services are incomplete');
    }

    for (final c in service.characteristics) {
      final uuid = c.characteristicUuid.toString();
      if (uuid.contains('feb5')) _writeChar = c;
      if (uuid.contains('feb6')) _notifyChar = c;
    }
    await _subscribeFcc0(services);
    await _subscribeOptionalTLinkServices(services);

    if (_notifyChar == null || _writeChar == null) {
      throw StateError('TLink fee5 characteristics are incomplete');
    }
    await _enableNotifyOrIndicate(_notifyChar!);
    _notifySub = _notifyChar!.onValueReceived.listen(_onStandardNotify);
    final tokenReq = buildTLinkTokenRequest(_model.aesKey);
    await runGattOperation(
      () => _writeChar!.write(tokenReq.toList(), withoutResponse: false),
      priority: GattOperationPriority.high,
    );
  }

  Future<void> _subscribeOptionalTLinkServices(
    List<BluetoothService> services,
  ) async {
    for (final service in services) {
      final serviceUuid = service.serviceUuid.toString();
      if (!serviceUuid.contains('2000') &&
          !serviceUuid.contains('7000') &&
          !serviceUuid.contains('fe01')) {
        continue;
      }
      for (final characteristic in service.characteristics) {
        if (!characteristic.properties.notify &&
            !characteristic.properties.indicate) {
          continue;
        }
        try {
          await _enableNotifyOrIndicate(characteristic);
        } catch (e) {
          _log.ble(
            '订阅 TLink 可选特征失败',
            detail: characteristic.characteristicUuid.toString(),
            level: LogLevel.debug,
          );
        }
      }
    }
  }

  Future<void> _setupQgj(List<BluetoothService> services) async {
    final service = services.firstWhere(
      (s) => s.serviceUuid.toString().contains('feb0'),
    );

    for (final c in service.characteristics) {
      final uuid = c.characteristicUuid.toString();
      if (uuid.contains('feb1')) _feb1Char = c;
      if (uuid.contains('feb2')) _feb2Char = c;
      if (uuid.contains('feb3')) _feb3Char = c;
    }

    _log.ble(
      'QGJ characteristics',
      detail:
          'feb1=${_feb1Char != null}, feb2=${_feb2Char != null}, feb3=${_feb3Char != null}',
    );

    // 订阅 fcc0 服务的 fcc1/fbb1/fcc2/fbb2（原 app 必须步骤，否则设备超时断开）
    await _subscribeFcc0(services);
    await _subscribeQgjGps(services);

    if (_feb2Char != null) {
      await _enableNotifyOrIndicate(_feb2Char!, forceIndications: true);
      _notifySub = _feb2Char!.onValueReceived.listen(_onQgjNotify);
    }

    if (_feb1Char != null) {
      final context = _connectionContext;
      if (context != null && !context.hasQgjCredentials) {
        throw StateError('QGJ login credentials are unavailable');
      }
      final loginFrame = buildQgjLoginFrame(
        password: _qgjLoginPassword,
        userId: _qgjUserId,
      );
      await runGattOperation(
        () => _feb1Char!.write(loginFrame.toList(), withoutResponse: false),
        priority: GattOperationPriority.high,
      );
    }
  }

  Future<void> _connectDeviceWithRetry(
    BluetoothDevice device, {
    required Duration timeout,
    required int attempts,
    required Duration retryDelay,
  }) async {
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        await device.connect(timeout: timeout, mtu: null);
        return;
      } catch (e) {
        if (attempt == attempts) rethrow;
        _log.ble(
          '连接失败，短暂重试 $attempt/$attempts',
          detail: e.toString(),
          level: LogLevel.debug,
        );
        await _recoverFailedConnect(device, e);
        await Future<void>.delayed(retryDelay);
      }
    }
    throw StateError('连接失败');
  }

  Future<void> _ensureKksBond(BluetoothDevice device) async {
    if (_connectionContext?.stack != OfficialBleStack.kks ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      final bonded = await device.bondState.first;
      if (bonded != BluetoothBondState.bonded) {
        await device.createBond();
      }
    } catch (e) {
      _log.ble('KKS 配对失败', detail: e.toString(), level: LogLevel.warning);
      rethrow;
    }
  }

  Future<void> _requestQgjMtu(BluetoothDevice device) async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        _connectionContext?.stack != OfficialBleStack.qgj) {
      return;
    }
    try {
      final mtu = await device.requestMtu(BleTimings.qgjRequestedMtu);
      _log.ble('MTU 已请求', detail: mtu.toString(), level: LogLevel.debug);
    } catch (e) {
      _log.ble('MTU 请求失败', detail: e.toString(), level: LogLevel.debug);
    }
  }

  Future<void> _enableNotifyOrIndicate(
    BluetoothCharacteristic characteristic, {
    bool forceIndications = false,
  }) async {
    await runGattOperation(
      () => characteristic.setNotifyValue(
        true,
        forceIndications:
            defaultTargetPlatform == TargetPlatform.android &&
            (forceIndications ||
                (characteristic.properties.indicate &&
                    !characteristic.properties.notify)),
      ),
      priority: GattOperationPriority.high,
    );
  }

  Future<void> _subscribeFcc0(List<BluetoothService> services) async {
    final fcc0Service = services.where(
      (s) => s.serviceUuid.toString().contains('fcc0'),
    );
    if (fcc0Service.isEmpty) {
      _log.ble('fcc0 服务未找到', level: LogLevel.warning);
      return;
    }

    final service = fcc0Service.first;
    int subscribed = 0;
    for (final c in service.characteristics) {
      final uuid = c.characteristicUuid.toString();
      if (uuid.contains('fcc1')) _fcc1Char = c;
      if (uuid.contains('fcc2')) _fcc2Char = c;
      if (uuid.contains('fbb1')) _fbb1Char = c;
      if (uuid.contains('fbb2')) _fbb2Char = c;
      if (c.properties.notify || c.properties.indicate) {
        try {
          await _enableNotifyOrIndicate(c);
          subscribed++;
        } catch (e) {
          _log.ble('订阅 $uuid 失败', detail: e.toString(), level: LogLevel.debug);
        }
      }
    }
    _log.ble(
      'fcc0 已订阅 $subscribed 个特征',
      detail:
          'fcc1=${_fcc1Char != null}, fcc2=${_fcc2Char != null}, fbb1=${_fbb1Char != null}, fbb2=${_fbb2Char != null}',
      level: LogLevel.info,
    );
    if (_fbb2Char != null) {
      _fbb2NotifySub = _fbb2Char!.onValueReceived.listen(_onFbb2Notify);
    }
  }

  Future<void> _subscribeQgjGps(List<BluetoothService> services) async {
    final fe01Service = services.where(
      (s) => s.serviceUuid.toString().contains('fe01'),
    );
    if (fe01Service.isEmpty) return;

    for (final c in fe01Service.first.characteristics) {
      final uuid = c.characteristicUuid.toString();
      if (uuid.contains('fe02')) _fe02Char = c;
      if (uuid.contains('fe03')) _fe03Char = c;
    }

    final canWriteGps =
        _fe02Char?.properties.writeWithoutResponse == true ||
        _fe02Char?.properties.write == true;
    final canNotifyGps = _fe03Char?.properties.notify == true;
    if (!canWriteGps || !canNotifyGps || _fe03Char == null) {
      _log.ble(
        'fe01 GPS 服务不完整',
        detail: 'fe02=$canWriteGps, fe03=$canNotifyGps',
        level: LogLevel.debug,
      );
      return;
    }

    try {
      await _enableNotifyOrIndicate(_fe03Char!);
      _gpsNotifySub = _fe03Char!.onValueReceived.listen(_onQgjGpsNotify);
      _log.ble('fe03 GPS 通知已订阅', level: LogLevel.info);
    } catch (e) {
      _log.ble('fe03 GPS 通知订阅失败', detail: e.toString(), level: LogLevel.debug);
    }
  }

  void _onStandardNotify(List<int> value) {
    if (_disposed) return;
    final data = Uint8List.fromList(value);
    _log.ble('← 收到数据', detail: bytesToSpacedHex(data));
    if (_protocol == ProtocolType.tlink) {
      final response = parseTLinkResponse(_model.aesKey, data);
      unawaited(_handleTLinkResponse(response));
      return;
    }
    final response = parseResponse(_model.aesKey, data);
    _addResponse(response);

    _handleStandardResponse(response);
  }

  Future<void> _handleTLinkResponse(TLinkResponse response) async {
    if (response is TLinkTokenResponse) {
      final context = _connectionContext;
      final writeChar = _writeChar;
      if (context == null ||
          !context.hasTLinkCredentials ||
          writeChar == null) {
        await _rejectProtocolLogin('TLink 登录凭据缺失');
        return;
      }
      _acceptTLinkToken(response.token);
      final loginFrame = buildTLinkLoginFrame(
        keyHex: _model.aesKey,
        password: context.selectedPassword!,
        userId: context.userIdValue!,
        token: response.token,
      );
      await runGattOperation(
        () => writeChar.write(loginFrame.toList(), withoutResponse: false),
        priority: GattOperationPriority.high,
      );
      return;
    }

    if (response is TLinkLoginResponse) {
      if (!_acceptTLinkLogin(response.success)) {
        await _rejectProtocolLogin('TLink 登录被车辆拒绝');
      }
      return;
    }

    if (response is TLinkInductionStatusResponse) {
      final completer = _tlinkInductionStatusCompleter;
      _tlinkInductionStatusCompleter = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete(response);
      }
      return;
    }

    if (response is TLinkInductionSetResponse) {
      final completer = _tlinkInductionSetCompleter;
      _tlinkInductionSetCompleter = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete(response.success);
      }
      return;
    }

    if (response is TLinkProximityDistanceSetResponse) {
      final completer = _tlinkProximityDistanceCompleter;
      _tlinkProximityDistanceCompleter = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete(response.success);
      }
      return;
    }

    if (response is TLinkCommandResponse) {
      final commandType = switch (response.commandType) {
        '20' => CommandCode.lock.code,
        '21' => CommandCode.unlock.code,
        '22' => CommandCode.powerOn.code,
        '23' => CommandCode.powerOff.code,
        '24' => CommandCode.openSeat.code,
        '25' => CommandCode.find.code,
        _ => response.commandType,
      };
      _handleStandardResponse(
        CommandResponse(
          response.raw,
          commandType: commandType,
          statusCode: response.statusCode,
          success: response.success,
        ),
      );
    }
  }

  void _acceptTLinkToken(String token) {
    _token = token;
    _protocolLoggedIn = false;
  }

  bool _acceptTLinkLogin(bool success) {
    final token = _token;
    if (!success || token == null) return false;
    _markProtocolLoggedIn(token);
    return true;
  }

  Future<void> _rejectProtocolLogin(String reason) async {
    _log.ble(reason, level: LogLevel.error);
    _clearProtocolLogin();
    _userDisconnected = true;
    await _clearRuntimeResources(disconnectDevice: true);
    _resetCharacteristics();
    _setState(ConnectionState.disconnected);
  }

  void _handleStandardResponse(ParsedResponse response) {
    if (response is StateResponse) {
      final stateCompleter = _standardStateCompleter;
      if (response.bikeState != null) {
        _publishBikeState(response.bikeState);
      }
      if (stateCompleter != null && !stateCompleter.isCompleted) {
        stateCompleter.complete(response.bikeState);
      }
      return;
    }

    if (response is TokenResponse) {
      _markProtocolLoggedIn(response.token);
      return;
    }

    if (response is CommandResponse) {
      _applyStandardCommandState(response);
      final expected = _standardPendingCommandType;
      if (expected == null || expected != response.commandType) return;
      final completer = _standardCommandAckCompleter;
      _standardCommandAckCompleter = null;
      _standardPendingCommandType = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete(response.success);
      }
    }
  }

  void _applyStandardCommandState(CommandResponse response) {
    if (!response.success) return;
    final current = _latestBikeState;
    final next = switch (response.commandType.toUpperCase()) {
      '01' => BikeState(
        isLocked: true,
        isPowerOn: false,
        isMuted: current?.isMuted ?? false,
        voltage: current?.voltage,
        temperature: current?.temperature,
        batteryPercent: current?.batteryPercent,
        signalStrength: current?.signalStrength,
        faultMotor: current?.faultMotor ?? false,
        faultController: current?.faultController ?? false,
        faultBrake: current?.faultBrake ?? false,
        faultLowVoltage: current?.faultLowVoltage ?? false,
      ),
      '02' =>
        current == null
            ? const BikeState(isLocked: false, isPowerOn: false)
            : current.copyWith(isLocked: false),
      '06' =>
        current == null
            ? const BikeState(isLocked: false, isPowerOn: true)
            : current.copyWith(isLocked: false, isPowerOn: true),
      '07' =>
        current == null
            ? const BikeState(isLocked: false, isPowerOn: false)
            : current.copyWith(isPowerOn: false),
      _ => null,
    };
    if (next != null && (current == null || next != current)) {
      _publishBikeState(next);
    }
  }

  void _onQgjNotify(List<int> value) {
    if (_disposed) return;
    final data = Uint8List.fromList(value);
    _log.ble('← QGJ 响应', detail: bytesToSpacedHex(data));
    final response = parseQgjResponse(data);
    if (response == null) return;

    if (response.cmdId == QgjCommandIds.login && response.success) {
      _log.ble('QGJ 登录成功', level: LogLevel.info);
      _markProtocolLoggedIn('qgj');
      _startHeartbeat();
    } else if (response.cmdId == QgjCommandIds.setStatus) {
      final completer = _cmdAckCompleter;
      _cmdAckCompleter = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete(response.success);
      }
    }

    final completer = _qgjResponseCompleters.remove(response.cmdId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
    }
  }

  void _onQgjGpsNotify(List<int> value) {
    if (_disposed) return;
    if (value.isEmpty) return;
    _log.ble(
      '← QGJ GPS 通知',
      detail: bytesToSpacedHex(value),
      level: LogLevel.debug,
    );
  }

  void _startHeartbeat() {
    _cancelHeartbeat();
    _log.ble(
      '心跳启动 feb3=${_feb3Char != null}',
      detail: 'interval=${BleTimings.qgjStatusPollInterval.inSeconds}s',
      level: LogLevel.info,
    );
    if (_feb3Char == null) {
      _log.ble('feb3 未找到，无法维持心跳', level: LogLevel.error);
      return;
    }
    int failCount = 0;
    bool heartbeatInFlight = false;

    void tick() {
      if (_state != ConnectionState.ready || _feb3Char == null) return;
      if (heartbeatInFlight) return;
      heartbeatInFlight = true;
      unawaited(
        readFeb3()
            .then((data) {
              failCount = 0;
              if (data != null && data.isNotEmpty) {
                final state = BikeState.fromFeb3(data);
                if (state != null) {
                  _publishBikeState(state);
                }
              }
            })
            .catchError((Object e) {
              failCount++;
              if (failCount == 3) {
                _log.ble(
                  '心跳连续失败 3 次',
                  detail: e.toString(),
                  level: LogLevel.warning,
                );
              }
              if (failCount >= 5 && _state == ConnectionState.ready) {
                _log.ble('心跳持续失败 ($failCount 次)，触发重连', level: LogLevel.warning);
                _cancelHeartbeat();
                // scheduleMicrotask: _onDisconnected performs async cleanup
                // (cancel subs, _attemptReconnect). Running it inline inside
                // the Timer callback would route those futures through the
                // Timer zone, swallowing any thrown exceptions.
                scheduleMicrotask(() {
                  unawaited(
                    _onDisconnected().catchError((Object e, StackTrace st) {
                      _log.ble(
                        'Disconnect handler error: $e',
                        level: LogLevel.error,
                      );
                    }),
                  );
                });
              }
            })
            .whenComplete(() => heartbeatInFlight = false),
      );
    }

    _heartbeatInitialTimer = Timer(BleTimings.heartbeatInitialDelay, () {
      _heartbeatInitialTimer = null;
      tick();
    });
    _heartbeatTimer = Timer.periodic(
      BleTimings.qgjStatusPollInterval,
      (_) => tick(),
    );
  }

  void _cancelHeartbeat() {
    _heartbeatInitialTimer?.cancel();
    _heartbeatInitialTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _publishBikeState(BikeState? state) {
    if (state == _lastPublishedBikeState) return;
    _latestBikeState = state;
    _lastPublishedBikeState = state;
    if (!_disposed) {
      _bikeStateController.add(state);
    }
  }

  void _clearBikeState() {
    if (_latestBikeState == null && _lastPublishedBikeState == null) return;
    _latestBikeState = null;
    _lastPublishedBikeState = null;
    if (!_disposed) {
      _bikeStateController.add(null);
    }
  }

  @visibleForTesting
  void publishBikeStateForTest(BikeState? state) => _publishBikeState(state);

  @visibleForTesting
  void resetCharacteristicsForTest() => _resetCharacteristics();

  @visibleForTesting
  Future<bool> createPendingCommandAckForTest() {
    final completer = Completer<bool>();
    _cmdAckCompleter = completer;
    return completer.future;
  }

  @visibleForTesting
  Future<bool> createPendingStandardCommandAckForTest(String commandType) {
    final completer = Completer<bool>();
    _standardCommandAckCompleter = completer;
    _standardPendingCommandType = commandType.toUpperCase();
    return completer.future;
  }

  @visibleForTesting
  void handleStandardResponseForTest(ParsedResponse response) {
    _handleStandardResponse(response);
  }

  @visibleForTesting
  void acceptTLinkTokenForTest(String token) {
    _protocol = ProtocolType.tlink;
    _state = ConnectionState.connected;
    _acceptTLinkToken(token);
  }

  @visibleForTesting
  bool acceptTLinkLoginForTest(bool success) => _acceptTLinkLogin(success);

  @visibleForTesting
  Future<QgjResponse?> createPendingQgjResponseForTest(int cmdId) {
    final completer = Completer<QgjResponse?>();
    _qgjResponseCompleters[cmdId] = completer;
    return completer.future;
  }

  @visibleForTesting
  void enterConnectedForTest() => _setState(ConnectionState.connected);

  /// Simulate official LOGIN (ready + protocol credential).
  @visibleForTesting
  void enterReadyForTest({String token = 'test-token'}) {
    _markProtocolLoggedIn(token);
  }

  /// Simulate a QGJ session that has a bound device and is ready.
  ///
  /// Attaches a fake device so the reconnect branch in [_onDisconnected]
  /// is reachable (it requires `_device != null`), and sets `_protocol`
  /// to QGJ so the "no auto-reconnect" guard can actually be exercised.
  @visibleForTesting
  void enterReadyForQgjWithDeviceForTest({String deviceId = 'qgj-test'}) {
    _device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
    _protocol = ProtocolType.qgj;
    _markProtocolLoggedIn('qgj');
  }

  /// Simulate GATT-up without protocol login (must NOT route as bleReady).
  @visibleForTesting
  void enterConnectedWithoutLoginForTest() {
    _protocolLoggedIn = false;
    _token = null;
    _setState(ConnectionState.connected);
  }

  /// Bind a fake remote device for switch-vehicle / target tests.
  @visibleForTesting
  void attachDeviceForTest(
    BluetoothDevice device, {
    ConnectionState state = ConnectionState.ready,
    String token = 'test-token',
  }) {
    _device = device;
    if (state == ConnectionState.ready) {
      _markProtocolLoggedIn(token);
    } else {
      _protocolLoggedIn = false;
      _token = null;
      _setState(state);
    }
  }

  @visibleForTesting
  bool get readyWatchdogActiveForTest => _readyWatchdog?.isActive ?? false;

  /// P0-1: 测试钩子 —— 模拟设备端断连守卫的标记与复位。
  ///
  /// `_disconnectHandled` 在 `_onDisconnected()` 首次进入时置 true，
  /// 在 `connect()` 与 `_attemptReconnect()` 成功路径复位。
  /// 此钩子让单元测试无需真实 BLE 设备即可验证复位语义。
  @visibleForTesting
  bool get disconnectHandledForTest => _disconnectHandled;

  @visibleForTesting
  bool markDisconnectHandledForTest() => _markDisconnectHandled();

  @visibleForTesting
  void resetDisconnectHandledForTest() => _disconnectHandled = false;

  @visibleForTesting
  Future<void> handleDisconnectedForTest() => _onDisconnected();

  Future<bool> sendCommand(CommandCode cmd) async {
    if (_state != ConnectionState.ready) return false;

    _log.operation('发送指令: ${cmd.label}', detail: 'code=${cmd.code}');

    if (_protocol == ProtocolType.kks || _protocol == ProtocolType.tlink) {
      if (_writeChar == null || _token == null) return false;
      final frame = _protocol == ProtocolType.tlink
          ? buildTLinkCommand(
              keyHex: _model.aesKey,
              command: cmd,
              token: _token!,
            )
          : buildCommand(_model.aesKey, cmd, _token!);
      return runGattOperation(() async {
        final previous = _standardCommandAckCompleter;
        if (previous != null && !previous.isCompleted) {
          previous.complete(false);
        }
        final completer = Completer<bool>();
        _standardCommandAckCompleter = completer;
        _standardPendingCommandType = cmd.code.toUpperCase();
        try {
          await _writeChar!.write(frame.toList(), withoutResponse: false);
          return await completer.future.timeout(
            BleTimings.commandAckTimeout,
            onTimeout: () => false,
          );
        } finally {
          if (identical(_standardCommandAckCompleter, completer)) {
            _standardCommandAckCompleter = null;
            _standardPendingCommandType = null;
          }
        }
      }, priority: GattOperationPriority.high);
    } else if (_protocol == ProtocolType.qgj) {
      if (_feb1Char == null) return false;
      final frame = buildQgjControlFrame(cmd);
      if (frame == null) return false;

      final success = await runGattOperation(() async {
        final previous = _cmdAckCompleter;
        if (previous != null && !previous.isCompleted) {
          previous.complete(false);
        }
        final completer = Completer<bool>();
        _cmdAckCompleter = completer;
        try {
          await _feb1Char!.write(frame.toList(), withoutResponse: false);
          return await completer.future.timeout(
            BleTimings.commandAckTimeout,
            onTimeout: () => false,
          );
        } finally {
          if (identical(_cmdAckCompleter, completer)) {
            _cmdAckCompleter = null;
          }
        }
      }, priority: GattOperationPriority.high);

      if (success) {
        _log.operation('指令确认: ${cmd.label}', level: LogLevel.info);
      } else {
        _log.operation('指令失败: ${cmd.label}', level: LogLevel.warning);
      }
      return success;
    }
    return false;
  }

  Future<QgjResponse?> sendQgjCommand(
    int cmdId, [
    List<int> payload = const [],
  ]) async {
    if (_state != ConnectionState.ready || _protocol != ProtocolType.qgj) {
      return null;
    }
    if (_feb1Char == null) return null;

    final frame = buildQgjCommand(cmdId, Uint8List.fromList(payload));
    return runGattOperation(() async {
      final previous = _qgjResponseCompleters.remove(cmdId);
      if (previous != null && !previous.isCompleted) {
        previous.completeError(StateError('QGJ command superseded'));
      }

      final completer = Completer<QgjResponse?>();
      _qgjResponseCompleters[cmdId] = completer;
      try {
        await _feb1Char!.write(frame.toList(), withoutResponse: false);
        return await completer.future.timeout(
          BleTimings.commandAckTimeout,
          onTimeout: () => null,
        );
      } finally {
        final current = _qgjResponseCompleters[cmdId];
        if (identical(current, completer)) {
          _qgjResponseCompleters.remove(cmdId);
        }
      }
    }, priority: GattOperationPriority.high);
  }

  /// Standard-stack raw hex write (official `writeData` path) after LOGIN.
  Future<bool> writeStandardHex(String hexData) async {
    if (_state != ConnectionState.ready ||
        (_protocol != ProtocolType.kks && _protocol != ProtocolType.tlink) ||
        _writeChar == null) {
      return false;
    }
    final frame = _protocol == ProtocolType.tlink
        ? '$hexData${_token!}'
        : hexData;
    final bytes = aesEcbEncrypt(_model.aesKey, frame);
    await runGattOperation(
      () => _writeChar!.write(bytes.toList(), withoutResponse: false),
      priority: GattOperationPriority.high,
    );
    return true;
  }

  // ---------------------------------------------------------------------------
  // TLink induction mode (official openMode / closeMode / setModeDistance)
  // ---------------------------------------------------------------------------

  /// Query induction switch + distance (`checkMode`).
  Future<TLinkInductionStatusResponse?> checkTlinkInduction() async {
    // Official openMode path is TLink AES writeData only (token-appended 16B block).
    if (!isProtocolLoggedIn || _protocol != ProtocolType.tlink) {
      return null;
    }
    final previous = _tlinkInductionStatusCompleter;
    if (previous != null && !previous.isCompleted) {
      previous.complete(null);
    }
    final completer = Completer<TLinkInductionStatusResponse?>();
    _tlinkInductionStatusCompleter = completer;
    final written = await writeStandardHex(tlinkInductionCheckPlain);
    if (!written) {
      if (identical(_tlinkInductionStatusCompleter, completer)) {
        _tlinkInductionStatusCompleter = null;
      }
      return null;
    }
    try {
      return await completer.future.timeout(
        BleTimings.commandAckTimeout,
        onTimeout: () => null,
      );
    } finally {
      if (identical(_tlinkInductionStatusCompleter, completer)) {
        _tlinkInductionStatusCompleter = null;
      }
    }
  }

  /// Open induction mode (`openMode`). Pairing is left to the caller.
  Future<bool> openTlinkInduction() async {
    if (!isProtocolLoggedIn || _protocol != ProtocolType.tlink) {
      return false;
    }
    final previous = _tlinkInductionSetCompleter;
    if (previous != null && !previous.isCompleted) {
      previous.complete(false);
    }
    final completer = Completer<bool>();
    _tlinkInductionSetCompleter = completer;
    final written = await writeStandardHex(tlinkInductionOpenPlain);
    if (!written) {
      if (identical(_tlinkInductionSetCompleter, completer)) {
        _tlinkInductionSetCompleter = null;
      }
      return false;
    }
    try {
      return await completer.future.timeout(
        BleTimings.commandAckTimeout,
        onTimeout: () => false,
      );
    } finally {
      if (identical(_tlinkInductionSetCompleter, completer)) {
        _tlinkInductionSetCompleter = null;
      }
    }
  }

  /// Close induction mode (`closeMode`). Bond removal is left to the caller.
  Future<bool> closeTlinkInduction() async {
    if (!isProtocolLoggedIn || _protocol != ProtocolType.tlink) {
      return false;
    }
    final previous = _tlinkInductionSetCompleter;
    if (previous != null && !previous.isCompleted) {
      previous.complete(false);
    }
    final completer = Completer<bool>();
    _tlinkInductionSetCompleter = completer;
    final written = await writeStandardHex(tlinkInductionClosePlain);
    if (!written) {
      if (identical(_tlinkInductionSetCompleter, completer)) {
        _tlinkInductionSetCompleter = null;
      }
      return false;
    }
    try {
      return await completer.future.timeout(
        BleTimings.commandAckTimeout,
        onTimeout: () => false,
      );
    } finally {
      if (identical(_tlinkInductionSetCompleter, completer)) {
        _tlinkInductionSetCompleter = null;
      }
    }
  }

  /// Set TLink proximity distance level 0–30 (`setModeDistance`).
  Future<bool> setTlinkInductionDistance(int progress) async {
    if (!isProtocolLoggedIn || _protocol != ProtocolType.tlink) {
      return false;
    }
    final previous = _tlinkProximityDistanceCompleter;
    if (previous != null && !previous.isCompleted) {
      previous.complete(false);
    }
    final completer = Completer<bool>();
    _tlinkProximityDistanceCompleter = completer;
    final written = await writeStandardHex(
      buildTLinkInductionDistancePlain(progress),
    );
    if (!written) {
      if (identical(_tlinkProximityDistanceCompleter, completer)) {
        _tlinkProximityDistanceCompleter = null;
      }
      return false;
    }
    try {
      return await completer.future.timeout(
        BleTimings.commandAckTimeout,
        onTimeout: () => false,
      );
    } finally {
      if (identical(_tlinkProximityDistanceCompleter, completer)) {
        _tlinkProximityDistanceCompleter = null;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // System BLE bond (official pairingDevice / removeBleBond)
  // ---------------------------------------------------------------------------

  /// Create system bond with the connected peripheral (Android/iOS).
  Future<bool> createBond({bool quiet = false}) async {
    final device = _device;
    if (device == null) return false;
    try {
      final state = await device.bondState.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => BluetoothBondState.none,
      );
      if (state == BluetoothBondState.bonded) return true;
      await device.createBond();
      final after = await device.bondState
          .firstWhere((s) => s == BluetoothBondState.bonded)
          .timeout(const Duration(seconds: 15), onTimeout: () => state);
      final ok = after == BluetoothBondState.bonded;
      if (!quiet) {
        _log.ble(
          ok ? '系统蓝牙配对成功' : '系统蓝牙配对未完成',
          level: ok ? LogLevel.info : LogLevel.warning,
        );
      }
      return ok;
    } catch (e) {
      _log.ble('系统蓝牙配对失败', detail: e.toString(), level: LogLevel.warning);
      return false;
    }
  }

  /// Remove system bond (official `removeBleBond` / HID close path).
  Future<bool> removeBond({bool quiet = false}) async {
    final device = _device;
    if (device == null) return false;
    try {
      final state = await device.bondState.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => BluetoothBondState.none,
      );
      if (state == BluetoothBondState.none) return true;
      await device.removeBond();
      if (!quiet) {
        _log.ble('系统蓝牙配对已移除', level: LogLevel.info);
      }
      return true;
    } catch (e) {
      _log.ble('移除系统配对失败', detail: e.toString(), level: LogLevel.warning);
      return false;
    }
  }

  /// Read remote RSSI once (official `readRemoteRssi` path).
  Future<int?> readRemoteRssi() async {
    final device = _device;
    if (device == null || _state == ConnectionState.disconnected) return null;
    try {
      return await device.readRssi();
    } catch (e) {
      _log.ble('读取 RSSI 失败', detail: e.toString(), level: LogLevel.debug);
      return null;
    }
  }

  /// Official OTA control characteristic write (`gatt7000` / otaOrder).
  Future<bool> writeOtaOrder(List<int> message) async {
    if (_state != ConnectionState.ready) return false;
    final char = _findCharByUuid(BleUuids.otaOrder);
    if (char == null) return false;
    await runGattOperation(
      () => char.write(message, withoutResponse: false),
      priority: GattOperationPriority.high,
    );
    return true;
  }

  /// Official OTA file characteristic write (`gatt7001` / otaFile).
  Future<bool> writeOtaFileChunk(List<int> message) async {
    if (_state != ConnectionState.ready) return false;
    final char = _findCharByUuid(BleUuids.otaFile);
    if (char == null) return false;
    await runGattOperation(
      () => char.write(message, withoutResponse: true),
      priority: GattOperationPriority.high,
    );
    return true;
  }

  BluetoothCharacteristic? _findCharByUuid(String uuidFragment) {
    final device = _device;
    if (device == null) return null;
    final needle = uuidFragment.toLowerCase().replaceAll('-', '');
    for (final service in device.servicesList) {
      for (final c in service.characteristics) {
        final id = c.characteristicUuid.toString().toLowerCase().replaceAll(
          '-',
          '',
        );
        if (id.contains(needle.replaceAll('0000', '').substring(0, 8)) ||
            id.contains(needle)) {
          return c;
        }
      }
    }
    // Also match short form 7000/7001.
    final short = uuidFragment.toLowerCase();
    for (final service in device.servicesList) {
      for (final c in service.characteristics) {
        if (c.characteristicUuid.toString().toLowerCase().contains(
          short.contains('7000')
              ? '7000'
              : short.contains('7001')
              ? '7001'
              : short,
        )) {
          return c;
        }
      }
    }
    return null;
  }

  void _onFbb2Notify(List<int> value) {
    if (value.isEmpty) return;
    final hex = bytesToHex(Uint8List.fromList(value));
    _log.ble('fbb2 通知', detail: hex, level: LogLevel.debug);
    if (!_disposed) {
      _fbb2Controller.add(hex);
    }
  }

  Future<void> writeFbb2(String hexData) async {
    if (_state != ConnectionState.ready || _fbb2Char == null) return;
    final bytes = hexToBytes(hexData);
    await runGattOperation(
      () => _fbb2Char!.write(bytes.toList(), withoutResponse: false),
      priority: GattOperationPriority.high,
    );
  }

  RidingMode _ridingMode = RidingMode.standard;
  RidingMode get ridingMode => _ridingMode;
  final _ridingModeController = StreamController<RidingMode>.broadcast();
  Stream<RidingMode> get ridingModeStream => _ridingModeController.stream;

  Future<bool> setRidingMode(RidingMode mode) async {
    if (_state != ConnectionState.ready) return false;

    _log.operation('切换模式: ${mode.label}', detail: 'code=${mode.code}');

    try {
      final fcc1 = _fcc1Char ?? _findFcc1Char();
      if (fcc1 == null) return false;

      final response = await runGattOperation(() async {
        final current = await fcc1.read();
        final data = buildQgjRidingModeFrame(current, mode);
        if (data == null) {
          throw const FormatException('fcc1 状态数据不完整');
        }
        await fcc1.write(data, withoutResponse: false);
        await Future<void>.delayed(BleTimings.fccReadbackDelay);
        return fcc1.read();
      }, priority: GattOperationPriority.high);
      _ridingMode = parseQgjRidingMode(response) ?? mode;

      _addRidingMode(_ridingMode);
      _log.operation('模式已切换: ${_ridingMode.label}', level: LogLevel.info);
      return true;
    } catch (e) {
      _log.operation('模式切换失败', detail: e.toString(), level: LogLevel.error);
      return false;
    }
  }

  BluetoothCharacteristic? _findFcc1Char() {
    if (_device == null) return null;
    for (final service in _device!.servicesList) {
      if (service.serviceUuid.toString().contains('fcc0')) {
        for (final c in service.characteristics) {
          if (c.characteristicUuid.toString().contains('fcc1')) return c;
        }
      }
    }
    return null;
  }

  /// P0-1: 守卫逻辑收敛到单一入口。
  ///
  /// 返回 true 表示首次进入断连处理，false 表示已处理过（重入守卫）。
  /// 复位点在 `_attemptReconnect()` 成功路径与 `connect()` 中。
  bool _markDisconnectHandled() {
    if (_disconnectHandled) return false;
    _disconnectHandled = true;
    return true;
  }

  Future<void> _onDisconnected() async {
    if (_disposed) return;
    // P0-1: 收敛守卫到单一入口，便于 S4 状态机改造时统一复位点。
    if (!_markDisconnectHandled()) return;
    _log.ble('设备断开连接', level: LogLevel.warning);
    _cancelHeartbeat();
    _completePendingOperations(StateError('QGJ disconnected'));
    _completePendingGattOperations(StateError('BLE disconnected'));
    await _notifySub?.cancel();
    _notifySub = null;
    await _gpsNotifySub?.cancel();
    _gpsNotifySub = null;
    await _fbb2NotifySub?.cancel();
    _fbb2NotifySub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;

    // During the initial connect handshake, connect() still owns the session.
    // Starting a parallel reconnect race is what produced the diagnostic log:
    // login succeeds → reconnect exit forces disconnected → commands die.
    final wasHandshaking =
        _state == ConnectionState.connecting ||
        _state == ConnectionState.connected;
    // QGJ (电动车) shuts BLE off after 熄火/休眠. The official app does NOT
    // auto-reconnect QGJ — it只更新 DISCONNECTED 状态, 回到「点击连接」等用户。
    // Mirror that: no reconnect race, no scan spam, saves battery.
    final protocolIsQgj =
        _protocol == ProtocolType.qgj || _lastKnownProtocol == ProtocolType.qgj;
    _resetCharacteristics();
    if (!_userDisconnected &&
        _device != null &&
        !wasHandshaking &&
        !protocolIsQgj) {
      _setState(ConnectionState.reconnecting);
      unawaited(
        _attemptReconnect().catchError((Object e, StackTrace st) {
          _log.ble('Reconnect error: $e', level: LogLevel.error);
        }),
      );
    } else {
      _setState(ConnectionState.disconnected);
      if (wasHandshaking && !_userDisconnected) {
        _log.ble('握手期断连，交由 connect() 处理', level: LogLevel.info);
      } else if (protocolIsQgj && !_userDisconnected) {
        _log.ble('QGJ 断连（对齐官方：不自动重连，等待用户重连）', level: LogLevel.info);
      }
    }
  }

  Future<void> _attemptReconnect() async {
    if (_reconnecting || _device == null) return;
    _reconnecting = true;
    _reconnectAttempt = 0;

    while (_reconnectAttempt < _maxReconnectAttempts &&
        _state == ConnectionState.reconnecting) {
      // C-1: Check if reconnect was cancelled by connect()
      if (_reconnectCancelled) break;
      _reconnectAttempt++;
      final baseMs = 3000;
      final maxMs = 30000;
      final exponential = (baseMs * pow(2, _reconnectAttempt - 1))
          .toInt()
          .clamp(baseMs, maxMs);
      final jitter = Random().nextInt(500);
      final delay = Duration(milliseconds: exponential + jitter);
      _log.ble(
        '重连 $_reconnectAttempt/$_maxReconnectAttempts，${delay.inSeconds}s 后重试',
        level: LogLevel.info,
      );

      await Future<void>.delayed(delay);

      if (_state != ConnectionState.reconnecting) break;
      if (_reconnectCancelled) break;

      try {
        await _device!.connect(
          timeout: BleTimings.reconnectConnectTimeout,
          mtu: null,
        );

        if (_state != ConnectionState.reconnecting || _reconnectCancelled) {
          try {
            await _device?.disconnect();
          } catch (e) {
            _log.ble('取消重连时断开失败', detail: e.toString(), level: LogLevel.debug);
          }
          break;
        }

        _connectionSub = _device!.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            unawaited(_onDisconnected());
          }
        });

        _setState(ConnectionState.connected);
        await _requestQgjMtu(_device!);
        await Future<void>.delayed(BleTimings.serviceSetupDelay);
        if (_state != ConnectionState.connected || _reconnectCancelled) {
          break;
        }
        await _discoverAndSetup();

        _reconnecting = false;
        _reconnectAttempt = 0;
        // P0-1: 复位守卫，确保二次断连能再次进入 _onDisconnected。
        // 原 Bug：重连成功后此标志未复位，导致再次断连时 _onDisconnected 直接 return，
        // App 假死在 reconnecting/ready 状态。
        _disconnectHandled = false;
        _log.ble('重连成功', level: LogLevel.info);
        return;
      } catch (e) {
        _log.ble('重连失败', detail: e.toString(), level: LogLevel.debug);
        await _recoverFailedConnect(_device!, e);
      }
    }

    _reconnecting = false;
    _reconnectAttempt = 0;
    // Critical: do NOT clobber a session that already became ready/connected
    // while this loop was sleeping (race with the original connect path).
    if (_state == ConnectionState.reconnecting) {
      _setState(ConnectionState.disconnected);
      _log.ble('重连次数已用尽', level: LogLevel.warning);
    } else {
      _log.ble('重连结束（保留当前状态: ${_state.name}）', level: LogLevel.info);
    }
  }

  /// Latch official LOGIN: store credential, mark flag, enter ready.
  void _markProtocolLoggedIn(String credential) {
    _token = credential;
    _protocolLoggedIn = true;
    // Any in-flight reconnect must not tear down a successful LOGIN.
    _reconnectCancelled = true;
    _reconnecting = false;
    _disconnectHandled = false;
    _setState(ConnectionState.ready);
  }

  void _clearProtocolLogin() {
    _protocolLoggedIn = false;
    _token = null;
  }

  void _resetCharacteristics() {
    _protocol = ProtocolType.unknown;
    _clearProtocolLogin();
    _writeChar = null;
    _notifyChar = null;
    _feb1Char = null;
    _feb2Char = null;
    _feb3Char = null;
    _fe02Char = null;
    _fe03Char = null;
    _fcc1Char = null;
    _fcc2Char = null;
    _fbb1Char = null;
    _fbb2Char = null;
    _clearBikeState();
  }

  Future<void> _clearRuntimeResources({required bool disconnectDevice}) async {
    _cancelHeartbeat();
    _disarmReadyWatchdog();
    await _notifySub?.cancel();
    _notifySub = null;
    await _gpsNotifySub?.cancel();
    _gpsNotifySub = null;
    await _fbb2NotifySub?.cancel();
    _fbb2NotifySub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
    _completePendingOperations(StateError('BLE runtime cleared'));
    _completePendingGattOperations(StateError('BLE runtime cleared'));
    if (disconnectDevice) {
      try {
        await _device?.disconnect();
      } catch (e) {
        _log.ble('断开旧连接失败', detail: e.toString(), level: LogLevel.debug);
      }
    }
  }

  Future<void> _recoverFailedConnect(
    BluetoothDevice device,
    Object error,
  ) async {
    final text = error.toString();
    final isAndroidGatt133 =
        defaultTargetPlatform == TargetPlatform.android &&
        text.contains('android-code: 133');
    final isTimeout = text.toLowerCase().contains('timed out');
    if (!isAndroidGatt133 && !isTimeout) return;
    try {
      await device.disconnect();
    } catch (e) {
      _log.ble('连接失败恢复断开设备失败', detail: e.toString(), level: LogLevel.debug);
    }
    _resetCharacteristics();
    _log.ble(
      '连接失败后已清理 GATT 状态',
      detail: isAndroidGatt133 ? 'android-code: 133' : 'timeout',
      level: LogLevel.debug,
    );
    await Future<void>.delayed(
      isAndroidGatt133
          ? BleTimings.androidGattErrorRecoveryDelay
          : BleTimings.failedConnectRecoveryDelay,
    );
  }

  void _completePendingOperations(Object error) {
    if (_cmdAckCompleter != null && !_cmdAckCompleter!.isCompleted) {
      _cmdAckCompleter!.complete(false);
    }
    _cmdAckCompleter = null;
    if (_standardCommandAckCompleter != null &&
        !_standardCommandAckCompleter!.isCompleted) {
      _standardCommandAckCompleter!.complete(false);
    }
    _standardCommandAckCompleter = null;
    _standardPendingCommandType = null;
    if (_standardStateCompleter != null &&
        !_standardStateCompleter!.isCompleted) {
      _standardStateCompleter!.complete(null);
    }
    _standardStateCompleter = null;
    if (_tlinkInductionStatusCompleter != null &&
        !_tlinkInductionStatusCompleter!.isCompleted) {
      _tlinkInductionStatusCompleter!.complete(null);
    }
    _tlinkInductionStatusCompleter = null;
    if (_tlinkInductionSetCompleter != null &&
        !_tlinkInductionSetCompleter!.isCompleted) {
      _tlinkInductionSetCompleter!.complete(false);
    }
    _tlinkInductionSetCompleter = null;
    if (_tlinkProximityDistanceCompleter != null &&
        !_tlinkProximityDistanceCompleter!.isCompleted) {
      _tlinkProximityDistanceCompleter!.complete(false);
    }
    _tlinkProximityDistanceCompleter = null;
    for (final completer in _qgjResponseCompleters.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _qgjResponseCompleters.clear();
  }

  void _completePendingGattOperations(Object error) {
    final active = _activeGattOperation;
    if (active != null && !active.completer.isCompleted) {
      active.completer.completeError(error);
    }
    _activeGattOperation = null;
    for (final queue in _gattPendingByPriority.values) {
      for (final queued in queue) {
        if (!queued.completer.isCompleted) {
          queued.completer.completeError(error);
        }
      }
      queue.clear();
    }
  }

  void _reset() {
    _state = ConnectionState.disconnected;
    _device = null;
    if (!_disposed) {
      _stateController.add(_state);
    }
    _resetCharacteristics();
  }

  void _setState(ConnectionState s) {
    if (_state == s) return;
    _state = s;
    // Manage the ready-handshake watchdog: arm it when entering `connected`
    // (GATT up, awaiting token/login response), disarm it on any other
    // transition (ready = success, disconnected/reconnecting = teardown).
    if (s == ConnectionState.connected) {
      _armReadyWatchdog();
    } else {
      _disarmReadyWatchdog();
    }
    if (!_disposed) {
      _stateController.add(s);
    }
  }

  void _armReadyWatchdog() {
    _disarmReadyWatchdog();
    _readyWatchdog = Timer(BleTimings.readyHandshakeTimeout, () {
      if (_disposed) return;
      if (_state != ConnectionState.connected) return;
      _log.ble('connected→ready 握手超时，回退断连并触发重连', level: LogLevel.warning);
      // scheduleMicrotask avoids running teardown inside the Timer zone,
      // where async exceptions from _onDisconnected would be swallowed.
      scheduleMicrotask(() {
        unawaited(
          _onDisconnected().catchError((Object e, StackTrace st) {
            _log.ble('Disconnect handler error: $e', level: LogLevel.error);
          }),
        );
      });
    });
  }

  void _disarmReadyWatchdog() {
    _readyWatchdog?.cancel();
    _readyWatchdog = null;
  }

  void _addResponse(ParsedResponse response) {
    if (_disposed) return;
    _responseController.add(response);
  }

  void _addRidingMode(RidingMode mode) {
    if (_disposed) return;
    _ridingModeController.add(mode);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    _completePendingGattOperations(StateError('ConnectionManager disposed'));

    // Cancel timers
    _cancelHeartbeat();
    _disarmReadyWatchdog();

    // Cancel subscriptions
    await _notifySub?.cancel();
    await _gpsNotifySub?.cancel();
    await _connectionSub?.cancel();

    // Complete pending operations
    _completePendingOperations(StateError('ConnectionManager disposed'));

    // Disconnect device
    try {
      await _device?.disconnect();
    } catch (e) {
      _log.ble('释放连接时断开设备失败', detail: e.toString(), level: LogLevel.warning);
    }

    // Close controllers
    unawaited(_stateController.close());
    unawaited(_responseController.close());
    unawaited(_bikeStateController.close());
    unawaited(_ridingModeController.close());
    unawaited(_fbb2Controller.close());
  }
}

class _QueuedGattOperation<T> {
  final Future<T> Function() operation;
  final GattOperationPriority priority;
  final Completer<T> completer = Completer<T>();

  _QueuedGattOperation(this.operation, this.priority);
}
