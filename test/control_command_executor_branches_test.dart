import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/command_types.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/services/control_channel_resolver.dart';
import 'package:tailg_ble_app/services/control_command_executor.dart';
import 'package:tailg_ble_app/services/control_command_result.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

void main() {
  ControlChannelAvailability availability({
    required OfficialControlChannel channel,
    bool bleReady = false,
    bool signedIn = true,
    bool withVehicle = true,
  }) {
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'c1',
      'carNickName': '车',
      'modelType': 3,
      'isGps': 1,
    });
    final state = OfficialCloudState.initial().copyWith(
      token: signedIn ? 't' : '',
      vehicles: withVehicle ? [vehicle] : const [],
      selectedVehicleKey: withVehicle ? vehicle.key : null,
    );
    return ControlChannelResolver.resolve(
      cloudState: state,
      bleReady: bleReady,
      channel: channel,
    );
  }

  group('ControlCommandExecutor branches (P4-3)', () {
    test('BLE branch when forced ble and ready', () async {
      final calls = <String>[];
      final executor = ControlCommandExecutor(
        sendBleCommand: (cmd) async {
          calls.add('ble:${cmd.name}');
          return true;
        },
        sendCloudCommand: (_) async {
          calls.add('cloud');
          return 'ok';
        },
      );
      final result = await executor.send(
        command: CommandCode.lock,
        availability: availability(
          channel: OfficialControlChannel.ble,
          bleReady: true,
        ),
      );
      expect(result.success, isTrue);
      expect(result.transport, ControlCommandTransport.ble);
      expect(calls, ['ble:lock']);
    });

    test('cloud branch when forced cloud', () async {
      final calls = <String>[];
      final executor = ControlCommandExecutor(
        sendBleCommand: (_) async {
          calls.add('ble');
          return true;
        },
        sendCloudCommand: (cmd) async {
          calls.add('cloud:${cmd.name}');
          return 'success';
        },
      );
      final result = await executor.send(
        command: CommandCode.powerOn,
        availability: availability(
          channel: OfficialControlChannel.officialCloud,
        ),
      );
      expect(result.success, isTrue);
      expect(result.transport, ControlCommandTransport.officialCloud);
      expect(calls, ['cloud:powerOn']);
    });

    test('unavailable when neither path ready', () async {
      final executor = ControlCommandExecutor(
        sendBleCommand: (_) async => true,
        sendCloudCommand: (_) async => 'ok',
      );
      final result = await executor.send(
        command: CommandCode.find,
        availability: availability(
          channel: OfficialControlChannel.automatic,
          bleReady: false,
          signedIn: false,
          withVehicle: false,
        ),
      );
      expect(result.success, isFalse);
      expect(result.transport, ControlCommandTransport.unavailable);
    });
  });
}
