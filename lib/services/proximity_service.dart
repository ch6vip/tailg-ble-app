import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import 'package:shared_preferences/shared_preferences.dart';
import '../ble/connection_manager.dart';
import '../ble/constants.dart';
import 'ble_connection_snapshot_guard.dart';
import 'log_service.dart';
import 'manual_mode_service.dart';
import 'vehicle_store.dart';

class ProximityUnlockGuard {
  const ProximityUnlockGuard();

  bool allowsUnlock({
    required bool proximityEnabled,
    required bool manualModeEnabled,
    required String? targetDeviceId,
    required String deviceId,
    required ConnectionManager manager,
    required BluetoothDevice device,
    required ConnectionManager? currentManager,
    required BleConnectionSnapshotGuard snapshotGuard,
  }) {
    return proximityEnabled &&
        !manualModeEnabled &&
        targetDeviceId == deviceId &&
        snapshotGuard.allowsReadyTarget(
          startManager: manager,
          currentManager: currentManager,
          startDevice: device,
          currentDevice: manager.device,
          currentDeviceId: manager.device?.remoteId.toString(),
          expectedDeviceId: deviceId,
          currentState: manager.state,
        );
  }
}

class ProximityService {
  static final ProximityService _instance = ProximityService._();
  factory ProximityService() => _instance;
  ProximityService._();

  final _log = LogService();
  final _connectionSnapshotGuard = const BleConnectionSnapshotGuard();
  final _unlockGuard = const ProximityUnlockGuard();
  ConnectionManager? _connectionManager;
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _scanning = false;
  bool _unlockSent = false;
  String? _targetDeviceId;
  DateTime? _lastUnlockTime;
  bool _initialized = false;
  Future<void>? _initializing;

  static const _rssiThreshold = -75;
  static const _cooldownSeconds = 30;
  static const _prefKey = 'proximity_unlock_enabled';

  bool _enabled = false;
  bool get enabled => _enabled;
  @visibleForTesting
  String? get targetDeviceId => _targetDeviceId;

  final _enabledController = StreamController<bool>.broadcast();
  Stream<bool> get enabledStream => _enabledController.stream;

  Future<void> init(ConnectionManager manager) async {
    _connectionManager = manager;
    if (_initialized) return;
    final initializing = _initializing;
    if (initializing != null) return initializing;
    _initializing = _load();
    return _initializing!;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKey) ?? false;
      _initialized = true;
      _enabledController.add(_enabled);
    } finally {
      _initializing = null;
    }
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    _enabled = value;
    _enabledController.add(value);
    if (value) {
      await start();
    } else {
      stop();
    }
  }

  void setTargetDevice(String deviceId) {
    final trimmed = deviceId.trim();
    _targetDeviceId = trimmed.isEmpty ? null : trimmed;
  }

  Future<void> start() async {
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

    try {
      await FlutterBluePlus.startScan(
        timeout: BleTimings.proximityScanTimeout,
        continuousUpdates: true,
      );
    } catch (e) {
      final isPermission =
          e is PlatformException &&
          (e.code.contains('Permission') || e.code.contains('denied'));
      _log.operation(
        isPermission ? '感应解锁: 扫描权限不足' : '感应解锁: 扫描启动失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
    } finally {
      _scanning = false;
      await _scanSub?.cancel();
      _scanSub = null;
    }
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
        unawaited(start());
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
      _connectAndUnlock(result.device).catchError((Object e) {
        _log.operation(
          '感应解锁: 未捕获异常',
          detail: e.toString(),
          level: LogLevel.error,
        );
      });
    }
  }

  Future<void> _connectAndUnlock(BluetoothDevice device) async {
    final manager = _connectionManager;
    if (manager == null) {
      _unlockSent = false;
      return;
    }
    final deviceId = device.remoteId.toString();
    try {
      final vehicle = VehicleStore().defaultVehicle;
      manager.setQgjCredentials(
        password: vehicle?.qgjLoginPassword,
        userId: vehicle?.qgjUserId,
      );
      await manager.connect(device);
      await Future.delayed(BleTimings.serviceSetupDelay);
      if (_canUnlockConnectedTarget(
        manager: manager,
        device: device,
        deviceId: deviceId,
      )) {
        await manager.sendCommand(CommandCode.unlock);
        _log.operation('感应解锁: 解锁成功', level: LogLevel.info);
      } else {
        _unlockSent = false;
      }
    } catch (e) {
      _unlockSent = false;
      _log.operation(
        '感应解锁: 连接失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
    }
  }

  bool _canUnlockConnectedTarget({
    required ConnectionManager manager,
    required BluetoothDevice device,
    required String deviceId,
  }) {
    return _unlockGuard.allowsUnlock(
      proximityEnabled: _enabled,
      manualModeEnabled: ManualModeService().enabled,
      targetDeviceId: _targetDeviceId,
      deviceId: deviceId,
      manager: manager,
      device: device,
      currentManager: _connectionManager,
      snapshotGuard: _connectionSnapshotGuard,
    );
  }

  void dispose() {
    stop();
    _enabledController.close();
  }

  void resetForTest() {
    _connectionManager = null;
    _scanSub = null;
    _scanning = false;
    _unlockSent = false;
    _targetDeviceId = null;
    _lastUnlockTime = null;
    _enabled = false;
    _initialized = false;
    _initializing = null;
  }
}
