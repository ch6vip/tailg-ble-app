import 'official_cloud_service.dart';

class ControlChannelAvailability {
  final OfficialControlChannel channel;
  final bool canUseBle;
  final bool canUseCloud;
  final bool enabled;
  final bool willUseBle;
  final String disabledReason;

  const ControlChannelAvailability({
    required this.channel,
    required this.canUseBle,
    required this.canUseCloud,
    required this.enabled,
    required this.willUseBle,
    required this.disabledReason,
  });
}

class ControlChannelResolver {
  const ControlChannelResolver._();

  static ControlChannelAvailability resolve({
    required OfficialCloudState cloudState,
    required bool bleReady,
    required String? defaultVehicleId,
    bool busy = false,
  }) {
    final canUseBle = _canUseLinkedBle(
      cloudState: cloudState,
      bleReady: bleReady,
      defaultVehicleId: defaultVehicleId,
    );
    final canUseCloud = _canUseOfficialCloud(cloudState);
    final enabled =
        !busy &&
        switch (cloudState.controlChannel) {
          OfficialControlChannel.ble => canUseBle,
          OfficialControlChannel.officialCloud => canUseCloud,
          OfficialControlChannel.automatic => canUseBle || canUseCloud,
        };
    final willUseBle = switch (cloudState.controlChannel) {
      OfficialControlChannel.ble => canUseBle,
      OfficialControlChannel.officialCloud => false,
      OfficialControlChannel.automatic => canUseBle,
    };

    return ControlChannelAvailability(
      channel: cloudState.controlChannel,
      canUseBle: canUseBle,
      canUseCloud: canUseCloud,
      enabled: enabled,
      willUseBle: willUseBle,
      disabledReason: _disabledReason(
        cloudState: cloudState,
        bleReady: bleReady,
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

  static String _disabledReason({
    required OfficialCloudState cloudState,
    required bool bleReady,
  }) {
    switch (cloudState.controlChannel) {
      case OfficialControlChannel.ble:
        return bleReady ? '当前官方车辆未关联这台本地 BLE 车辆' : 'BLE 未连接，当前通道不可用';
      case OfficialControlChannel.officialCloud:
        return cloudState.signedIn ? '官方账号未选择车辆' : '请先登录官方账号';
      case OfficialControlChannel.automatic:
        return '请连接 BLE 或登录官方账号后再控车';
    }
  }
}
