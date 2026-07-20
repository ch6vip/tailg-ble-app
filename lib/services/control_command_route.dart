import '../models/command_types.dart';
import '../models/official_vehicle.dart';
import 'control_channel_resolver.dart';

/// Applies command-specific constraints on top of the official vehicle route.
///
/// The official app does not expose one universal six-command transport table:
/// seat control is local-only and some model families have no implementation.
class ControlCommandRoute {
  const ControlCommandRoute._();

  static ControlChannelAvailability resolve({
    required ControlChannelAvailability base,
    required CommandCode command,
    required OfficialVehicle? vehicle,
  }) {
    if (vehicle == null || !base.enabled) return base;

    if (command == CommandCode.openSeat) {
      if (vehicle.isCushionLockSupported != true) {
        return _disabled(base, '当前车辆不支持开坐垫');
      }

      final canUseBle = base.canUseBle;
      final canUseCloud = false;
      final enabled = switch (base.channel) {
        OfficialControlChannel.ble => canUseBle,
        OfficialControlChannel.officialCloud => false,
        OfficialControlChannel.automatic => canUseBle,
      };
      final willUseBle = enabled && canUseBle;
      return base.copyWith(
        canUseBle: canUseBle,
        canUseCloud: canUseCloud,
        enabled: enabled,
        willUseBle: willUseBle,
        effectiveChannelLabel: enabled ? 'BLE' : '不可用',
        cloudUnavailableReason: '开坐垫需连接蓝牙',
        disabledReason: enabled ? '' : '开坐垫需连接蓝牙',
      );
    }

    return base;
  }

  static ControlChannelAvailability _disabled(
    ControlChannelAvailability base,
    String reason,
  ) {
    return base.copyWith(
      canUseBle: false,
      canUseCloud: false,
      enabled: false,
      willUseBle: false,
      effectiveChannelLabel: '不可用',
      disabledReason: reason,
    );
  }
}
