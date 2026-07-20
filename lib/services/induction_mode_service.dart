import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/connection_manager.dart';
import '../ble/constants.dart';
import '../ble/qgj_protocol.dart';
import '../ble/rssi_distance.dart';
import '../ble/tlink_protocol.dart';
import 'log_service.dart';
import 'manual_mode_service.dart';
import 'official_control_route.dart';

/// Which official induction stack a [modelType] uses.
enum InductionStack {
  /// QGJ HID + Proximity (`0x2030–0x2033` / `0x2140`).
  qgj,

  /// TLink ECU mode (`4A33` open/close + bond).
  tlink,

  /// Phone-side RSSI estimator (`BleConnectService`) for KKS / legacy.
  rssi,

  /// No local induction path (e.g. pure cloud YJ without BLE).
  none,
}

/// Snapshot exposed to UI.
class InductionModeSnapshot {
  final InductionStack stack;
  final bool? enabled;
  final int? distance;
  final bool busy;
  final bool bleReady;
  final String? lastError;

  /// ECU mode is on, but system BLE bond did not complete.
  final bool bondIncomplete;

  const InductionModeSnapshot({
    required this.stack,
    required this.enabled,
    required this.distance,
    required this.busy,
    required this.bleReady,
    this.lastError,
    this.bondIncomplete = false,
  });

  static const empty = InductionModeSnapshot(
    stack: InductionStack.none,
    enabled: null,
    distance: null,
    busy: false,
    bleReady: false,
  );

  /// true = induction, false = manual, null = unknown / still reading.
  bool? get unlockSelection {
    if (stack == InductionStack.none) return false;
    if (enabled == null) return null;
    return enabled;
  }

  InductionModeSnapshot copyWith({
    InductionStack? stack,
    bool? enabled,
    int? distance,
    bool? busy,
    bool? bleReady,
    String? lastError,
    bool? bondIncomplete,
    bool clearError = false,
    bool clearEnabled = false,
  }) {
    return InductionModeSnapshot(
      stack: stack ?? this.stack,
      enabled: clearEnabled ? null : (enabled ?? this.enabled),
      distance: distance ?? this.distance,
      busy: busy ?? this.busy,
      bleReady: bleReady ?? this.bleReady,
      lastError: clearError ? null : (lastError ?? this.lastError),
      bondIncomplete: bondIncomplete ?? this.bondIncomplete,
    );
  }
}

/// Optional RSSI path-loss calibration (official CarControlInfoBean fields).
class RssiCalibration {
  final double rssiA;
  final double rssiFactor;
  final double minDistanceM;
  final double maxDistanceM;

  const RssiCalibration({
    this.rssiA = defaultRssiA,
    this.rssiFactor = defaultRssiFactor,
    this.minDistanceM = defaultMinDistanceM,
    this.maxDistanceM = defaultMaxDistanceM,
  });

  factory RssiCalibration.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const RssiCalibration();
    double parse(dynamic v, double fallback) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    return RssiCalibration(
      rssiA: parse(map['rssiA'] ?? map['RssiA'], defaultRssiA),
      rssiFactor: parse(
        map['rssiFactor'] ?? map['RssiFactor'],
        defaultRssiFactor,
      ),
      minDistanceM: parse(
        map['minRssiDistance'] ?? map['MinRssiDistance'],
        defaultMinDistanceM,
      ),
      maxDistanceM: parse(
        map['maxRssiDistance'] ?? map['MaxRssiDistance'],
        defaultMaxDistanceM,
      ),
    );
  }
}

/// Unified induction / proximity unlock facade.
///
/// Mirrors official three paths:
/// - QGJ: `setProximityStatus` + `setHidStatus` + system bond
/// - TLink: `openMode` / `closeMode` / `setModeDistance` + system bond
/// - RSSI: phone `readRemoteRssi` → auto lock/unlock (KKS / legacy)
class InductionModeService with WidgetsBindingObserver {
  InductionModeService({
    required ConnectionManager connectionManager,
    ManualModeService? manualModeService,
    LogService? logService,
  }) : _cm = connectionManager,
       _manual = manualModeService ?? ManualModeService(),
       _log = logService ?? LogService();

  static const _prefEnabledPrefix = 'induction_enabled_';
  static const _prefDistancePrefix = 'induction_distance_';
  static const defaultDistanceLevel = 5;
  static const maxDistanceLevel = 30;

  final ConnectionManager _cm;
  final ManualModeService _manual;
  final LogService _log;

  InductionModeSnapshot _snapshot = InductionModeSnapshot.empty;
  final _controller = StreamController<InductionModeSnapshot>.broadcast();
  StreamSubscription<ConnectionState>? _connSub;
  bool _observingLifecycle = false;
  bool _appInForeground = true;

  // RSSI path runtime
  Timer? _rssiTimer;
  final ListQueue<int> _rssiSamples = ListQueue<int>();
  RssiTaskState _rssiTaskState = RssiTaskState.idle;
  bool _rssiFiring = false;
  RssiCalibration _rssiCalibration = const RssiCalibration();
  int? _boundModelType;
  String? _boundCarId;

  Stream<InductionModeSnapshot> get snapshotStream => _controller.stream;
  InductionModeSnapshot get snapshot => _snapshot;

  void bindVehicle({
    required int? modelType,
    required String? carId,
    Map<String, dynamic>? vehicleRaw,
  }) {
    _ensureLifecycleObserver();
    final changed = _boundModelType != modelType || _boundCarId != carId;
    _boundModelType = modelType;
    _boundCarId = carId;
    _rssiCalibration = RssiCalibration.fromMap(vehicleRaw);
    _connSub ??= _cm.stateStream.listen((_) {
      unawaited(_onConnectionChanged());
    });
    if (changed) {
      _stopRssiLoop();
      _publish(
        InductionModeSnapshot(
          stack: stackForModelType(modelType),
          enabled: null,
          distance: null,
          busy: false,
          bleReady: _bleReadyFor(stackForModelType(modelType)),
        ),
      );
      unawaited(refresh(force: true));
    } else {
      unawaited(_onConnectionChanged());
    }
  }

  void _ensureLifecycleObserver() {
    if (_observingLifecycle) return;
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    setAppForeground(fg);
  }

  /// Pause RSSI polling in background to save battery.
  void setAppForeground(bool foreground) {
    if (_appInForeground == foreground) return;
    _appInForeground = foreground;
    if (!foreground) {
      _stopRssiLoop();
      return;
    }
    final stack = resolveStack(_boundModelType);
    if (stack == InductionStack.rssi &&
        _snapshot.enabled == true &&
        _bleReadyFor(stack)) {
      _startRssiLoop();
    }
  }

  static InductionStack stackForModelType(int? modelType) {
    final type = modelType ?? -1;
    if (OfficialControlRoute.qgjModelTypes.contains(type)) {
      return InductionStack.qgj;
    }
    // TLink openMode models (ControlFragment iv_mode cases).
    if (type == 3 ||
        OfficialControlRoute.c39ModelTypes.contains(type) ||
        OfficialControlRoute.gpsComboModelTypes.contains(type)) {
      return InductionStack.tlink;
    }
    // KKS uses phone RSSI / cloud blueOn; local BLE still benefits from RSSI.
    if (type == 1) return InductionStack.rssi;
    // YJ remote-only — no local induction over BLE in our route table.
    if (type == 2) return InductionStack.none;
    return InductionStack.none;
  }

  /// Infer stack from live BLE protocol when modelType is unknown / none.
  InductionStack resolveStack(int? modelType) {
    final byModel = stackForModelType(modelType);
    if (byModel != InductionStack.none) return byModel;
    return switch (_cm.protocol) {
      ProtocolType.qgj => InductionStack.qgj,
      ProtocolType.tlink => InductionStack.tlink,
      ProtocolType.kks => InductionStack.rssi,
      ProtocolType.unknown => InductionStack.none,
    };
  }

  bool _bleReadyFor(InductionStack stack) {
    if (!_cm.isProtocolLoggedIn) return false;
    return switch (stack) {
      InductionStack.qgj => _cm.protocol == ProtocolType.qgj,
      InductionStack.tlink => _cm.protocol == ProtocolType.tlink,
      InductionStack.rssi =>
        _cm.protocol == ProtocolType.kks || _cm.protocol == ProtocolType.tlink,
      InductionStack.none => false,
    };
  }

  Future<void> _onConnectionChanged() async {
    final stack = resolveStack(_boundModelType);
    final ready = _bleReadyFor(stack);
    if (!ready) {
      _stopRssiLoop();
      _publish(
        _snapshot.copyWith(
          stack: stack,
          bleReady: false,
          enabled: stack == InductionStack.rssi ? _snapshot.enabled : null,
        ),
      );
      return;
    }
    _publish(_snapshot.copyWith(stack: stack, bleReady: true));
    await refresh();
  }

  Future<void> refresh({bool force = false}) async {
    final stack = resolveStack(_boundModelType);
    final ready = _bleReadyFor(stack);
    if (!ready) {
      _publish(
        InductionModeSnapshot(
          stack: stack,
          enabled: stack == InductionStack.rssi
              ? await _loadEnabledPref()
              : null,
          distance: stack == InductionStack.rssi
              ? await _loadDistancePref()
              : null,
          busy: false,
          bleReady: false,
        ),
      );
      return;
    }

    if (_snapshot.busy && !force) return;
    _publish(
      _snapshot.copyWith(
        stack: stack,
        bleReady: true,
        busy: true,
        clearError: true,
      ),
    );

    try {
      switch (stack) {
        case InductionStack.qgj:
          await _refreshQgj();
        case InductionStack.tlink:
          await _refreshTlink();
        case InductionStack.rssi:
          await _refreshRssi();
        case InductionStack.none:
          _publish(InductionModeSnapshot.empty);
      }
    } catch (e) {
      _log.operation('读取感应状态失败', detail: e.toString(), level: LogLevel.debug);
      _publish(
        _snapshot.copyWith(
          busy: false,
          lastError: e.toString(),
          bleReady: true,
        ),
      );
    }
  }

  Future<void> _refreshQgj() async {
    final status = await _cm.sendQgjCommand(QgjCommandIds.proximityStatusGet);
    final distance = await _cm.sendQgjCommand(
      QgjCommandIds.proximityDistanceGet,
    );
    final enabled = status != null && status.success
        ? parseQgjProximityEnabled(status.payload)
        : null;
    final level = distance != null && distance.success
        ? parseQgjProximityDistance(distance.payload)
        : null;
    _publish(
      InductionModeSnapshot(
        stack: InductionStack.qgj,
        enabled: enabled,
        distance: level?.clamp(0, maxDistanceLevel),
        busy: false,
        bleReady: true,
      ),
    );
  }

  Future<void> _refreshTlink() async {
    final status = await _cm.checkTlinkInduction();
    if (status == null) {
      _publish(
        _snapshot.copyWith(
          stack: InductionStack.tlink,
          busy: false,
          bleReady: true,
          lastError: '读取感应状态超时，请重试',
        ),
      );
      return;
    }
    _publish(
      InductionModeSnapshot(
        stack: InductionStack.tlink,
        enabled: status.enabled,
        distance: status.distance,
        busy: false,
        bleReady: true,
      ),
    );
  }

  Future<void> _refreshRssi() async {
    final enabled = await _loadEnabledPref();
    final distance = await _loadDistancePref();
    _publish(
      InductionModeSnapshot(
        stack: InductionStack.rssi,
        enabled: enabled,
        distance: distance,
        busy: false,
        bleReady: true,
      ),
    );
    if (enabled && _appInForeground) {
      _startRssiLoop();
    } else {
      _stopRssiLoop();
    }
  }

  /// Toggle induction. When [enabled] is true, clears manual mode first so the
  /// home-page 感应|手动 switch cannot race with ManualModeService prefs.
  Future<bool> setEnabled(bool enabled, {bool clearManualMode = true}) async {
    final stack = resolveStack(_boundModelType);
    if (!_bleReadyFor(stack)) {
      _publish(_snapshot.copyWith(lastError: '请先连接车辆蓝牙并完成协议登录'));
      return false;
    }

    if (enabled && clearManualMode && _manual.enabled) {
      await _manual.setEnabled(false);
    }
    if (enabled && _manual.enabled) {
      _publish(_snapshot.copyWith(lastError: '已开启手动模式，无法开关感应解锁'));
      return false;
    }

    _publish(
      _snapshot.copyWith(
        busy: true,
        clearError: true,
        stack: stack,
        bondIncomplete: false,
      ),
    );
    try {
      final result = switch (stack) {
        InductionStack.qgj => await _setQgjEnabled(enabled),
        InductionStack.tlink => await _setTlinkEnabled(enabled),
        InductionStack.rssi => await _setRssiEnabled(enabled),
        InductionStack.none => const _EnableResult(ok: false),
      };
      if (!result.ok) {
        _publish(
          _snapshot.copyWith(
            busy: false,
            lastError: result.message ?? (enabled ? '开启感应解锁失败' : '关闭感应解锁失败'),
          ),
        );
        return false;
      }
      await _saveEnabledPref(enabled);
      _publish(
        InductionModeSnapshot(
          stack: stack,
          enabled: enabled,
          distance: _snapshot.distance,
          busy: false,
          bleReady: true,
          bondIncomplete: result.bondIncomplete,
          lastError: result.bondIncomplete
              ? '感应已开启，但系统蓝牙配对未完成。请在系统弹窗中允许配对，否则靠近解锁可能无效'
              : null,
        ),
      );
      return true;
    } catch (e) {
      _publish(_snapshot.copyWith(busy: false, lastError: e.toString()));
      return false;
    }
  }

  Future<_EnableResult> _setQgjEnabled(bool enabled) async {
    if (enabled) {
      await _cm.removeBond(quiet: true);
      await _cm.sendQgjCommand(
        QgjCommandIds.hidStatusSet,
        buildQgjHidPayload(QgjHidModes.open),
      );
      final response = await _cm.sendQgjCommand(
        QgjCommandIds.proximityStatusSet,
        buildQgjProximityStatusPayload(true),
      );
      if (response?.success != true) {
        return const _EnableResult(ok: false, message: '车辆未确认开启感应');
      }
      final bonded = await _cm.createBond(quiet: true);
      return _EnableResult(ok: true, bondIncomplete: !bonded);
    }
    final response = await _cm.sendQgjCommand(
      QgjCommandIds.proximityStatusSet,
      buildQgjProximityStatusPayload(false),
    );
    await _cm.sendQgjCommand(
      QgjCommandIds.hidStatusSet,
      buildQgjHidPayload(QgjHidModes.close),
    );
    await _cm.removeBond(quiet: true);
    return _EnableResult(
      ok: response?.success == true,
      message: response?.success == true ? null : '车辆未确认关闭感应',
    );
  }

  Future<_EnableResult> _setTlinkEnabled(bool enabled) async {
    if (enabled) {
      final ok = await _cm.openTlinkInduction();
      if (!ok) {
        return const _EnableResult(ok: false, message: '车辆未确认开启感应');
      }
      final bonded = await _cm.createBond(quiet: true);
      if (bonded) {
        await _cm.writeStandardHex(tlinkHidOpenAfterBondPlain);
      }
      return _EnableResult(ok: true, bondIncomplete: !bonded);
    }
    final ok = await _cm.closeTlinkInduction();
    await _cm.removeBond(quiet: true);
    return _EnableResult(ok: ok, message: ok ? null : '车辆未确认关闭感应');
  }

  Future<_EnableResult> _setRssiEnabled(bool enabled) async {
    if (enabled) {
      if (_appInForeground) {
        _startRssiLoop();
      }
    } else {
      _stopRssiLoop();
      _rssiTaskState = RssiTaskState.idle;
    }
    return const _EnableResult(ok: true);
  }

  Future<bool> setDistance(int level) async {
    final stack = resolveStack(_boundModelType);
    final value = level.clamp(0, maxDistanceLevel);
    if (!_bleReadyFor(stack)) {
      _publish(_snapshot.copyWith(lastError: '请先连接车辆蓝牙并完成协议登录'));
      return false;
    }
    _publish(_snapshot.copyWith(busy: true, clearError: true));
    try {
      final ok = switch (stack) {
        InductionStack.qgj => await _setQgjDistance(value),
        InductionStack.tlink => await _cm.setTlinkInductionDistance(value),
        InductionStack.rssi => true,
        InductionStack.none => false,
      };
      if (!ok) {
        _publish(_snapshot.copyWith(busy: false, lastError: '写入感应距离失败'));
        return false;
      }
      await _saveDistancePref(value);
      _publish(
        _snapshot.copyWith(distance: value, busy: false, clearError: true),
      );
      return true;
    } catch (e) {
      _publish(_snapshot.copyWith(busy: false, lastError: e.toString()));
      return false;
    }
  }

  Future<bool> _setQgjDistance(int value) async {
    final response = await _cm.sendQgjCommand(
      QgjCommandIds.proximityDistanceSet,
      buildQgjProximityDistancePayload(value),
    );
    return response?.success == true;
  }

  // ---------------------------------------------------------------------------
  // RSSI path
  // ---------------------------------------------------------------------------

  void _startRssiLoop() {
    if (!_appInForeground) return;
    if (_rssiTimer != null) return;
    _rssiSamples.clear();
    _rssiTaskState = RssiTaskState.idle;
    _rssiTimer = Timer.periodic(rssiPollInterval, (_) {
      unawaited(_rssiTick());
    });
    _log.operation('RSSI 感应轮询已启动', level: LogLevel.info);
  }

  void _stopRssiLoop() {
    _rssiTimer?.cancel();
    _rssiTimer = null;
    _rssiSamples.clear();
    _rssiFiring = false;
  }

  Future<void> _rssiTick() async {
    if (!_appInForeground) return;
    if (_manual.enabled) return;
    if (!_cm.isProtocolLoggedIn) return;
    if (_rssiFiring) return;
    final rssi = await _cm.readRemoteRssi();
    if (rssi == null) return;
    _rssiSamples.addLast(rssi);
    while (_rssiSamples.length > rssiSampleWindow) {
      _rssiSamples.removeFirst();
    }
    if (_rssiSamples.length < rssiSampleWindow) return;

    final distance = estimateDistanceFromRssiSamples(
      _rssiSamples,
      rssiA: _rssiCalibration.rssiA,
      rssiFactor: _rssiCalibration.rssiFactor,
    );
    final action = classifyDistance(
      distance,
      minDistanceM: _rssiCalibration.minDistanceM,
      maxDistanceM: _rssiCalibration.maxDistanceM,
    );
    if (!shouldFireRssiAction(action, _rssiTaskState)) {
      _rssiSamples.removeFirst();
      return;
    }

    _rssiFiring = true;
    _rssiTaskState = RssiTaskState.pending;
    try {
      if (action == RssiProximityAction.approachUnlock) {
        _log.operation(
          'RSSI 感应 → 解防',
          detail: 'd=${distance.toStringAsFixed(2)}m',
          level: LogLevel.info,
        );
        final ok = await _cm.sendCommand(CommandCode.unlock);
        if (ok) {
          await _cm.sendCommand(CommandCode.powerOn);
          _rssiTaskState = RssiTaskState.poweredOn;
        } else {
          _rssiTaskState = RssiTaskState.idle;
        }
      } else if (action == RssiProximityAction.leaveLock) {
        _log.operation(
          'RSSI 感应 → 设防',
          detail: 'd=${distance.toStringAsFixed(2)}m',
          level: LogLevel.info,
        );
        await _cm.sendCommand(CommandCode.powerOff);
        final ok = await _cm.sendCommand(CommandCode.lock);
        _rssiTaskState = ok ? RssiTaskState.locked : RssiTaskState.idle;
      }
    } catch (e) {
      _log.operation(
        'RSSI 感应指令失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      _rssiTaskState = RssiTaskState.idle;
    } finally {
      _rssiFiring = false;
      _rssiSamples.clear();
    }
  }

  // ---------------------------------------------------------------------------
  // Prefs
  // ---------------------------------------------------------------------------

  String get _enabledKey =>
      '$_prefEnabledPrefix${_boundCarId ?? _boundModelType ?? 'default'}';
  String get _distanceKey =>
      '$_prefDistancePrefix${_boundCarId ?? _boundModelType ?? 'default'}';

  Future<bool> _loadEnabledPref() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> _saveEnabledPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<int> _loadDistancePref() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_distanceKey) ?? defaultDistanceLevel;
  }

  Future<void> _saveDistancePref(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_distanceKey, value);
  }

  void _publish(InductionModeSnapshot next) {
    _snapshot = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  void resetForTest() {
    _stopRssiLoop();
    _rssiTaskState = RssiTaskState.idle;
    _boundModelType = null;
    _boundCarId = null;
    _rssiCalibration = const RssiCalibration();
    _appInForeground = true;
    _publish(InductionModeSnapshot.empty);
  }

  void dispose() {
    _stopRssiLoop();
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
    unawaited(_connSub?.cancel());
    _connSub = null;
    if (!_controller.isClosed) {
      unawaited(_controller.close());
    }
  }
}

class _EnableResult {
  final bool ok;
  final bool bondIncomplete;
  final String? message;

  const _EnableResult({
    required this.ok,
    this.bondIncomplete = false,
    this.message,
  });
}
