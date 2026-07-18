import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/command_types.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/services/control_channel_resolver.dart';
import 'package:tailg_ble_app/services/control_command_confirmation.dart';
import 'package:tailg_ble_app/services/control_command_executor.dart';
import 'package:tailg_ble_app/services/control_command_result.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

/// PLAN P0-A5 / P0-B5 acceptance without a physical vehicle.
///
/// Exercises the official six-key matrix on BLE LOGIN path and remote cloud
/// path with mocked senders + confirmation rules. Real-device checklist in
/// PLAN §7 remains recommended for field evidence.
void main() {
  const sixKeys = [
    CommandCode.lock,
    CommandCode.unlock,
    CommandCode.powerOn,
    CommandCode.powerOff,
    CommandCode.find,
    CommandCode.openSeat,
  ];

  OfficialCloudState vehicleState({
    required int modelType,
    required int isGps,
  }) {
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'accept-1',
      'carNickName': '验收车',
      'modelType': modelType,
      'isGps': isGps,
      'btmac': 'AA:BB:CC:DD:EE:FF',
      'defenceStatus': 0,
      'acc': 0,
    });
    return OfficialCloudState.initial().copyWith(
      token: 'accept-token',
      vehicles: [vehicle],
      selectedVehicleKey: vehicle.key,
    );
  }

  group('P0-A5 near-field six-key matrix (mock BLE LOGIN)', () {
    test('all six keys succeed on BLE when protocol LOGIN', () async {
      final sent = <CommandCode>[];
      final executor = ControlCommandExecutor(
        sendBleCommand: (cmd) async {
          sent.add(cmd);
          return true;
        },
        sendCloudCommand: (_) async => fail('must not use cloud for BLE path'),
      );
      final availability = ControlChannelResolver.resolve(
        cloudState: vehicleState(modelType: 3, isGps: 0),
        bleReady: true,
        channel: OfficialControlChannel.automatic,
      );
      expect(availability.willUseBle, isTrue);

      for (final cmd in sixKeys) {
        final result = await executor.send(
          command: cmd,
          availability: availability,
        );
        expect(result.success, isTrue, reason: cmd.name);
        expect(result.transport, ControlCommandTransport.ble);
        // BLE ACK is confirmed without waiting cloud ACC.
        expect(
          ControlCommandConfirmation.isConfirmed(
            command: cmd,
            transport: ControlCommandTransport.ble,
            expectedOfficialVehicleKey: 'accept-1',
            currentOfficialVehicleKey: 'accept-1',
            baseline: const ControlCommandVehicleStateSnapshot(),
            current: const ControlCommandVehicleStateSnapshot(),
            mqttAcked: false,
          ),
          isTrue,
          reason: 'confirm ${cmd.name}',
        );
      }
      expect(sent, sixKeys);
    });
  });

  group('P0-B5 remote six-key matrix (mock cloud, GPS vehicle)', () {
    test('all six keys succeed on cloud when BLE not LOGIN', () async {
      final sent = <CommandCode>[];
      final executor = ControlCommandExecutor(
        sendBleCommand: (_) async => fail('must not use BLE for remote path'),
        sendCloudCommand: (cmd) async {
          sent.add(cmd);
          return 'mqtt:success';
        },
      );
      final availability = ControlChannelResolver.resolve(
        cloudState: vehicleState(modelType: 8, isGps: 1),
        bleReady: false,
        channel: OfficialControlChannel.automatic,
      );
      expect(availability.canUseCloud, isTrue);
      expect(availability.willUseBle, isFalse);

      for (final cmd in sixKeys) {
        final result = await executor.send(
          command: cmd,
          availability: availability,
        );
        expect(result.success, isTrue, reason: cmd.name);
        expect(result.transport, ControlCommandTransport.officialCloud);
      }
      expect(sent, sixKeys);
    });

    test('lock/power require state flip or MQTT ACK to confirm', () {
      expect(
        ControlCommandConfirmation.isConfirmed(
          command: CommandCode.lock,
          transport: ControlCommandTransport.officialCloud,
          expectedOfficialVehicleKey: 'accept-1',
          currentOfficialVehicleKey: 'accept-1',
          baseline: const ControlCommandVehicleStateSnapshot(isLocked: false),
          current: const ControlCommandVehicleStateSnapshot(isLocked: true),
          mqttAcked: false,
        ),
        isTrue,
      );
      expect(
        ControlCommandConfirmation.isConfirmed(
          command: CommandCode.powerOn,
          transport: ControlCommandTransport.officialCloud,
          expectedOfficialVehicleKey: 'accept-1',
          currentOfficialVehicleKey: 'accept-1',
          baseline: const ControlCommandVehicleStateSnapshot(isPowerOn: false),
          current: const ControlCommandVehicleStateSnapshot(isPowerOn: false),
          mqttAcked: true,
        ),
        isTrue,
      );
    });
  });
}
