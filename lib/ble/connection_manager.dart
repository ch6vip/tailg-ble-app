import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import '../services/log_service.dart';
import 'constants.dart';
import 'protocol.dart';
import 'qgj_protocol.dart';
import 'parser.dart';

enum ProtocolType { standard, qgj, unknown }

enum ConnectionState { disconnected, connecting, reconnecting, connected, ready }

class ConnectionManager {
  final _log = LogService();
  BluetoothDevice? _device;
  ProtocolType _protocol = ProtocolType.unknown;
  ConnectionState _state = ConnectionState.disconnected;
  String? _token;
  ModelType _model = ModelType.KKS;

  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _feb1Char;
  BluetoothCharacteristic? _feb2Char;
  BluetoothCharacteristic? _feb3Char;

  Timer? _heartbeatTimer;
  StreamSubscription? _connectionSub;
  StreamSubscription? _notifySub;

  bool _userDisconnected = false;
  bool _reconnecting = false;
  int _reconnectAttempt = 0;
  static const _maxReconnectAttempts = 8;

  Completer<bool>? _cmdAckCompleter;

  final _stateController = StreamController<ConnectionState>.broadcast();
  final _responseController = StreamController<ParsedResponse>.broadcast();
  final _bikeStateController = StreamController<BikeState?>.broadcast();

  Stream<ConnectionState> get stateStream => _stateController.stream;
  Stream<ParsedResponse> get responseStream => _responseController.stream;
  Stream<BikeState?> get bikeStateStream => _bikeStateController.stream;
  ConnectionState get state => _state;
  ProtocolType get protocol => _protocol;
  String? get token => _token;
  BluetoothDevice? get device => _device;

  void setModel(ModelType model) => _model = model;

  Future<void> connect(BluetoothDevice device) async {
    _userDisconnected = false;
    _reconnecting = false;
    _reconnectAttempt = 0;
    _notifySub?.cancel();
    _connectionSub?.cancel();
    _heartbeatTimer?.cancel();

    _device = device;
    _setState(ConnectionState.connecting);
    _log.ble('连接设备 ${device.platformName}', detail: device.remoteId.toString());

    try {
      await device.connect(timeout: const Duration(seconds: 10));

      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _onDisconnected();
        }
      });

      _setState(ConnectionState.connected);

      await Future.delayed(const Duration(milliseconds: 500));
      await _discoverAndSetup();
    } catch (e) {
      _log.ble('连接失败', detail: e.toString(), level: LogLevel.error);
      _setState(ConnectionState.disconnected);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _userDisconnected = true;
    _reconnecting = false;
    _reconnectAttempt = 0;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _notifySub?.cancel();
    _connectionSub?.cancel();
    await _device?.disconnect();
    _reset();
  }

  Future<void> _discoverAndSetup() async {
    try {
      final services = await _device!.discoverServices();

      _log.ble('发现 ${services.length} 个服务',
          detail: services.map((s) => s.serviceUuid.toString()).join(', '));

      final hasFeb0 = services.any(
          (s) => s.serviceUuid.toString().contains('feb0'));
      final hasFee5 = services.any(
          (s) => s.serviceUuid.toString().contains('fee5'));

      if (hasFeb0) {
        _protocol = ProtocolType.qgj;
        _log.ble('识别协议: QGJ (feb0)', level: LogLevel.info);
        await _setupQgj(services);
      } else if (hasFee5) {
        _protocol = ProtocolType.standard;
        _log.ble('识别协议: Standard (fee5)', level: LogLevel.info);
        await _setupStandard(services);
      } else {
        _protocol = ProtocolType.unknown;
        _log.ble('未识别协议', level: LogLevel.warning);
      }
    } catch (e) {
      _log.ble('服务发现/设置失败', detail: e.toString(), level: LogLevel.error);
      _setState(ConnectionState.disconnected);
    }
  }

  Future<void> _setupStandard(List<BluetoothService> services) async {
    final service = services.firstWhere(
        (s) => s.serviceUuid.toString().contains('fee5'));

    for (final c in service.characteristics) {
      final uuid = c.characteristicUuid.toString();
      if (uuid.contains('feb5')) _writeChar = c;
      if (uuid.contains('feb6')) _notifyChar = c;
    }

    if (_notifyChar != null) {
      await _notifyChar!.setNotifyValue(true);
      _notifySub = _notifyChar!.onValueReceived.listen(_onStandardNotify);
    }

    if (_writeChar != null) {
      final tokenReq = buildTokenRequest(_model.aesKey);
      await _writeChar!.write(tokenReq.toList(), withoutResponse: false);
    }
  }

  Future<void> _setupQgj(List<BluetoothService> services) async {
    final service = services.firstWhere(
        (s) => s.serviceUuid.toString().contains('feb0'));

    for (final c in service.characteristics) {
      final uuid = c.characteristicUuid.toString();
      if (uuid.contains('feb1')) _feb1Char = c;
      if (uuid.contains('feb2')) _feb2Char = c;
      if (uuid.contains('feb3')) _feb3Char = c;
    }

    _log.ble('QGJ characteristics',
        detail: 'feb1=${_feb1Char != null}, feb2=${_feb2Char != null}, feb3=${_feb3Char != null}');

    // 订阅 fcc0 服务的 fcc1/fbb1/fcc2/fbb2（原 app 必须步骤，否则设备超时断开）
    await _subscribeFcc0(services);

    if (_feb2Char != null) {
      await _feb2Char!.setNotifyValue(true, forceIndications: true);
      _notifySub = _feb2Char!.onValueReceived.listen(_onQgjNotify);
    }

    if (_feb1Char != null) {
      final loginFrame = buildQgjLoginFrame();
      await _feb1Char!.write(loginFrame.toList(), withoutResponse: false);
    }
  }

  Future<void> _subscribeFcc0(List<BluetoothService> services) async {
    final fcc0Service = services.where(
        (s) => s.serviceUuid.toString().contains('fcc0'));
    if (fcc0Service.isEmpty) {
      _log.ble('fcc0 服务未找到', level: LogLevel.warning);
      return;
    }

    final service = fcc0Service.first;
    int subscribed = 0;
    for (final c in service.characteristics) {
      final uuid = c.characteristicUuid.toString();
      if (c.properties.notify || c.properties.indicate) {
        try {
          await c.setNotifyValue(true);
          subscribed++;
        } catch (e) {
          _log.ble('订阅 $uuid 失败', detail: e.toString(), level: LogLevel.debug);
        }
      }
    }
    _log.ble('fcc0 已订阅 $subscribed 个特征', level: LogLevel.info);
  }

  void _onStandardNotify(List<int> value) {
    final data = Uint8List.fromList(value);
    _log.ble('← 收到数据', detail: data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));
    final response = parseResponse(_model.aesKey, data);
    _responseController.add(response);

    if (response is TokenResponse) {
      _token = response.token;
      _setState(ConnectionState.ready);
    } else if (response is StateResponse && response.bikeState != null) {
      _bikeStateController.add(response.bikeState);
    }
  }

  void _onQgjNotify(List<int> value) {
    final data = Uint8List.fromList(value);
    _log.ble('← QGJ 响应', detail: data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));
    final response = parseQgjResponse(data);
    if (response == null) return;

    if (response.cmdId == 0x1001 && response.success) {
      _token = 'qgj';
      _log.ble('QGJ 登录成功', level: LogLevel.info);
      _setState(ConnectionState.ready);
      _startHeartbeat();
    } else if (response.cmdId == 0x1002) {
      _cmdAckCompleter?.complete(response.success);
      _cmdAckCompleter = null;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _log.ble('心跳启动 feb3=${_feb3Char != null}', level: LogLevel.info);
    if (_feb3Char == null) {
      _log.ble('feb3 未找到，无法维持心跳', level: LogLevel.error);
      return;
    }
    int failCount = 0;

    void tick() {
      if (_state != ConnectionState.ready || _feb3Char == null) return;
      _feb3Char!.read().then((data) {
        failCount = 0;
        if (data.isNotEmpty) {
          final state = BikeState.fromFeb3(data);
          if (state != null) {
            _bikeStateController.add(state);
          }
        }
      }).catchError((e) {
        failCount++;
        if (failCount == 3) {
          _log.ble('心跳连续失败 3 次', detail: e.toString(), level: LogLevel.warning);
        }
      });
    }

    Future.delayed(const Duration(milliseconds: 500), tick);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<bool> sendCommand(CommandCode cmd) async {
    if (_state != ConnectionState.ready) return false;

    _log.operation('发送指令: ${cmd.label}', detail: 'code=${cmd.code}');

    if (_protocol == ProtocolType.standard) {
      if (_writeChar == null || _token == null) return false;
      final frame = buildCommand(_model.aesKey, cmd, _token!);
      await _writeChar!.write(frame.toList(), withoutResponse: false);
      return true;
    } else if (_protocol == ProtocolType.qgj) {
      if (_feb1Char == null) return false;
      final frame = buildQgjControlFrame(cmd);
      if (frame == null) return false;

      _cmdAckCompleter = Completer<bool>();
      await _feb1Char!.write(frame.toList(), withoutResponse: false);

      final success = await _cmdAckCompleter!.future
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      _cmdAckCompleter = null;

      if (success) {
        _log.operation('指令确认: ${cmd.label}', level: LogLevel.info);
      } else {
        _log.operation('指令失败: ${cmd.label}', level: LogLevel.warning);
      }
      return success;
    }
    return false;
  }

  RidingMode _ridingMode = RidingMode.standard;
  RidingMode get ridingMode => _ridingMode;
  final _ridingModeController = StreamController<RidingMode>.broadcast();
  Stream<RidingMode> get ridingModeStream => _ridingModeController.stream;

  Future<bool> setRidingMode(RidingMode mode) async {
    if (_state != ConnectionState.ready) return false;

    _log.operation('切换模式: ${mode.label}', detail: 'code=${mode.code}');

    try {
      final fcc1 = _findFcc1Char();
      if (fcc1 == null) return false;

      // fcc1 ECU control: 00070002 + state1 + state2 + state3
      // Mode encoded in state2 bits 3-4
      final state2 = (mode.code & 0x03) << 3;
      final data = [0x00, 0x07, 0x00, 0x02, 0x00, state2, 0x00];
      await fcc1.write(data, withoutResponse: false);

      await Future.delayed(const Duration(milliseconds: 200));
      final response = await fcc1.read();
      if (response.isNotEmpty) {
        final confirmedMode = (response.length > 5)
            ? (response[5] >> 3) & 0x03
            : mode.code;
        _ridingMode = RidingMode.values.firstWhere(
            (m) => m.code == confirmedMode,
            orElse: () => mode);
      } else {
        _ridingMode = mode;
      }

      _ridingModeController.add(_ridingMode);
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

  void _onDisconnected() {
    _log.ble('设备断开连接', level: LogLevel.warning);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _notifySub?.cancel();
    _notifySub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    _resetCharacteristics();
    if (!_userDisconnected && _device != null) {
      _setState(ConnectionState.reconnecting);
      _attemptReconnect();
    } else {
      _setState(ConnectionState.disconnected);
    }
  }

  Future<void> _attemptReconnect() async {
    if (_reconnecting || _device == null) return;
    _reconnecting = true;
    _reconnectAttempt = 0;

    while (_reconnectAttempt < _maxReconnectAttempts && _state == ConnectionState.reconnecting) {
      _reconnectAttempt++;
      final delay = Duration(milliseconds: (3000 * (1 << (_reconnectAttempt - 1)).clamp(1, 3)));
      _log.ble('重连 $_reconnectAttempt/$_maxReconnectAttempts，${delay.inSeconds}s 后重试', level: LogLevel.info);

      await Future.delayed(delay);

      if (_state != ConnectionState.reconnecting) break;

      try {
        await _device!.connect(timeout: const Duration(seconds: 8));

        _connectionSub = _device!.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            _onDisconnected();
          }
        });

        _setState(ConnectionState.connected);
        await Future.delayed(const Duration(milliseconds: 500));
        await _discoverAndSetup();

        _reconnecting = false;
        _reconnectAttempt = 0;
        _log.ble('重连成功', level: LogLevel.info);
        return;
      } catch (e) {
        _log.ble('重连失败', detail: e.toString(), level: LogLevel.debug);
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
  }

  void _reset() {
    _state = ConnectionState.disconnected;
    _stateController.add(_state);
    _resetCharacteristics();
  }

  void _setState(ConnectionState s) {
    _state = s;
    _stateController.add(s);
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _notifySub?.cancel();
    _connectionSub?.cancel();
    _stateController.close();
    _responseController.close();
    _bikeStateController.close();
    _ridingModeController.close();
  }
}
