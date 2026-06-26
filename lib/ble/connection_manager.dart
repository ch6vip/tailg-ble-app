import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import '../services/log_service.dart';
import 'constants.dart';
import 'protocol.dart';
import 'qgj_protocol.dart';
import 'parser.dart';

enum ProtocolType { standard, qgj, unknown }

enum ConnectionState {
  disconnected,
  connecting,
  reconnecting,
  connected,
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
  ConnectionState _state = ConnectionState.disconnected;
  String? _token;
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

  Timer? _heartbeatTimer;
  Timer? _readyWatchdog;
  StreamSubscription? _connectionSub;
  StreamSubscription? _notifySub;
  StreamSubscription? _gpsNotifySub;

  bool _userDisconnected = false;
  bool _reconnecting = false;
  bool _reconnectCancelled = false;
  bool _disconnectHandled = false;
  int _reconnectAttempt = 0;
  static const _maxReconnectAttempts = 8;

  Completer<bool>? _cmdAckCompleter;
  final Map<int, Completer<QgjResponse?>> _qgjResponseCompleters = {};
  final List<_QueuedGattOperation<dynamic>> _gattPending = [];
  bool _gattRunning = false;

  final _stateController = StreamController<ConnectionState>.broadcast();
  final _responseController = StreamController<ParsedResponse>.broadcast();
  final _bikeStateController = StreamController<BikeState?>.broadcast();

  Stream<ConnectionState> get stateStream => _stateController.stream;
  Stream<ParsedResponse> get responseStream => _responseController.stream;
  Stream<BikeState?> get bikeStateStream => _bikeStateController.stream;
  ConnectionState get state => _state;
  ProtocolType get protocol => _protocol;
  ProtocolType get lastKnownProtocol => _lastKnownProtocol;
  String? get token => _token;
  BluetoothDevice? get device => _device;
  BikeState? get latestBikeState => _latestBikeState;
  int get qgjLoginPassword => _qgjLoginPassword;
  int get qgjUserId => _qgjUserId;
  BluetoothCharacteristic? get fcc1Char => _fcc1Char;
  BluetoothCharacteristic? get fcc2Char => _fcc2Char;
  BluetoothCharacteristic? get fbb1Char => _fbb1Char;
  BluetoothCharacteristic? get fbb2Char => _fbb2Char;

  void setModel(ModelType model) => _model = model;

  void setQgjCredentials({int? password, int? userId}) {
    _qgjLoginPassword = password ?? 0;
    _qgjUserId = userId ?? 0;
  }

  Future<T> runGattOperation<T>(
    Future<T> Function() operation, {
    GattOperationPriority priority = GattOperationPriority.normal,
  }) {
    final queued = _QueuedGattOperation<T>(operation, priority);
    _gattPending.add(queued);
    _gattPending.sort((a, b) {
      final priorityCompare = a.priority.index.compareTo(b.priority.index);
      if (priorityCompare != 0) return priorityCompare;
      return a.sequence.compareTo(b.sequence);
    });
    _drainGattQueue();
    return queued.completer.future;
  }

  void _drainGattQueue() {
    if (_gattRunning || _gattPending.isEmpty) return;
    _gattRunning = true;
    () async {
      while (_gattPending.isNotEmpty) {
        final queued = _gattPending.removeAt(0);
        try {
          final result = await queued.operation().timeout(
            const Duration(seconds: 30),
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
        }
      }
    }().whenComplete(() {
      _gattRunning = false;
      if (_gattPending.isNotEmpty) _drainGattQueue();
    });
  }

  Future<List<int>?> readFeb3() {
    return runGattOperation(() async {
      if (_state != ConnectionState.ready || _feb3Char == null) return null;
      return _feb3Char!.read();
    }, priority: GattOperationPriority.low);
  }

  Future<BikeState?> refreshBikeState() async {
    final data = await readFeb3();
    if (data == null || data.isEmpty) return null;
    final state = BikeState.fromFeb3(data);
    if (state != null) {
      _publishBikeState(state);
    }
    return state;
  }

  Future<void> connect(BluetoothDevice device) async {
    if (_disposed) {
      throw StateError('ConnectionManager disposed');
    }

    // C-1: Cancel any ongoing reconnect loop
    _reconnectCancelled = true;
    if (_reconnecting) {
      // Give the reconnect loop a chance to exit
      await Future.delayed(const Duration(milliseconds: 100));
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

    _device = device;
    _lastKnownProtocol = ProtocolType.unknown;
    _setState(ConnectionState.connecting);
    _reconnectCancelled = false; // C-1: Reset after setup
    _log.ble('连接设备 ${device.platformName}', detail: device.remoteId.toString());

    try {
      // Subscribe BEFORE connecting to not miss early disconnect events
      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _onDisconnected();
        }
      });

      await _connectDeviceWithRetry(
        device,
        timeout: BleTimings.connectTimeout,
        attempts: 3,
      );

      _setState(ConnectionState.connected);

      await _requestQgjMtu(device);
      await Future.delayed(BleTimings.serviceSetupDelay);
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
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _completePendingOperations(StateError('QGJ disconnected'));
    _completePendingGattOperations(StateError('Disconnected by user'));
    await _clearRuntimeResources(disconnectDevice: false);
    await _device?.disconnect();
    _resetCharacteristics();
    _reset();
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

      if (hasFeb0) {
        _protocol = ProtocolType.qgj;
        _lastKnownProtocol = _protocol;
        _log.ble('识别协议: QGJ (feb0)', level: LogLevel.info);
        await _setupQgj(services);
      } else if (hasFee5) {
        _protocol = ProtocolType.standard;
        _lastKnownProtocol = _protocol;
        _log.ble('识别协议: Standard (fee5)', level: LogLevel.info);
        await _setupStandard(services);
      } else {
        _protocol = ProtocolType.unknown;
        _log.ble('未识别协议', level: LogLevel.warning);
      }
    } catch (e) {
      _log.ble('服务发现/设置失败', detail: e.toString(), level: LogLevel.error);
      await _clearRuntimeResources(disconnectDevice: true);
      _resetCharacteristics();
      _setState(ConnectionState.disconnected);
      rethrow;
    }
  }

  Future<void> _setupStandard(List<BluetoothService> services) async {
    final service = services.firstWhere(
      (s) => s.serviceUuid.toString().contains('fee5'),
    );

    for (final c in service.characteristics) {
      final uuid = c.characteristicUuid.toString();
      if (uuid.contains('feb5')) _writeChar = c;
      if (uuid.contains('feb6')) _notifyChar = c;
    }

    if (_notifyChar != null) {
      await _enableNotifyOrIndicate(_notifyChar!);
      _notifySub = _notifyChar!.onValueReceived.listen(_onStandardNotify);
    }

    if (_writeChar != null) {
      final tokenReq = buildTokenRequest(_model.aesKey);
      await runGattOperation(
        () => _writeChar!.write(tokenReq.toList(), withoutResponse: false),
        priority: GattOperationPriority.high,
      );
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
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        await device.connect(timeout: timeout, mtu: null);
        return;
      } catch (e) {
        lastError = e;
        if (attempt == attempts) break;
        _log.ble(
          '连接失败，短暂重试 $attempt/$attempts',
          detail: e.toString(),
          level: LogLevel.debug,
        );
        await _recoverFailedConnect(device, e);
        await Future.delayed(BleTimings.initialConnectRetryDelay);
      }
    }
    throw lastError ?? StateError('连接失败');
  }

  Future<void> _requestQgjMtu(BluetoothDevice device) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
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
    _log.ble(
      '← 收到数据',
      detail: data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '),
    );
    final response = parseResponse(_model.aesKey, data);
    _addResponse(response);

    if (response is TokenResponse) {
      _token = response.token;
      _setState(ConnectionState.ready);
    } else if (response is StateResponse && response.bikeState != null) {
      _publishBikeState(response.bikeState);
    }
  }

  void _onQgjNotify(List<int> value) {
    if (_disposed) return;
    final data = Uint8List.fromList(value);
    _log.ble(
      '← QGJ 响应',
      detail: data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '),
    );
    final response = parseQgjResponse(data);
    if (response == null) return;

    if (response.cmdId == QgjCommandIds.login && response.success) {
      _token = 'qgj';
      _log.ble('QGJ 登录成功', level: LogLevel.info);
      _setState(ConnectionState.ready);
      _startHeartbeat();
    } else if (response.cmdId == QgjCommandIds.setStatus) {
      _cmdAckCompleter?.complete(response.success);
      _cmdAckCompleter = null;
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
      detail: value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '),
      level: LogLevel.debug,
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
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
          .catchError((e) {
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
              _heartbeatTimer?.cancel();
              _heartbeatTimer = null;
              // scheduleMicrotask: _onDisconnected performs async cleanup
              // (cancel subs, _attemptReconnect). Running it inline inside
              // the Timer callback would route those futures through the
              // Timer zone, swallowing any thrown exceptions.
              scheduleMicrotask(() {
                _onDisconnected().catchError((e, st) {
                  _log.ble(
                    'Disconnect handler error: $e',
                    level: LogLevel.error,
                  );
                });
              });
            }
          })
          .whenComplete(() => heartbeatInFlight = false);
    }

    Future.delayed(BleTimings.heartbeatInitialDelay, tick);
    _heartbeatTimer = Timer.periodic(
      BleTimings.qgjStatusPollInterval,
      (_) => tick(),
    );
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
  Future<QgjResponse?> createPendingQgjResponseForTest(int cmdId) {
    final completer = Completer<QgjResponse?>();
    _qgjResponseCompleters[cmdId] = completer;
    return completer.future;
  }

  Future<bool> sendCommand(CommandCode cmd) async {
    if (_state != ConnectionState.ready) return false;

    _log.operation('发送指令: ${cmd.label}', detail: 'code=${cmd.code}');

    if (_protocol == ProtocolType.standard) {
      if (_writeChar == null || _token == null) return false;
      final frame = buildCommand(_model.aesKey, cmd, _token!);
      await runGattOperation(
        () => _writeChar!.write(frame.toList(), withoutResponse: false),
        priority: GattOperationPriority.high,
      );
      return true;
    } else if (_protocol == ProtocolType.qgj) {
      if (_feb1Char == null) return false;
      final frame = buildQgjControlFrame(cmd);
      if (frame == null) return false;

      final success = await runGattOperation(() async {
        _cmdAckCompleter = Completer<bool>();
        await _feb1Char!.write(frame.toList(), withoutResponse: false);
        final result = await _cmdAckCompleter!.future.timeout(
          BleTimings.commandAckTimeout,
          onTimeout: () => false,
        );
        _cmdAckCompleter = null;
        return result;
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
        await Future.delayed(BleTimings.fccReadbackDelay);
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

  Future<void> _onDisconnected() async {
    if (_disposed) return;
    if (_disconnectHandled) return;
    _disconnectHandled = true;
    _log.ble('设备断开连接', level: LogLevel.warning);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _completePendingOperations(StateError('QGJ disconnected'));
    await _notifySub?.cancel();
    _notifySub = null;
    await _gpsNotifySub?.cancel();
    _gpsNotifySub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
    _resetCharacteristics();
    if (!_userDisconnected && _device != null) {
      _setState(ConnectionState.reconnecting);
      _attemptReconnect().catchError((e, st) {
        _log.ble('Reconnect error: $e', level: LogLevel.error);
      });
    } else {
      _setState(ConnectionState.disconnected);
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

      await Future.delayed(delay);

      if (_state != ConnectionState.reconnecting) break;

      try {
        await _device!.connect(
          timeout: BleTimings.reconnectConnectTimeout,
          mtu: null,
        );

        _connectionSub = _device!.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            _onDisconnected();
          }
        });

        _setState(ConnectionState.connected);
        await _requestQgjMtu(_device!);
        await Future.delayed(BleTimings.serviceSetupDelay);
        await _discoverAndSetup();

        _reconnecting = false;
        _reconnectAttempt = 0;
        _log.ble('重连成功', level: LogLevel.info);
        return;
      } catch (e) {
        _log.ble('重连失败', detail: e.toString(), level: LogLevel.debug);
        await _recoverFailedConnect(_device!, e);
      }
    }

    _reconnecting = false;
    _reconnectAttempt = 0;
    _setState(ConnectionState.disconnected);
    _log.ble('重连次数已用尽', level: LogLevel.warning);
  }

  void _resetCharacteristics() {
    _protocol = ProtocolType.unknown;
    _token = null;
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
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _disarmReadyWatchdog();
    await _notifySub?.cancel();
    _notifySub = null;
    await _gpsNotifySub?.cancel();
    _gpsNotifySub = null;
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
    } catch (_) {
      // Best-effort cleanup for Android GATT cache/state issues.
    }
    _resetCharacteristics();
    _log.ble(
      '连接失败后已清理 GATT 状态',
      detail: isAndroidGatt133 ? 'android-code: 133' : 'timeout',
      level: LogLevel.debug,
    );
    await Future.delayed(
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
    for (final completer in _qgjResponseCompleters.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _qgjResponseCompleters.clear();
  }

  void _completePendingGattOperations(Object error) {
    for (final queued in _gattPending) {
      if (!queued.completer.isCompleted) {
        queued.completer.completeError(error);
      }
    }
    _gattPending.clear();
  }

  void _reset() {
    _state = ConnectionState.disconnected;
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
        _onDisconnected().catchError((e, st) {
          _log.ble('Disconnect handler error: $e', level: LogLevel.error);
        });
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
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
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
    } catch (_) {}

    // Close controllers
    _stateController.close();
    _responseController.close();
    _bikeStateController.close();
    _ridingModeController.close();
  }
}

class _QueuedGattOperation<T> {
  static int _nextSequence = 0;

  final Future<T> Function() operation;
  final GattOperationPriority priority;
  final int sequence;
  final Completer<T> completer = Completer<T>();

  _QueuedGattOperation(this.operation, this.priority)
    : sequence = _nextSequence++;
}
