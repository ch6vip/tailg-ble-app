import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import '../services/log_service.dart';
import 'constants.dart';
import 'protocol.dart';
import 'qgj_protocol.dart';
import 'parser.dart';

enum ProtocolType { standard, qgj, unknown }

enum ConnectionState { disconnected, connecting, connected, ready }

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
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _notifySub?.cancel();
    _connectionSub?.cancel();
    await _device?.disconnect();
    _reset();
  }

  Future<void> _discoverAndSetup() async {
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

    if (_feb2Char != null) {
      await _feb2Char!.setNotifyValue(true, forceIndications: true);
      _notifySub = _feb2Char!.onValueReceived.listen(_onQgjNotify);
    }

    if (_feb1Char != null) {
      final loginFrame = buildQgjLoginFrame();
      await _feb1Char!.write(loginFrame.toList(), withoutResponse: false);
    }
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
      _feb3Char!.read().then((_) {
        failCount = 0;
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

  Future<void> sendCommand(CommandCode cmd) async {
    if (_state != ConnectionState.ready) return;

    _log.operation('发送指令: ${cmd.label}', detail: 'code=${cmd.code}');

    if (_protocol == ProtocolType.standard) {
      if (_writeChar == null || _token == null) return;
      final frame = buildCommand(_model.aesKey, cmd, _token!);
      await _writeChar!.write(frame.toList(), withoutResponse: false);
    } else if (_protocol == ProtocolType.qgj) {
      if (_feb1Char == null) return;
      final frame = buildQgjControlFrame(cmd);
      if (frame == null) return;
      await _feb1Char!.write(frame.toList(), withoutResponse: false);
    }
  }

  void _onDisconnected() {
    _log.ble('设备断开连接', level: LogLevel.warning);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _notifySub?.cancel();
    _notifySub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    _reset();
  }

  void _reset() {
    _state = ConnectionState.disconnected;
    _stateController.add(_state);
    _protocol = ProtocolType.unknown;
    _token = null;
    _writeChar = null;
    _notifyChar = null;
    _feb1Char = null;
    _feb2Char = null;
    _feb3Char = null;
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
  }
}
