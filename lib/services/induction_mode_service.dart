import 'dart:async';
import 'dart:collection';

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

  const InductionModeSnapshot({
    required this.stack,
    required this.enabled,
    required this.distance,
    required this.busy,
    required this.bleReady,
    this.lastError,
  });

  static const empty = InductionModeSnapshot(
    stack: InductionStack.none,
    enabled: null,
    distance: null,
    busy: false,
    bleReady: false,
  );

  InductionModeSnapshot copyWith({
    InductionStack? stack,
    bool? enabled,
    int? distance,
    bool? busy,
    bool? bleReady,
    String? lastError,
    bool clearError = false,
  }) {
    return InductionModeSnapshot(
      stack: stack ?? this.stack,
      enabled: enabled ?? this.enabled,
      distance: distance ?? this.distance,
      busy: busy ?? this.busy,
      bleReady: bleReady ?? this.bleReady,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

/// Unified induction / proximity unlock facade.
///
/// Mirrors official three paths:
/// - QGJ: `setProximityStatus` + `setHidStatus` + system bond
/// - TLink: `openMode` / `closeMode` / `setModeDistance` + system bond
/// - RSSI: phone `readRemoteRssi` → auto lock/unlock (KKS / legacy)
class InductionModeService {
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

  // RSSI path runtime
  Timer? _rssiTimer;
  final ListQueue<int> _rssiSamples = ListQueue<int>();
  RssiTaskState _rssiTaskState = RssiTaskState.idle;
  bool _rssiFiring = false;
  int? _boundModelType;
  String? _boundCarId;

  Stream<InductionModeSnapshot> get snapshotStream => _controller.stream;
  InductionModeSnapshot get snapshot => _snapshot;

  void bindVehicle({required int? modelType, required String? carId}) {
    final changed = _boundModelType != modelType || _boundCarId != carId;
    _boundModelType = modelType;
    _boundCarId = carId;
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
    // If already on a live TLink/QGJ session without known modelType, infer.
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
        _snapshot.copyWith(busy: false, lastError: e.toString(), bleReady: true),
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
          lastError: '读取 TLink 感应状态超时',
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
    if (enabled) {
      _startRssiLoop();
    } else {
      _stopRssiLoop();
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    final stack = resolveStack(_boundModelType);
    if (!_bleReadyFor(stack)) {
      _publish(_snapshot.copyWith(lastError: '请先连接车辆蓝牙并完成协议登录'));
      return false;
    }
    if (_manual.enabled) {
      _publish(_snapshot.copyWith(lastError: '已开启手动模式，无法开关感应解锁'));
      return false;
    }
    _publish(_snapshot.copyWith(busy: true, clearError: true, stack: stack));
    try {
      final ok = switch (stack) {
        InductionStack.qgj => await _setQgjEnabled(enabled),
        InductionStack.tlink => await _setTlinkEnabled(enabled),
        InductionStack.rssi => await _setRssiEnabled(enabled),
        InductionStack.none => false,
      };
      if (!ok) {
        _publish(
          _snapshot.copyWith(
            busy: false,
            lastError: enabled ? '开启感应解锁失败' : '关闭感应解锁失败',
          ),
        );
        return false;
      }
      await _saveEnabledPref(enabled);
      _publish(
        _snapshot.copyWith(
          enabled: enabled,
          busy: false,
          bleReady: true,
          clearError: true,
        ),
      );
      return true;
    } catch (e) {
      _publish(_snapshot.copyWith(busy: false, lastError: e.toString()));
      return false;
    }
  }

  Future<bool> _setQgjEnabled(bool enabled) async {
    // Official: open HID first, then proximity; close proximity then HID + remove.
    if (enabled) {
      // Drop stale bond so createBond can re-pair (official setHidStatus).
      await _cm.removeBond(quiet: true);
      await _cm.sendQgjCommand(
        QgjCommandIds.hidStatusSet,
        buildQgjHidPayload(QgjHidModes.open),
      );
      final response = await _cm.sendQgjCommand(
        QgjCommandIds.proximityStatusSet,
        buildQgjProximityStatusPayload(true),
      );
      if (response?.success != true) return false;
      await _cm.createBond(quiet: true);
      return true;
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
    return response?.success == true;
  }

  Future<bool> _setTlinkEnabled(bool enabled) async {
    if (enabled) {
      final ok = await _cm.openTlinkInduction();
      if (!ok) return false;
      // Official pairingDevice after open ACK.
      final bonded = await _cm.createBond(quiet: true);
      if (bonded) {
        await _cm.writeStandardHex(tlinkHidOpenAfterBondPlain);
      }
      return true;
    }
    final ok = await _cm.closeTlinkInduction();
    // C39 (10/14) official still removes bond for non-C39; we always remove.
    await _cm.removeBond(quiet: true);
    return ok;
  }

  Future<bool> _setRssiEnabled(bool enabled) async {
    if (enabled) {
      _startRssiLoop();
    } else {
      _stopRssiLoop();
      _rssiTaskState = RssiTaskState.idle;
    }
    return true;
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
        _snapshot.copyWith(
          distance: value,
          busy: false,
          clearError: true,
        ),
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

    final distance = estimateDistanceFromRssiSamples(_rssiSamples);
    final action = classifyDistance(distance);
    if (!shouldFireRssiAction(action, _rssiTaskState)) {
      if (action == RssiProximityAction.hold) {
        // Official clears task state when in the dead-band.
        if (_rssiTaskState == RssiTaskState.pending) {
          // keep pending until ACK
        }
      }
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
          // Follow with power on like official START path.
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
      _log.operation('RSSI 感应指令失败', detail: e.toString(), level: LogLevel.warning);
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
    _publish(InductionModeSnapshot.empty);
  }

  void dispose() {
    _stopRssiLoop();
    unawaited(_connSub?.cancel());
    _connSub = null;
    if (!_controller.isClosed) {
      unawaited(_controller.close());
    }
  }
}
