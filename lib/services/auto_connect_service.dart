import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import 'package:shared_preferences/shared_preferences.dart';
import '../ble/constants.dart';
import '../ble/connection_manager.dart';
import '../models/vehicle_profile.dart';
import 'ble_connection_snapshot_guard.dart';
import 'log_service.dart';
import 'manual_mode_service.dart';
import 'vehicle_store.dart';

class AutoConnectRunGate {
  Future<void>? _running;

  bool get isRunning => _running != null;

  Future<void> run(Future<void> Function() operation) {
    final running = _running;
    if (running != null) return running;

    late final Future<void> current;
    current = Future.sync(operation).whenComplete(() {
      if (identical(_running, current)) {
        _running = null;
      }
    });
    _running = current;
    return current;
  }
}

class AutoConnectTargetGuard {
  const AutoConnectTargetGuard();

  bool allowsConnectedTarget({
    required bool autoConnectEnabled,
    required bool manualModeEnabled,
    required String? defaultVehicleId,
    required String deviceId,
    required ConnectionManager manager,
    required BluetoothDevice device,
    required ConnectionManager? currentManager,
    required BleConnectionSnapshotGuard snapshotGuard,
  }) {
    return autoConnectEnabled &&
        !manualModeEnabled &&
        AutoConnectService._sameDeviceId(defaultVehicleId ?? '', deviceId) &&
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

class AutoConnectService {
  static final AutoConnectService _instance = AutoConnectService._();
  factory AutoConnectService() => _instance;
  AutoConnectService._();

  final _log = LogService();
  final _runGate = AutoConnectRunGate();
  final _connectionSnapshotGuard = const BleConnectionSnapshotGuard();
  final _targetGuard = const AutoConnectTargetGuard();
  ConnectionManager? _connectionManager;

  static const _prefEnabled = 'auto_connect_enabled';
  static const _prefDeviceId = 'auto_connect_device_id';
  static const _prefDeviceName = 'auto_connect_device_name';

  bool _enabled = false;
  bool _initialized = false;
  Future<void>? _initializing;
  DateTime Function() _clock = DateTime.now;
  bool get enabled => _enabled;
  String? _lastDeviceId;
  String? _lastDeviceName;
  String? get lastDeviceName => _lastDeviceName;

  StreamController<bool> _enabledController =
      StreamController<bool>.broadcast();
  Stream<bool> get enabledStream => _enabledController.stream;

  Future<void> init(ConnectionManager manager) async {
    _connectionManager = manager;
    if (_initialized) {
      _refreshTarget();
      return;
    }
    final initializing = _initializing;
    if (initializing != null) return initializing;
    final loading = _load();
    _initializing = loading;
    return loading;
  }

  Future<void> _load() async {
    await VehicleStore().init();
    try {
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
      _initialized = true;
      _emitEnabled();
    } finally {
      _initializing = null;
    }
  }

  void resetForTest({DateTime Function()? clock}) {
    if (_enabledController.isClosed) {
      _enabledController = StreamController<bool>.broadcast();
    }
    _connectionManager = null;
    _enabled = false;
    _lastDeviceId = null;
    _lastDeviceName = null;
    _initialized = false;
    _initializing = null;
    _clock = clock ?? DateTime.now;
  }

  void dispose() {
    if (!_enabledController.isClosed) {
      unawaited(_enabledController.close());
    }
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, value);
    _enabled = value;
    _emitEnabled();
  }

  /// Bind the official selected car as the near-field auto-connect target and
  /// optionally start scanning/connecting (official ControlFragment path).
  ///
  /// **P0-A4:** if BLE is already connected/connecting to a *different* device,
  /// disconnect first (clears pending commands) before retargeting.
  Future<void> linkOfficialTarget({
    required String deviceId,
    required String displayName,
    bool enable = true,
    bool connectNow = true,
  }) async {
    final id = deviceId.trim();
    if (id.isEmpty) return;

    await _disconnectIfDifferentTarget(id);

    await VehicleStore().init();
    await VehicleStore().upsert(
      id: id,
      name: displayName.trim().isEmpty ? '我的车辆' : displayName.trim(),
      protocol: VehicleProtocol.auto,
      makeDefault: true,
    );
    _lastDeviceId = id;
    _lastDeviceName = displayName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefDeviceId, id);
    if (displayName.trim().isNotEmpty) {
      await prefs.setString(_prefDeviceName, displayName.trim());
    }
    if (enable && !_enabled) {
      await setEnabled(true);
    } else {
      _refreshTarget();
    }
    if (connectNow) {
      await tryAutoConnect();
    }
  }

  /// Disconnect when the active BLE session is for another MAC/device id.
  ///
  /// [ConnectionManager.disconnect] also completes pending commands / GATT ops.
  Future<void> _disconnectIfDifferentTarget(String targetDeviceId) async {
    final manager = _connectionManager;
    if (manager == null) return;
    if (manager.state == ConnectionState.disconnected) return;

    final currentId = manager.device?.remoteId.toString() ?? '';
    if (currentId.isNotEmpty && sameDeviceId(currentId, targetDeviceId)) {
      return;
    }

    _log.operation(
      '换车: 断开旧 BLE',
      detail:
          'from=${currentId.isEmpty ? manager.state.name : currentId} '
          'to=$targetDeviceId',
      level: LogLevel.info,
    );
    try {
      await manager.disconnect();
    } catch (e) {
      _log.operation(
        '换车: 断开旧 BLE 失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
    }
  }

  /// Whether two BLE/device MAC strings refer to the same radio address.
  static bool sameDeviceId(String a, String b) => _sameDeviceId(a, b);

  /// True when manager is already working on [targetDeviceId].
  bool isLinkedTo(String targetDeviceId) {
    final manager = _connectionManager;
    if (manager == null) return false;
    if (manager.state == ConnectionState.disconnected) return false;
    final currentId = manager.device?.remoteId.toString() ?? '';
    if (currentId.isEmpty) return false;
    return sameDeviceId(currentId, targetDeviceId);
  }

  void _emitEnabled() {
    if (!_enabledController.isClosed) {
      _enabledController.add(_enabled);
    }
  }

  Future<VehicleProfile> saveDevice(
    BluetoothDevice device, {
    DateTime? lastConnectedAt,
    VehicleProtocol protocol = VehicleProtocol.auto,
  }) async {
    final connectedAt = lastConnectedAt ?? _clock();
    final deviceId = device.remoteId.toString();
    final deviceName = device.platformName;
    _lastDeviceId = deviceId;
    _lastDeviceName = deviceName;
    final profile = await VehicleStore().upsert(
      id: deviceId,
      name: deviceName,
      protocol: protocol,
      makeDefault: true,
      lastConnectedAt: connectedAt,
      savedAt: connectedAt,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefDeviceId, deviceId);
    if (deviceName.isNotEmpty) {
      await prefs.setString(_prefDeviceName, deviceName);
    }
    return profile;
  }

  Future<void> tryAutoConnect() async {
    await _runGate.run(_tryAutoConnectOnce);
  }

  Future<void> _tryAutoConnectOnce() async {
    await VehicleStore().init();
    _refreshTarget();
    await ManualModeService().init();
    if (ManualModeService().enabled) {
      _log.operation('自动连接: 已开启手动模式，跳过', level: LogLevel.info);
      return;
    }
    final manager = _connectionManager;
    final targetDeviceId = _lastDeviceId;
    final targetDeviceName = _lastDeviceName;
    if (!_enabled || targetDeviceId == null || manager == null) {
      return;
    }
    if (manager.state != ConnectionState.disconnected) return;

    _log.operation('自动连接: 扫描 $targetDeviceName ($targetDeviceId)');

    StreamSubscription<List<ScanResult>>? scanSub;
    Timer? timeout;
    final completer = Completer<void>();
    try {
      scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final foundId = r.device.remoteId.toString();
          if (!_sameDeviceId(foundId, targetDeviceId)) {
            continue;
          }
          if (!_enabled) {
            unawaited(scanSub?.cancel());
            timeout?.cancel();
            unawaited(FlutterBluePlus.stopScan());
            if (!completer.isCompleted) completer.complete();
            return;
          }
          if (ManualModeService().enabled) {
            unawaited(scanSub?.cancel());
            timeout?.cancel();
            unawaited(FlutterBluePlus.stopScan());
            if (!completer.isCompleted) completer.complete();
            return;
          }
          unawaited(scanSub?.cancel());
          timeout?.cancel();
          unawaited(FlutterBluePlus.stopScan());
          unawaited(
            _doConnect(r.device)
                .catchError((Object e) {
                  _log.operation(
                    '自动连接: 连接异常',
                    detail: e.toString(),
                    level: LogLevel.error,
                  );
                })
                .whenComplete(() {
                  if (!completer.isCompleted) completer.complete();
                }),
          );
          return;
        }
      });

      timeout = Timer(BleTimings.autoConnectScanTimeout, () {
        unawaited(scanSub?.cancel());
        unawaited(FlutterBluePlus.stopScan());
        _log.operation('自动连接: 超时未找到设备', level: LogLevel.warning);
        if (!completer.isCompleted) completer.complete();
      });

      try {
        await FlutterBluePlus.startScan(
          timeout: BleTimings.autoConnectScanTimeout,
        );
      } on PlatformException catch (e) {
        _log.operation(
          '自动连接: 扫描权限不足',
          detail: e.toString(),
          level: LogLevel.warning,
        );
        if (!completer.isCompleted) completer.complete();
        return;
      } catch (e) {
        _log.operation(
          '自动连接: 扫描启动失败',
          detail: e.toString(),
          level: LogLevel.warning,
        );
        if (!completer.isCompleted) completer.complete();
        return;
      }
      await completer.future;
    } finally {
      unawaited(scanSub?.cancel());
      timeout?.cancel();
      unawaited(FlutterBluePlus.stopScan());
    }
  }

  void _refreshTarget() {
    final defaultVehicle = VehicleStore().defaultVehicle;
    _lastDeviceId = defaultVehicle?.id ?? _lastDeviceId;
    _lastDeviceName = defaultVehicle?.displayName ?? _lastDeviceName;
  }

  Future<void> _doConnect(BluetoothDevice device) async {
    final manager = _connectionManager;
    if (manager == null) return;
    final deviceId = device.remoteId.toString();
    try {
      final vehicle = VehicleStore().defaultVehicle;
      // Local QGJ credentials were scrubbed; keep zero defaults for login frame.
      manager.setQgjCredentials(password: 0, userId: 0);
      await manager.connect(device);
      if (_isConnectedAutoTarget(
        manager: manager,
        device: device,
        deviceId: deviceId,
      )) {
        _log.operation('自动连接: 成功', detail: vehicle?.displayName ?? deviceId);
      }
    } catch (e) {
      _log.operation('自动连接: 失败', detail: e.toString(), level: LogLevel.warning);
    }
  }

  bool _isConnectedAutoTarget({
    required ConnectionManager manager,
    required BluetoothDevice device,
    required String deviceId,
  }) {
    return _targetGuard.allowsConnectedTarget(
      autoConnectEnabled: _enabled,
      manualModeEnabled: ManualModeService().enabled,
      defaultVehicleId: VehicleStore().defaultVehicle?.id,
      deviceId: deviceId,
      manager: manager,
      device: device,
      currentManager: _connectionManager,
      snapshotGuard: _connectionSnapshotGuard,
    );
  }

  static bool _sameDeviceId(String a, String b) {
    final left = a.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    final right = b.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    return left.isNotEmpty && left == right;
  }
}
