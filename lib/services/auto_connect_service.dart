import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import 'package:shared_preferences/shared_preferences.dart';
import '../ble/connection_manager.dart';
import '../models/vehicle_profile.dart';
import 'log_service.dart';
import 'vehicle_store.dart';

class AutoConnectService {
  static final AutoConnectService _instance = AutoConnectService._();
  factory AutoConnectService() => _instance;
  AutoConnectService._();

  final _log = LogService();
  ConnectionManager? _connectionManager;

  static const _prefEnabled = 'auto_connect_enabled';
  static const _prefDeviceId = 'auto_connect_device_id';
  static const _prefDeviceName = 'auto_connect_device_name';

  bool _enabled = false;
  bool get enabled => _enabled;
  String? _lastDeviceId;
  String? _lastDeviceName;
  String? get lastDeviceName => _lastDeviceName;

  final _enabledController = StreamController<bool>.broadcast();
  Stream<bool> get enabledStream => _enabledController.stream;

  Future<void> init(ConnectionManager manager) async {
    _connectionManager = manager;
    await VehicleStore().init();
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefEnabled) ?? false;
    final defaultVehicle = VehicleStore().defaultVehicle;
    if (defaultVehicle == null) {
      final legacyId = prefs.getString(_prefDeviceId);
      if (legacyId != null) {
        await VehicleStore().upsert(
          id: legacyId,
          name: prefs.getString(_prefDeviceName) ?? '未命名车辆',
          protocol: VehicleProtocol.auto,
          makeDefault: true,
        );
      }
    }
    _refreshTarget();
    _enabledController.add(_enabled);
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    _enabledController.add(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, value);
  }

  Future<void> saveDevice(BluetoothDevice device) async {
    _lastDeviceId = device.remoteId.toString();
    _lastDeviceName = device.platformName;
    await VehicleStore().upsert(
      id: _lastDeviceId!,
      name: _lastDeviceName ?? '未命名车辆',
      protocol: VehicleProtocol.auto,
      makeDefault: true,
      lastConnectedAt: DateTime.now(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefDeviceId, _lastDeviceId!);
    if (_lastDeviceName != null && _lastDeviceName!.isNotEmpty) {
      await prefs.setString(_prefDeviceName, _lastDeviceName!);
    }
  }

  Future<void> tryAutoConnect() async {
    await VehicleStore().init();
    _refreshTarget();
    if (!_enabled || _lastDeviceId == null || _connectionManager == null) {
      return;
    }
    if (_connectionManager!.state != ConnectionState.disconnected) return;

    _log.operation('自动连接: 扫描 $_lastDeviceName ($_lastDeviceId)');

    StreamSubscription? scanSub;
    Timer? timeout;

    final completer = Completer<void>();

    scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.remoteId.toString() == _lastDeviceId) {
          scanSub?.cancel();
          timeout?.cancel();
          FlutterBluePlus.stopScan();
          _doConnect(r.device).whenComplete(() {
            if (!completer.isCompleted) completer.complete();
          });
          return;
        }
      }
    });

    timeout = Timer(const Duration(seconds: 8), () {
      scanSub?.cancel();
      FlutterBluePlus.stopScan();
      _log.operation('自动连接: 超时未找到设备', level: LogLevel.warning);
      if (!completer.isCompleted) completer.complete();
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    await completer.future;
  }

  void _refreshTarget() {
    final defaultVehicle = VehicleStore().defaultVehicle;
    _lastDeviceId = defaultVehicle?.id ?? _lastDeviceId;
    _lastDeviceName = defaultVehicle?.displayName ?? _lastDeviceName;
  }

  Future<void> _doConnect(BluetoothDevice device) async {
    try {
      await _connectionManager!.connect(device);
      _log.operation('自动连接: 成功');
    } catch (e) {
      _log.operation('自动连接: 失败', detail: e.toString(), level: LogLevel.warning);
    }
  }
}
