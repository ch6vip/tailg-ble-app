import '../models/official_vehicle.dart';
import 'official_cloud_service.dart';
import 'official_control_route.dart';

/// Preferred control channel preference (user/app policy).
///
/// When [automatic], transport is decided by [OfficialControlRoute] — the pure
/// decision table extracted from official ControlFragment / ControlTypeUtil.
enum OfficialControlChannel {
  automatic('自动', '完全按官方 modelType + isGps + BLE LOGIN 分流'),
  ble('BLE', '只使用本地蓝牙直连'),
  officialCloud('官方云端', '强制使用官方账号远程控车');

  final String label;
  final String description;

  const OfficialControlChannel(this.label, this.description);
}

class ControlChannelAvailability {
  final OfficialControlChannel channel;
  final OfficialControlRouteDecision? officialDecision;
  final bool canUseBle;
  final bool canUseCloud;
  final bool enabled;
  final bool willUseBle;
  final bool vehicleAllowsCloudFallback;
  final String effectiveChannelLabel;
  final String bleUnavailableReason;
  final String cloudUnavailableReason;
  final String disabledReason;

  const ControlChannelAvailability({
    required this.channel,
    required this.officialDecision,
    required this.canUseBle,
    required this.canUseCloud,
    required this.enabled,
    required this.willUseBle,
    required this.vehicleAllowsCloudFallback,
    required this.effectiveChannelLabel,
    required this.bleUnavailableReason,
    required this.cloudUnavailableReason,
    required this.disabledReason,
  });

  ControlChannelAvailability copyWith({
    OfficialControlChannel? channel,
    OfficialControlRouteDecision? officialDecision,
    bool? canUseBle,
    bool? canUseCloud,
    bool? enabled,
    bool? willUseBle,
    bool? vehicleAllowsCloudFallback,
    String? effectiveChannelLabel,
    String? bleUnavailableReason,
    String? cloudUnavailableReason,
    String? disabledReason,
  }) {
    return ControlChannelAvailability(
      channel: channel ?? this.channel,
      officialDecision: officialDecision ?? this.officialDecision,
      canUseBle: canUseBle ?? this.canUseBle,
      canUseCloud: canUseCloud ?? this.canUseCloud,
      enabled: enabled ?? this.enabled,
      willUseBle: willUseBle ?? this.willUseBle,
      vehicleAllowsCloudFallback:
          vehicleAllowsCloudFallback ?? this.vehicleAllowsCloudFallback,
      effectiveChannelLabel:
          effectiveChannelLabel ?? this.effectiveChannelLabel,
      bleUnavailableReason: bleUnavailableReason ?? this.bleUnavailableReason,
      cloudUnavailableReason:
          cloudUnavailableReason ?? this.cloudUnavailableReason,
      disabledReason: disabledReason ?? this.disabledReason,
    );
  }
}

class ControlChannelResolver {
  const ControlChannelResolver._();

  static ControlChannelAvailability resolve({
    required OfficialCloudState cloudState,

    /// Official LoginStatus.LOGIN equivalent (use ConnectionManager.isProtocolLoggedIn).
    bool bleReady = false,

    /// Optional detail when [bleReady] is false (e.g. connecting / not LOGIN).
    String? bleNotReadyReason,
    String? defaultVehicleId,
    OfficialControlChannel channel = OfficialControlChannel.automatic,
    bool busy = false,
    bool networkReady = true,
  }) {
    final selected = cloudState.selectedVehicle;
    final cloudSessionReady =
        cloudState.signedIn && cloudState.selectedVehicle != null;

    // Linked-local-vehicle guard (ours): even if BLE LOGIN, refuse if the
    // selected official car is hard-linked to another local device id.
    final bleLinkedOk = _canUseLinkedBle(
      cloudState: cloudState,
      bleReady: bleReady,
      defaultVehicleId: defaultVehicleId,
    );
    final effectiveBleReady = bleReady && bleLinkedOk;

    final officialDecision = OfficialControlRoute.resolve(
      bindingCar: selected != null,
      modelType: selected?.modelType,
      isGps: selected?.isGps,
      bleReady: effectiveBleReady,
      networkReady: networkReady,
      cloudSessionReady: cloudSessionReady,
    );

    final canUseBle = switch (channel) {
      OfficialControlChannel.ble =>
        officialDecision.usesBle && effectiveBleReady,
      OfficialControlChannel.officialCloud => false,
      OfficialControlChannel.automatic =>
        officialDecision.usesBle && effectiveBleReady,
    };

    final vehicleAllowsCloudFallback = _officialAllowsCloudFallback(
      selected: selected,
      decision: officialDecision,
    );

    final canUseCloud = switch (channel) {
      OfficialControlChannel.officialCloud =>
        vehicleAllowsCloudFallback && cloudSessionReady && networkReady,
      OfficialControlChannel.ble => false,
      OfficialControlChannel.automatic =>
        officialDecision.usesCloud && cloudSessionReady && networkReady,
    };

    final bleUnavailableReason = canUseBle
        ? ''
        : _bleUnavailableReason(
            cloudState: cloudState,
            bleReady: bleReady,
            bleNotReadyReason: bleNotReadyReason,
            defaultVehicleId: defaultVehicleId,
            officialReason: officialDecision.usesBle
                ? ''
                : officialDecision.reason,
          );

    final cloudUnavailableReason = canUseCloud
        ? ''
        : _cloudUnavailableReason(
            cloudState: cloudState,
            channel: channel,
            networkReady: networkReady,
            officialReason: officialDecision.reason,
          );

    final enabled =
        !busy &&
        switch (channel) {
          OfficialControlChannel.ble => canUseBle,
          OfficialControlChannel.officialCloud => canUseCloud,
          OfficialControlChannel.automatic =>
            !officialDecision.isUnavailable && (canUseBle || canUseCloud),
        };

    final willUseBle =
        !busy &&
        switch (channel) {
          OfficialControlChannel.ble => canUseBle,
          OfficialControlChannel.officialCloud => false,
          OfficialControlChannel.automatic =>
            officialDecision.usesBle && canUseBle,
        };

    final otherwiseAvailable = canUseBle || canUseCloud;

    return ControlChannelAvailability(
      channel: channel,
      officialDecision: officialDecision,
      canUseBle: canUseBle,
      canUseCloud: canUseCloud,
      enabled: enabled,
      willUseBle: willUseBle,
      vehicleAllowsCloudFallback: channel == OfficialControlChannel.ble
          ? false
          : vehicleAllowsCloudFallback,
      effectiveChannelLabel: _effectiveChannelLabel(
        enabled: enabled,
        willUseBle: willUseBle,
        canUseCloud: canUseCloud,
      ),
      bleUnavailableReason: bleUnavailableReason,
      cloudUnavailableReason: cloudUnavailableReason,
      disabledReason: busy && otherwiseAvailable
          ? '正在执行控车指令，请稍候'
          : _disabledReason(
              channel: channel,
              bleUnavailableReason: bleUnavailableReason,
              cloudUnavailableReason: cloudUnavailableReason,
              officialDecision: officialDecision,
            ),
    );
  }

  static bool _officialAllowsCloudFallback({
    required OfficialVehicle? selected,
    required OfficialControlRouteDecision decision,
  }) {
    if (selected == null) return false;
    if (decision.usesCloud) return true;
    // Probe: if BLE were not ready, would official choose cloud?
    final withoutBle = OfficialControlRoute.resolve(
      bindingCar: true,
      modelType: selected.modelType,
      isGps: selected.isGps,
      bleReady: false,
      networkReady: true,
      cloudSessionReady: true,
    );
    return withoutBle.usesCloud;
  }

  static bool _canUseLinkedBle({
    required OfficialCloudState cloudState,
    required bool bleReady,
    required String? defaultVehicleId,
  }) {
    if (!bleReady) return false;
    final selected = cloudState.selectedVehicle;
    if (selected == null) return true;
    final linkedId = cloudState.linkedLocalVehicleId(selected.key);
    if (linkedId == null || linkedId.isEmpty) return true;
    return defaultVehicleId == linkedId;
  }

  static String _effectiveChannelLabel({
    required bool enabled,
    required bool willUseBle,
    required bool canUseCloud,
  }) {
    if (!enabled) return '不可用';
    if (willUseBle) return 'BLE';
    if (canUseCloud) return '官方云端';
    return '不可用';
  }

  static String _bleUnavailableReason({
    required OfficialCloudState cloudState,
    required bool bleReady,
    String? bleNotReadyReason,
    required String? defaultVehicleId,
    required String officialReason,
  }) {
    if (!bleReady) {
      // Prefer explicit non-LOGIN detail over generic official "蓝牙未连接".
      if (bleNotReadyReason != null && bleNotReadyReason.isNotEmpty) {
        return bleNotReadyReason;
      }
      return officialReason.isNotEmpty ? officialReason : '蓝牙未连接';
    }
    final selected = cloudState.selectedVehicle;
    if (selected == null) return '';
    final linkedId = cloudState.linkedLocalVehicleId(selected.key);
    if (linkedId == null || linkedId.isEmpty) return '';
    if (defaultVehicleId == null || defaultVehicleId.isEmpty) {
      return '没有默认本地车辆';
    }
    return '默认本地车辆与官方车辆关联不一致';
  }

  static String _cloudUnavailableReason({
    required OfficialCloudState cloudState,
    required OfficialControlChannel channel,
    required bool networkReady,
    required String officialReason,
  }) {
    if (!networkReady) return '手机网络未连接';
    if (!cloudState.signedIn) return OfficialCloudMessages.signInRequired;
    if (cloudState.selectedVehicle == null) return '官方账号未选择车辆';
    if (channel == OfficialControlChannel.automatic &&
        officialReason.isNotEmpty) {
      return officialReason;
    }
    return '';
  }

  static String _disabledReason({
    required OfficialControlChannel channel,
    required String bleUnavailableReason,
    required String cloudUnavailableReason,
    required OfficialControlRouteDecision officialDecision,
  }) {
    switch (channel) {
      case OfficialControlChannel.ble:
        return bleUnavailableReason.isEmpty
            ? '当前官方车辆未关联这台本地 BLE 车辆'
            : bleUnavailableReason;
      case OfficialControlChannel.officialCloud:
        return cloudUnavailableReason.isEmpty
            ? '官方云端不可用'
            : cloudUnavailableReason;
      case OfficialControlChannel.automatic:
        // Keep non-BLE official reasons (未绑定/未登录/无网) first.
        // For the generic "蓝牙未连接" branch, prefer the more specific
        // non-LOGIN detail (连接中 / 未完成协议登录) when available.
        if (officialDecision.isUnavailable &&
            officialDecision.reason.isNotEmpty &&
            officialDecision.reason != '蓝牙未连接') {
          return officialDecision.reason;
        }
        if (bleUnavailableReason.isNotEmpty) {
          return bleUnavailableReason;
        }
        if (officialDecision.isUnavailable &&
            officialDecision.reason.isNotEmpty) {
          return officialDecision.reason;
        }
        final reasons = [
          if (bleUnavailableReason.isNotEmpty) 'BLE：$bleUnavailableReason',
          if (cloudUnavailableReason.isNotEmpty) '云端：$cloudUnavailableReason',
        ];
        return reasons.isEmpty ? '请连接蓝牙或登录官方账号后再控车' : reasons.join('；');
    }
  }
}
