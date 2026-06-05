import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import 'package:shared_preferences/shared_preferences.dart';
import '../ble/connection_manager.dart';
import '../ble/constants.dart';
import 'log_service.dart';
import 'manual_mode_service.dart';
import 'vehicle_store.dart';

class ProximityService {
  static final ProximityService _instance = ProximityService._();
  factory ProximityService() => _instance;
  ProximityService._();

  final _log = LogService();
  ConnectionManager? _connectionManager;
  StreamSubscription? _scanSub;
  bool _scanning = false;
  bool _unlockSent = false;
  String? _targetDeviceId;
  DateTime? _lastUnlockTime;

  static const _rssiThreshold = -75;
  static const _cooldownSeconds = 30;
  static const _prefKey = 'proximity_unlock_enabled';

  bool _enabled = false;
  bool get enabled => _enabled;

  final _enabledController = StreamController<bool>.broadcast();
  Stream<bool> get enabledStream => _enabledController.stream;

  Future<void> init(ConnectionManager manager) async {
    _connectionManager = manager;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? false;
    _enabledController.add(_enabled);
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    _enabledController.add(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    if (value) {
      start();
    } else {
      stop();
    }
  }

  void setTargetDevice(String deviceId) {
    _targetDeviceId = deviceId;
  }

  void start() {
    if (!_enabled || _targetDeviceId == null || _scanning) return;
    if (ManualModeService().enabled) return;
    if (_connectionManager?.state == ConnectionState.ready) return;

    _unlockSent = false;
    _scanning = true;
    _log.operation('感应解锁: 开始扫描', level: LogLevel.info);

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.remoteId.toString() == _targetDeviceId) {
          _onTargetFound(r);
          break;
        }
      }
    });

    FlutterBluePlus.startScan(
      timeout: BleTimings.proximityScanTimeout,
      continuousUpdates: true,
    );
  }

  void stop() {
    if (!_scanning) return;
    _scanning = false;
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    _scanSub = null;
  }

  void onAppResumed() {
    if (_enabled && _targetDeviceId != null) {
      if (_connectionManager?.state != ConnectionState.ready) {
        start();
      }
    }
  }

  void onAppPaused() {
    stop();
  }

  void onConnected() {
    stop();
    _unlockSent = false;
  }

  void _onTargetFound(ScanResult result) {
    if (_unlockSent) return;

    final now = DateTime.now();
    if (_lastUnlockTime != null &&
        now.difference(_lastUnlockTime!).inSeconds < _cooldownSeconds) {
      return;
    }

    if (result.rssi >= _rssiThreshold) {
      _unlockSent = true;
      _lastUnlockTime = now;
      stop();
      _log.operation('感应解锁: RSSI=${result.rssi}dBm，触发解锁', level: LogLevel.info);
      _connectAndUnlock(result.device);
    }
  }

  Future<void> _connectAndUnlock(BluetoothDevice device) async {
    if (_connectionManager == null) return;
    try {
      final vehicle = VehicleStore().defaultVehicle;
      _connectionManager!.setQgjCredentials(
        password: vehicle?.qgjLoginPassword,
        userId: vehicle?.qgjUserId,
      );
      await _connectionManager!.connect(device);
      await Future.delayed(BleTimings.serviceSetupDelay);
      if (_connectionManager!.state == ConnectionState.ready) {
        await _connectionManager!.sendCommand(CommandCode.unlock);
        _log.operation('感应解锁: 解锁成功', level: LogLevel.info);
      }
    } catch (e) {
      _log.operation(
        '感应解锁: 连接失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
    }
  }

  void dispose() {
    stop();
    _enabledController.close();
  }
}
