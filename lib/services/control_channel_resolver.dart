import 'official_cloud_service.dart';

class ControlChannelAvailability {
  final bool canUseCloud;
  final bool enabled;
  final String effectiveChannelLabel;
  final String cloudUnavailableReason;
  final String disabledReason;

  const ControlChannelAvailability({
    required this.canUseCloud,
    required this.enabled,
    required this.effectiveChannelLabel,
    required this.cloudUnavailableReason,
    required this.disabledReason,
  });
}

class ControlChannelResolver {
  const ControlChannelResolver._();

  static ControlChannelAvailability resolve({
    required OfficialCloudState cloudState,
    bool busy = false,
  }) {
    final canUseCloud = _canUseOfficialCloud(cloudState);
    final cloudUnavailableReason = canUseCloud
        ? ''
        : _cloudUnavailableReason(cloudState);
    final enabled = !busy && canUseCloud;

    // Prefer the real cloud-unavailable reason. Only fall back to a generic
    // prompt when cloud itself is ready but the control surface is temporarily
    // blocked (e.g. another command is still in flight).
    final disabledReason = !canUseCloud
        ? (cloudUnavailableReason.isEmpty
              ? '请登录官方账号并选择车辆后再控车'
              : cloudUnavailableReason)
        : busy
        ? '正在执行控车指令，请稍候'
        : '';

    return ControlChannelAvailability(
      canUseCloud: canUseCloud,
      enabled: enabled,
      effectiveChannelLabel: enabled ? '官方云端' : '不可用',
      cloudUnavailableReason: cloudUnavailableReason,
      disabledReason: disabledReason,
    );
  }

  static bool _canUseOfficialCloud(OfficialCloudState cloudState) {
    return cloudState.signedIn && cloudState.selectedVehicle != null;
  }

  static String _cloudUnavailableReason(OfficialCloudState cloudState) {
    if (!cloudState.signedIn) return '请先登录官方账号';
    if (cloudState.selectedVehicle == null) return '官方账号未选择车辆';
    return '';
  }
}
