import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import 'package:shared_preferences/shared_preferences.dart';
import '../ble/constants.dart';
import '../ble/connection_manager.dart';
import '../ble/official_ble_connection_context.dart';
import '../ble/qgj_scan_identity.dart';
import '../models/vehicle_profile.dart';

import 'ble_connection_snapshot_guard.dart';
import 'log_service.dart';
import 'manual_mode_service.dart';
import 'permission_service.dart';
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
  OfficialBleConnectionContext? _officialContext;
  OfficialBleConnectionContext? _scanContext;
  String? get lastDeviceName => _lastDeviceName;

  /// Test hook: replace BLE permission gate used before auto-scan.
  @visibleForTesting
  Future<PermissionCheckResult> Function({bool request})?
  permissionRequestOverride;

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
    _officialContext = null;
    _scanContext = null;
    _initialized = false;
    _initializing = null;
    permissionRequestOverride = null;
    _clock = clock ?? DateTime.now;
  }

  Future<PermissionCheckResult> _ensureBleScanPermissions({
    bool request = true,
  }) {
    final override = permissionRequestOverride;
    if (override != null) {
      return override(request: request);
    }
    return AppPermissionService().requestBleScanPermissions(request: request);
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
    OfficialBleConnectionContext? context,
    bool enable = true,
    bool connectNow = true,

    /// Chip / explicit user action: connect even when 手动模式 is on.
    bool ignoreManualMode = false,
  }) async {
    final id = deviceId.trim();
    if (id.isEmpty) return;

    await _disconnectIfDifferentTarget(id, context: context);
    _officialContext = context;
    _connectionManager?.setOfficialConnectionContext(context);

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
      await tryAutoConnect(ignoreManualMode: ignoreManualMode);
    }
  }

  /// Disconnect when the active BLE session is for another MAC/device id.
  ///
  /// [ConnectionManager.disconnect] also completes pending commands / GATT ops.
  Future<void> _disconnectIfDifferentTarget(
    String targetDeviceId, {
    OfficialBleConnectionContext? context,
  }) async {
    final manager = _connectionManager;
    if (manager == null) return;
    if (manager.state == ConnectionState.disconnected) return;

    final currentTarget = manager.connectionContext?.targetMacCompact ?? '';
    if (currentTarget.isNotEmpty &&
        sameDeviceId(currentTarget, targetDeviceId)) {
      return;
    }

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
    final officialTarget = manager.connectionContext?.targetMacCompact ?? '';
    if (officialTarget.isNotEmpty) {
      return sameDeviceId(officialTarget, targetDeviceId);
    }
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

  Future<void> tryAutoConnect({bool ignoreManualMode = false}) async {
    await _runGate.run(
      () => _tryAutoConnectOnce(ignoreManualMode: ignoreManualMode),
    );
  }

  Future<void> _tryAutoConnectOnce({bool ignoreManualMode = false}) async {
    await VehicleStore().init();
    _refreshTarget();
    await ManualModeService().init();
    if (!ignoreManualMode && ManualModeService().enabled) {
      _log.operation('自动连接: 已开启手动模式，跳过', level: LogLevel.info);
      return;
    }
    final manager = _connectionManager;
    final targetDeviceId = _lastDeviceId;
    final targetDeviceName = _lastDeviceName;
    final targetContext = _officialContext;
    _scanContext = targetContext;
    if (!_enabled || targetDeviceId == null || manager == null) {
      return;
    }
    if (manager.state != ConnectionState.disconnected) return;

    // Auto-scan must not skip the runtime permission prompt. Without this,
    // first-run 爱车 auto-link fails silently when the user never opened Scan.
    final permission = await _ensureBleScanPermissions(request: true);
    if (!permission.granted) {
      _log.operation(
        '自动连接: 缺少蓝牙/定位权限',
        detail: permission.message ?? 'denied',
        level: LogLevel.warning,
      );
      return;
    }

    final adapterState = await _readAdapterState();
    if (adapterState != BluetoothAdapterState.on) {
      _log.operation(
        '自动连接: 蓝牙未开启',
        detail: adapterState.name,
        level: LogLevel.warning,
      );
      return;
    }

    if (targetContext != null) {
      _logMissingCredentials(targetContext);
    }

    // Official TLink ControlFragment.initBleTLink connects via
    // BluetoothAdapter.getRemoteDevice(mac) first — no scan required when the
    // classic MAC is known. Mirror that on Android before falling back to scan.
    // Also try identity/btmac for non-QGJ stacks when they differ.
    if (await _tryDirectMacConnect(
      targetDeviceId: targetDeviceId,
      targetDeviceName: targetDeviceName,
      context: targetContext,
    )) {
      return;
    }
    if (manager.state != ConnectionState.disconnected) return;

    _log.operation('自动连接: 扫描 $targetDeviceName ($targetDeviceId)');

    StreamSubscription<List<ScanResult>>? scanSub;
    Timer? timeout;
    var sawHarmonyQgj = false;
    final completer = Completer<void>();
    try {
      scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final foundId = r.device.remoteId.toString();
          final matchesSystemId = _sameDeviceId(foundId, targetDeviceId);
          final match = _matchesScanResult(
            r,
            targetDeviceId: targetDeviceId,
            context: targetContext,
            matchesSystemId: matchesSystemId,
          );
          if (targetContext?.stack == OfficialBleStack.qgj &&
              parseQgjScanIdentity(r.advertisementData).harmony) {
            sawHarmonyQgj = true;
          }
          if (!match) {
            continue;
          }
          if (!_enabled) {
            unawaited(scanSub?.cancel());
            timeout?.cancel();
            unawaited(FlutterBluePlus.stopScan());
            if (!completer.isCompleted) completer.complete();
            return;
          }
          if (!ignoreManualMode && ManualModeService().enabled) {
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
        _log.operation(
          sawHarmonyQgj ? '自动连接: Harmony QGJ 缺少 systemId' : '自动连接: 超时未找到设备',
          level: LogLevel.warning,
        );
        if (!completer.isCompleted) completer.complete();
      });

      try {
        await FlutterBluePlus.startScan(
          timeout: BleTimings.autoConnectScanTimeout,
          androidUsesFineLocation: true,
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
      _scanContext = null;
      unawaited(scanSub?.cancel());
      timeout?.cancel();
      unawaited(FlutterBluePlus.stopScan());
    }
  }

  Future<BluetoothAdapterState> _readAdapterState() async {
    try {
      return await FlutterBluePlus.adapterState
          .where((state) => state != BluetoothAdapterState.unknown)
          .first
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      _log.operation(
        '自动连接: 读取蓝牙开关状态失败',
        detail: e.toString(),
        level: LogLevel.debug,
      );
      return BluetoothAdapterState.unknown;
    }
  }

  void _logMissingCredentials(OfficialBleConnectionContext context) {
    if (context.stack == OfficialBleStack.tlink &&
        !context.hasTLinkCredentials) {
      _log.operation(
        '自动连接: TLink 登录凭据不完整',
        detail:
            'uid=${context.userId.isEmpty ? "empty" : "ok"} '
            'password=${context.selectedPassword == null ? "missing" : "ok"} '
            'shared=${context.shared}',
        level: LogLevel.warning,
      );
    }
    if (context.stack == OfficialBleStack.qgj && !context.hasQgjCredentials) {
      _log.operation(
        '自动连接: QGJ 登录凭据不完整',
        detail:
            'uid=${context.userId.isEmpty ? "empty" : "ok"} '
            'password=${context.selectedPassword == null ? "missing" : "ok"}',
        level: LogLevel.warning,
      );
    }
  }

  /// Official TLink path: `getBluetoothDeviceByMac(getRealMacForMac(mac))`
  /// then `connectDevice` without a prior LE scan.
  ///
  /// Returns true when a connect attempt was started (success or hard failure
  /// already logged). Returns false to fall through to scan matching.
  Future<bool> _tryDirectMacConnect({
    required String targetDeviceId,
    required String? targetDeviceName,
    required OfficialBleConnectionContext? context,
  }) async {
    // iOS remoteIds are opaque UUIDs — MAC direct connect is Android-only.
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    final stack = context?.stack;
    // QGJ identity lives in manufacturer data, not the radio address.
    if (stack == OfficialBleStack.qgj) return false;

    final colonMac = formatBleMacAddress(targetDeviceId);
    if (colonMac.isEmpty) return false;

    _log.operation(
      '自动连接: 直连 MAC',
      detail: '$targetDeviceName ($colonMac) stack=${stack?.name ?? "unknown"}',
    );
    try {
      final device = BluetoothDevice.fromId(colonMac);
      await _doConnect(device, context: context);
      final manager = _connectionManager;
      if (manager == null) return true;
      // GATT up or still handshaking counts as "attempt consumed".
      return manager.state != ConnectionState.disconnected;
    } catch (e) {
      _log.operation(
        '自动连接: 直连失败，改扫描',
        detail: e.toString(),
        level: LogLevel.info,
      );
      return false;
    }
  }

  void _refreshTarget() {
    final defaultVehicle = VehicleStore().defaultVehicle;
    _lastDeviceId = defaultVehicle?.id ?? _lastDeviceId;
    _lastDeviceName = defaultVehicle?.displayName ?? _lastDeviceName;
  }

  Future<void> _doConnect(
    BluetoothDevice device, {
    OfficialBleConnectionContext? context,
  }) async {
    final manager = _connectionManager;
    if (manager == null) return;
    final connectionContext = context ?? _scanContext;
    final deviceId = device.remoteId.toString();
    try {
      final vehicle = VehicleStore().defaultVehicle;
      manager.setOfficialConnectionContext(connectionContext);
      await manager.connect(device, context: connectionContext);
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

  static bool _matchesScanResult(
    ScanResult result, {
    required String targetDeviceId,
    required OfficialBleConnectionContext? context,
    required bool matchesSystemId,
  }) {
    if (context == null) return matchesSystemId;
    return switch (context.stack) {
      // Official KKS BleConnectService matches getBtname(); also accept MAC.
      OfficialBleStack.kks =>
        matchesSystemId ||
            _advertisedNameMatches(result, context.advertisedName),
      // Official TLink connects by mac; name is a useful scan fallback when
      // the cloud classic MAC differs from the current LE address.
      OfficialBleStack.tlink =>
        matchesSystemId ||
            _advertisedNameMatches(result, context.advertisedName),
      OfficialBleStack.qgj =>
        _matchesQgjAdvertisement(
              targetMac: targetDeviceId,
              identity: parseQgjScanIdentity(result.advertisementData),
            ) &&
            result.advertisementData.serviceUuids.any(
              (uuid) =>
                  uuid.toString().toLowerCase().contains('feb0') ||
                  uuid.toString().toLowerCase().contains('ffe1'),
            ),
      OfficialBleStack.unsupported => false,
    };
  }

  static bool _advertisedNameMatches(ScanResult result, String expected) {
    final name = expected.trim();
    if (name.isEmpty) return false;
    final adv = result.advertisementData.advName.trim();
    final platform = result.device.platformName.trim();
    return (adv.isNotEmpty && adv == name) ||
        (platform.isNotEmpty && platform == name);
  }

  /// Android classic/LE address form `AA:BB:CC:DD:EE:FF` for [BluetoothDevice.fromId].
  @visibleForTesting
  static String formatBleMacAddress(String raw) {
    final compact = raw.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    if (compact.length != 12) return '';
    final parts = <String>[];
    for (var i = 0; i < 12; i += 2) {
      parts.add(compact.substring(i, i + 2));
    }
    return parts.join(':');
  }

  @visibleForTesting
  static bool matchesQgjIdentity({
    required String targetMac,
    required String? observedMac,
    required int bootMode,
    required bool harmony,
  }) {
    return !harmony &&
        bootMode == 0 &&
        observedMac != null &&
        _sameDeviceId(observedMac, targetMac);
  }

  static bool _matchesQgjAdvertisement({
    required String targetMac,
    required QgjScanIdentity identity,
  }) {
    return matchesQgjIdentity(
      targetMac: targetMac,
      observedMac: identity.identityMac,
      bootMode: identity.bootMode,
      harmony: identity.harmony,
    );
  }

  bool _isConnectedAutoTarget({
    required ConnectionManager manager,
    required BluetoothDevice device,
    required String deviceId,
  }) {
    final context = _officialContext;
    if (context != null) {
      return _enabled &&
          !ManualModeService().enabled &&
          manager.isProtocolLoggedIn &&
          manager.state == ConnectionState.ready &&
          identical(manager, _connectionManager) &&
          identical(device, manager.device) &&
          sameDeviceId(
            manager.connectionContext?.targetMacCompact ?? '',
            context.targetMacCompact,
          );
    }
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
