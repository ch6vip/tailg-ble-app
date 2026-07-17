import '../models/official_vehicle.dart';
import 'official_cloud_service.dart';

/// Preferred control transport.
///
/// [automatic] mirrors the official app's ControlFragment routing:
/// - BLE protocol-ready (`LoginStatus.LOGIN` equivalent) always wins
/// - otherwise cloud is allowed only when the vehicle is remote-capable
///   (official `isGps == 1` / our [OfficialVehicle.hasGpsService], plus a few
///   cloud-first model types)
/// - pure BLE vehicles without GPS do not silently fall back to cloud
enum OfficialControlChannel {
  automatic('自动', '官方逻辑：BLE 就绪优先，有远程能力时云端兜底'),
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
  final bool vehicleAllowsCloudFallback;
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
    required this.vehicleAllowsCloudFallback,
    required this.effectiveChannelLabel,
    required this.bleUnavailableReason,
    required this.cloudUnavailableReason,
    required this.disabledReason,
  });
}

class ControlChannelResolver {
  const ControlChannelResolver._();

  /// Official cloud-first model types observed in ControlTypeUtil / ControlFragment
  /// where remote path is taken without requiring the BLE LOGIN state.
  static const _cloudFirstModelTypes = {1, 2};

  static ControlChannelAvailability resolve({
    required OfficialCloudState cloudState,
    bool bleReady = false,
    String? defaultVehicleId,
    OfficialControlChannel channel = OfficialControlChannel.automatic,
    bool busy = false,
  }) {
    final selected = cloudState.selectedVehicle;
    final vehicleAllowsCloudFallback = _vehicleAllowsCloudFallback(selected);

    final canUseBle = _canUseLinkedBle(
      cloudState: cloudState,
      bleReady: bleReady,
      defaultVehicleId: defaultVehicleId,
    );
    final cloudAccountReady = _cloudAccountReady(cloudState);
    // Forced cloud channel keeps account-only gate.
    // Automatic mode only uses cloud when the vehicle is remote-capable
    // (official: isGps==1 / modelType cloud-first paths).
    final canUseCloud = switch (channel) {
      OfficialControlChannel.officialCloud => cloudAccountReady,
      OfficialControlChannel.ble => false,
      OfficialControlChannel.automatic =>
        cloudAccountReady && vehicleAllowsCloudFallback,
    };

    final bleUnavailableReason = canUseBle
        ? ''
        : _bleUnavailableReason(
            cloudState: cloudState,
            bleReady: bleReady,
            defaultVehicleId: defaultVehicleId,
          );
    final cloudUnavailableReason = canUseCloud
        ? ''
        : _cloudUnavailableReason(
            cloudState: cloudState,
            channel: channel,
            vehicleAllowsCloudFallback: vehicleAllowsCloudFallback,
          );

    final enabled =
        !busy &&
        switch (channel) {
          OfficialControlChannel.ble => canUseBle,
          OfficialControlChannel.officialCloud => canUseCloud,
          // Official automatic: BLE LOGIN first, else remote only if allowed.
          OfficialControlChannel.automatic => canUseBle || canUseCloud,
        };

    final willUseBle =
        !busy &&
        switch (channel) {
          OfficialControlChannel.ble => canUseBle,
          OfficialControlChannel.officialCloud => false,
          // Official ControlFragment: if BLE LOGIN → local; else remote.
          OfficialControlChannel.automatic => canUseBle,
        };

    final otherwiseAvailable = switch (channel) {
      OfficialControlChannel.ble => canUseBle,
      OfficialControlChannel.officialCloud => canUseCloud,
      OfficialControlChannel.automatic => canUseBle || canUseCloud,
    };

    return ControlChannelAvailability(
      channel: channel,
      canUseBle: canUseBle,
      canUseCloud: canUseCloud,
      enabled: enabled,
      willUseBle: willUseBle,
      vehicleAllowsCloudFallback: vehicleAllowsCloudFallback,
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
              canUseBle: canUseBle,
              vehicleAllowsCloudFallback: vehicleAllowsCloudFallback,
            ),
    );
  }

  /// Maps official `isGps == 1` / cloud-first model types onto our vehicle model.
  ///
  /// Official ControlFragment (QGJ/C39):
  ///   `isGps == 1 && bleConnectStatus != LOGIN` → MQTT cloud
  ///   else → require BLE LOGIN
  ///
  /// Official KKS/YJ (modelType 1/2) also take remote path without BLE LOGIN.
  static bool _vehicleAllowsCloudFallback(OfficialVehicle? vehicle) {
    if (vehicle == null) return false;
    if (vehicle.hasGpsService) return true;
    final type = vehicle.modelType;
    if (type != null && _cloudFirstModelTypes.contains(type)) return true;
    return false;
  }

  static bool _canUseLinkedBle({
    required OfficialCloudState cloudState,
    required bool bleReady,
    required String? defaultVehicleId,
  }) {
    // Official LOGIN equivalent: protocol ready, not just GATT connected.
    if (!bleReady) return false;
    final selected = cloudState.selectedVehicle;
    if (selected == null) return true;
    final linkedId = cloudState.linkedLocalVehicleId(selected.key);
    if (linkedId == null || linkedId.isEmpty) return true;
    return defaultVehicleId == linkedId;
  }

  static bool _cloudAccountReady(OfficialCloudState cloudState) {
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
    if (!bleReady) return '蓝牙未连接或协议未登录';
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
    required bool vehicleAllowsCloudFallback,
  }) {
    if (!cloudState.signedIn) return OfficialCloudMessages.signInRequired;
    if (cloudState.selectedVehicle == null) return '官方账号未选择车辆';
    if (channel == OfficialControlChannel.automatic &&
        !vehicleAllowsCloudFallback) {
      return '当前车辆无远程控车能力，请先连接蓝牙';
    }
    return '';
  }

  static String _disabledReason({
    required OfficialControlChannel channel,
    required String bleUnavailableReason,
    required String cloudUnavailableReason,
    required bool canUseBle,
    required bool vehicleAllowsCloudFallback,
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
        // Official: non-remote vehicles must connect BLE.
        if (!canUseBle && !vehicleAllowsCloudFallback) {
          return bleUnavailableReason.isEmpty
              ? '请先连接蓝牙'
              : bleUnavailableReason;
        }
        final reasons = [
          if (bleUnavailableReason.isNotEmpty) 'BLE：$bleUnavailableReason',
          if (cloudUnavailableReason.isNotEmpty) '云端：$cloudUnavailableReason',
        ];
        return reasons.isEmpty ? '请连接蓝牙或登录官方账号后再控车' : reasons.join('；');
    }
  }
}
