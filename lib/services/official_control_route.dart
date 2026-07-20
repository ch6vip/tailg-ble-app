/// Official control-path routing extracted from decompiled
/// `ControlFragment.lock()` / `start()` + `ControlTypeUtil`.
///
/// This encodes **transport selection only** (BLE vs remote). Official remote
/// is MQTT (project: OfficialMqttService.sendCommandPreferMqtt with HTTP
/// `app/device/cmd/*` fallback). **When** to choose remote vs BLE follows the
/// official decision tree (`modelType` / `isGps` / BLE LOGIN).
library;

enum OfficialBleStackKind {
  /// TLinkBleManager / BleHandler path (KKS, C39, BB, GPS combo…).
  standard,

  /// TLinkBleManagerQgj path (modelType 8 / 283).
  qgj,

  /// Remote-only models (e.g. YJ) never use local BLE for control.
  none,
}

enum OfficialControlTransportChoice {
  /// Local BLE after protocol LOGIN (`LoginStatus.LOGIN`).
  ble,

  /// Remote control (official MQTT; HTTP cmd as fallback).
  cloud,

  /// No usable path.
  unavailable,
}

class OfficialControlRouteDecision {
  final OfficialControlTransportChoice transport;
  final OfficialBleStackKind bleStack;
  final String reason;

  const OfficialControlRouteDecision({
    required this.transport,
    required this.bleStack,
    required this.reason,
  });

  bool get usesBle => transport == OfficialControlTransportChoice.ble;
  bool get usesCloud => transport == OfficialControlTransportChoice.cloud;
  bool get isUnavailable =>
      transport == OfficialControlTransportChoice.unavailable;
}

/// Pure routing table matching official `ControlFragment` control keys.
class OfficialControlRoute {
  const OfficialControlRoute._();

  /// QGJ model types (`ControlTypeUtil.isQgj` + 283 variant in ControlFragment).
  static const qgjModelTypes = {8, 283};

  /// C39 family.
  static const c39ModelTypes = {10, 14};

  /// GPS combo models that fall back to remote when BLE is not LOGIN,
  /// without an extra `isGps == 1` gate (see lock cases 401/928/2103/2201).
  static const gpsComboModelTypes = {401, 928, 2103, 2201};

  /// Model types for which ControlFragment has no implementation for the
  /// primary control actions. Keep them unavailable instead of guessing a
  /// transport and sending a command the official app would ignore.
  static const unsupportedControlModelTypes = {1501, 1601, 1701};

  /// Known model types handled by the official control fragment.
  static const supportedControlModelTypes = {
    1,
    2,
    3,
    8,
    10,
    14,
    283,
    401,
    928,
    2103,
    2201,
  };

  /// Resolve which transport official control would take for a bound vehicle.
  ///
  /// [bleReady] **must** mean official `LoginStatus.LOGIN` (or
  /// `bleIsConnectedField` for KKS modelType 1). Feed
  /// `ConnectionManager.isProtocolLoggedIn` — not mere GATT
  /// `ConnectionState.connected` / raw `ready` without credential.
  /// [networkReady] corresponds to `NetworkUtils.isConnected()`.
  /// [cloudSessionReady] is our stand-in for "can talk to remote backend"
  /// (signed-in + selected vehicle). MQTT connect is ensured at send time via
  /// OfficialMqttService.ensureConnected.
  static OfficialControlRouteDecision resolve({
    required bool bindingCar,
    required int? modelType,
    required int? isGps,
    required bool bleReady,
    bool networkReady = true,
    bool cloudSessionReady = false,
  }) {
    if (!bindingCar) {
      return const OfficialControlRouteDecision(
        transport: OfficialControlTransportChoice.unavailable,
        bleStack: OfficialBleStackKind.none,
        reason: '未绑定车辆',
      );
    }

    final cloudReady = networkReady && cloudSessionReady;
    final type = modelType ?? -1;

    if (!supportedControlModelTypes.contains(type) ||
        unsupportedControlModelTypes.contains(type)) {
      return const OfficialControlRouteDecision(
        transport: OfficialControlTransportChoice.unavailable,
        bleStack: OfficialBleStackKind.none,
        reason: '当前车型暂不支持控车',
      );
    }

    // --- modelType 1: KKS ---
    // if (bleIsConnected) BLE else MQTT
    if (type == 1) {
      if (bleReady) {
        return const OfficialControlRouteDecision(
          transport: OfficialControlTransportChoice.ble,
          bleStack: OfficialBleStackKind.standard,
          reason: '',
        );
      }
      if (cloudReady) {
        return const OfficialControlRouteDecision(
          transport: OfficialControlTransportChoice.cloud,
          bleStack: OfficialBleStackKind.standard,
          reason: '',
        );
      }
      return OfficialControlRouteDecision(
        transport: OfficialControlTransportChoice.unavailable,
        bleStack: OfficialBleStackKind.standard,
        reason: !networkReady ? '手机网络未连接' : '请先登录官方账号并选择车辆',
      );
    }

    // --- modelType 2: YJ — cloud only ---
    if (type == 2) {
      if (cloudReady) {
        return const OfficialControlRouteDecision(
          transport: OfficialControlTransportChoice.cloud,
          bleStack: OfficialBleStackKind.none,
          reason: '',
        );
      }
      return OfficialControlRouteDecision(
        transport: OfficialControlTransportChoice.unavailable,
        bleStack: OfficialBleStackKind.none,
        reason: !networkReady ? '手机网络未连接' : '请先登录官方账号并选择车辆',
      );
    }

    // --- modelType 8 / 283: QGJ ---
    // if (isGps == 1 && bleConnectStatusQgj != LOGIN) → MQTT
    // else require BLE LOGIN → QGJ local
    if (qgjModelTypes.contains(type)) {
      return _hybridIsGpsGate(
        isGps: isGps,
        bleReady: bleReady,
        cloudReady: cloudReady,
        networkReady: networkReady,
        bleStack: OfficialBleStackKind.qgj,
      );
    }

    // --- modelType 10 / 14: C39 ---
    // same gate with standard BLE status
    if (c39ModelTypes.contains(type)) {
      return _hybridIsGpsGate(
        isGps: isGps,
        bleReady: bleReady,
        cloudReady: cloudReady,
        networkReady: networkReady,
        bleStack: OfficialBleStackKind.standard,
      );
    }

    // --- modelType 401 / 928 / 2103 / 2201 ---
    // if (ble != LOGIN) → MQTT else BLE (no isGps gate)
    if (gpsComboModelTypes.contains(type)) {
      if (bleReady) {
        return const OfficialControlRouteDecision(
          transport: OfficialControlTransportChoice.ble,
          bleStack: OfficialBleStackKind.standard,
          reason: '',
        );
      }
      if (cloudReady) {
        return const OfficialControlRouteDecision(
          transport: OfficialControlTransportChoice.cloud,
          bleStack: OfficialBleStackKind.standard,
          reason: '',
        );
      }
      return OfficialControlRouteDecision(
        transport: OfficialControlTransportChoice.unavailable,
        bleStack: OfficialBleStackKind.standard,
        reason: !networkReady ? '手机网络未连接' : '请先登录官方账号并选择车辆',
      );
    }

    // --- modelType 3 (BB) ---
    return _hybridIsGpsGate(
      isGps: isGps,
      bleReady: bleReady,
      cloudReady: cloudReady,
      networkReady: networkReady,
      bleStack: OfficialBleStackKind.standard,
    );
  }

  /// Official pattern used by QGJ / C39 / BB:
  /// `isGps == 1 && ble != LOGIN` → remote; else require BLE LOGIN.
  static OfficialControlRouteDecision _hybridIsGpsGate({
    required int? isGps,
    required bool bleReady,
    required bool cloudReady,
    required bool networkReady,
    required OfficialBleStackKind bleStack,
  }) {
    if (isGps == 1 && !bleReady) {
      if (cloudReady) {
        return OfficialControlRouteDecision(
          transport: OfficialControlTransportChoice.cloud,
          bleStack: bleStack,
          reason: '',
        );
      }
      return OfficialControlRouteDecision(
        transport: OfficialControlTransportChoice.unavailable,
        bleStack: bleStack,
        reason: !networkReady ? '手机网络未连接' : '请先登录官方账号并选择车辆',
      );
    }

    if (bleReady) {
      return OfficialControlRouteDecision(
        transport: OfficialControlTransportChoice.ble,
        bleStack: bleStack,
        reason: '',
      );
    }

    return OfficialControlRouteDecision(
      transport: OfficialControlTransportChoice.unavailable,
      bleStack: bleStack,
      reason: '蓝牙未连接',
    );
  }
}
