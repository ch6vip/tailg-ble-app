import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/command_types.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/services/control_channel_resolver.dart';
import 'package:tailg_ble_app/services/control_command_route.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

void main() {
  OfficialCloudState stateFor({
    int modelType = 3,
    int isGps = 0,
    bool cushionSupported = true,
  }) {
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'route-1',
      'carNickName': '路由测试车',
      'modelType': modelType,
      'isGps': isGps,
      'btmac': 'AA:BB:CC:DD:EE:FF',
      'defenceStatus': 0,
      'acc': 0,
      'isCushionLock': cushionSupported ? 1 : 0,
    });
    return OfficialCloudState.initial().copyWith(
      token: 'route-token',
      vehicles: [vehicle],
      selectedVehicleKey: vehicle.key,
    );
  }

  ControlChannelAvailability base(
    OfficialCloudState state, {
    bool bleReady = true,
    OfficialControlChannel channel = OfficialControlChannel.automatic,
  }) {
    return ControlChannelResolver.resolve(
      cloudState: state,
      bleReady: bleReady,
      channel: channel,
    );
  }

  test(
    'seat control is BLE-only and requires the official capability flag',
    () {
      final state = stateFor();
      final availability = ControlCommandRoute.resolve(
        base: base(state),
        command: CommandCode.openSeat,
        vehicle: state.selectedVehicle,
      );
      expect(availability.enabled, isTrue);
      expect(availability.willUseBle, isTrue);
      expect(availability.canUseCloud, isFalse);

      final unsupportedState = stateFor(cushionSupported: false);
      final unsupported = ControlCommandRoute.resolve(
        base: base(unsupportedState),
        command: CommandCode.openSeat,
        vehicle: unsupportedState.selectedVehicle,
      );
      expect(unsupported.enabled, isFalse);
      expect(unsupported.disabledReason, '当前车辆不支持开坐垫');
    },
  );

  test('seat remains unavailable on a cloud-only control path', () {
    final state = stateFor(modelType: 8, isGps: 1);
    final availability = ControlCommandRoute.resolve(
      base: base(state, bleReady: false),
      command: CommandCode.openSeat,
      vehicle: state.selectedVehicle,
    );
    expect(availability.enabled, isFalse);
    expect(availability.disabledReason, '开坐垫需连接蓝牙');
  });

  test('manual channels still obey the official vehicle route', () {
    final yj = stateFor(modelType: 2, isGps: 1);
    final ble = base(yj, channel: OfficialControlChannel.ble);
    expect(ble.enabled, isFalse);
    expect(ble.canUseBle, isFalse);

    final nonGpsBb = stateFor(modelType: 3, isGps: 0);
    final cloud = base(
      nonGpsBb,
      bleReady: false,
      channel: OfficialControlChannel.officialCloud,
    );
    expect(cloud.enabled, isFalse);
    expect(cloud.canUseCloud, isFalse);

    final kks = stateFor(modelType: 1, isGps: 0);
    final supportedCloud = base(
      kks,
      bleReady: true,
      channel: OfficialControlChannel.officialCloud,
    );
    expect(supportedCloud.enabled, isTrue);
    expect(supportedCloud.canUseCloud, isTrue);
  });
}
