import 'official_cloud_service.dart';

/// Preferred control transport. Defaults to [automatic] (BLE when ready, else
/// official cloud). Kept outside OfficialCloudState for now so the hybrid spike
/// does not reintroduce persisted channel storage.
enum OfficialControlChannel {
  automatic('自动', '优先 BLE，未连接时走官方云端'),
  ble('BLE', '只使用本地蓝牙直连'),
  officialCloud('官方云端', '使用官方账号远程控车');

  final String label;
  final String description;

  const OfficialControlChannel(this.label, this.description);
}

class ControlChannelAvailability {
  final OfficialControlChannel channel;
  final bool canUseBle;
  final bool canUseCloud;
  final bool enabled;
  final bool willUseBle;
  final String effectiveChannelLabel;
  final String bleUnavailableReason;
  final String cloudUnavailableReason;
  final String disabledReason;

  const ControlChannelAvailability({
    required this.channel,
    required this.canUseBle,
    required this.canUseCloud,
    required this.enabled,
    required this.willUseBle,
    required this.effectiveChannelLabel,
    required this.bleUnavailableReason,
    required this.cloudUnavailableReason,
    required this.disabledReason,
  });
}

class ControlChannelResolver {
  const ControlChannelResolver._();

  static ControlChannelAvailability resolve({
    required OfficialCloudState cloudState,
    bool bleReady = false,
    String? defaultVehicleId,
    OfficialControlChannel channel = OfficialControlChannel.automatic,
    bool busy = false,
  }) {
    final canUseBle = _canUseLinkedBle(
      cloudState: cloudState,
      bleReady: bleReady,
      defaultVehicleId: defaultVehicleId,
    );
    final canUseCloud = _canUseOfficialCloud(cloudState);
    final bleUnavailableReason = canUseBle
        ? ''
        : _bleUnavailableReason(
            cloudState: cloudState,
            bleReady: bleReady,
            defaultVehicleId: defaultVehicleId,
          );
    final cloudUnavailableReason = canUseCloud
        ? ''
        : _cloudUnavailableReason(cloudState);
    final enabled =
        !busy &&
        switch (channel) {
          OfficialControlChannel.ble => canUseBle,
          OfficialControlChannel.officialCloud => canUseCloud,
          OfficialControlChannel.automatic => canUseBle || canUseCloud,
        };
    final willUseBle =
        !busy &&
        switch (channel) {
          OfficialControlChannel.ble => canUseBle,
          OfficialControlChannel.officialCloud => false,
          OfficialControlChannel.automatic => canUseBle,
        };

    return ControlChannelAvailability(
      channel: channel,
      canUseBle: canUseBle,
      canUseCloud: canUseCloud,
      enabled: enabled,
      willUseBle: willUseBle,
      effectiveChannelLabel: _effectiveChannelLabel(
        enabled: enabled,
        willUseBle: willUseBle,
        canUseCloud: canUseCloud,
      ),
      bleUnavailableReason: bleUnavailableReason,
      cloudUnavailableReason: cloudUnavailableReason,
      disabledReason: busy && (canUseBle || canUseCloud)
          ? '正在执行控车指令，请稍候'
          : _disabledReason(
              channel: channel,
              bleUnavailableReason: bleUnavailableReason,
              cloudUnavailableReason: cloudUnavailableReason,
            ),
    );
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

  static bool _canUseOfficialCloud(OfficialCloudState cloudState) {
    return cloudState.signedIn && cloudState.selectedVehicle != null;
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
    required String? defaultVehicleId,
  }) {
    if (!bleReady) return 'BLE 未连接或协议未就绪';
    final selected = cloudState.selectedVehicle;
    if (selected == null) return '';
    final linkedId = cloudState.linkedLocalVehicleId(selected.key);
    if (linkedId == null || linkedId.isEmpty) return '';
    if (defaultVehicleId == null || defaultVehicleId.isEmpty) {
      return '没有默认本地车辆';
    }
    return '默认本地车辆与官方车辆关联不一致';
  }

  static String _cloudUnavailableReason(OfficialCloudState cloudState) {
    if (!cloudState.signedIn) return OfficialCloudMessages.signInRequired;
    if (cloudState.selectedVehicle == null) return '官方账号未选择车辆';
    return '';
  }

  static String _disabledReason({
    required OfficialControlChannel channel,
    required String bleUnavailableReason,
    required String cloudUnavailableReason,
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
        final reasons = [
          if (bleUnavailableReason.isNotEmpty) 'BLE：$bleUnavailableReason',
          if (cloudUnavailableReason.isNotEmpty) '云端：$cloudUnavailableReason',
        ];
        return reasons.isEmpty ? '请连接 BLE 或登录官方账号后再控车' : reasons.join('；');
    }
  }
}
