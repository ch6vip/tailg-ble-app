import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/command_types.dart';
import 'package:tailg_ble_app/services/control_command_confirmation.dart';
import 'package:tailg_ble_app/services/control_command_result.dart';

void main() {
  group('ControlCommandConfirmationGuard', () {
    test('keeps cloud confirmation bound to the selected official vehicle', () {
      const guard = ControlCommandConfirmationGuard();

      expect(
        guard.allows(
          context: const PendingControlCommandConfirmationContext(
            officialVehicleKey: 'official-1',
          ).forTransport(ControlCommandTransport.officialCloud),
          currentOfficialVehicleKey: 'official-1',
        ),
        isTrue,
      );
      expect(
        guard.allows(
          context: const PendingControlCommandConfirmationContext(
            officialVehicleKey: 'official-1',
          ).forTransport(ControlCommandTransport.officialCloud),
          currentOfficialVehicleKey: 'official-2',
        ),
        isFalse,
      );
      expect(
        guard.allows(
          context: const PendingControlCommandConfirmationContext(
            officialVehicleKey: '',
          ).forTransport(ControlCommandTransport.officialCloud),
          currentOfficialVehicleKey: 'official-1',
        ),
        isFalse,
      );
    });

    test('rejects unavailable transport', () {
      const guard = ControlCommandConfirmationGuard();

      expect(
        guard.allows(
          context: const PendingControlCommandConfirmationContext(
            officialVehicleKey: 'official-1',
          ).forTransport(ControlCommandTransport.unavailable),
          currentOfficialVehicleKey: 'official-1',
        ),
        isFalse,
      );
    });
  });

  group('ControlCommandConfirmation (P0-B1 MQTT publish ≠ executed)', () {
    test('needs state confirmation only for lock/power family', () {
      expect(
        ControlCommandConfirmation.needsVehicleStateConfirmation(
          CommandCode.lock,
        ),
        isTrue,
      );
      expect(
        ControlCommandConfirmation.needsVehicleStateConfirmation(
          CommandCode.find,
        ),
        isFalse,
      );
      expect(
        ControlCommandConfirmation.needsVehicleStateConfirmation(
          CommandCode.openSeat,
        ),
        isFalse,
      );
    });

    test('MQTT pending clear is treated as ACK', () {
      expect(
        ControlCommandConfirmation.mqttPendingAcknowledged(
          pendingAtSend: 'lock',
          pendingNow: null,
        ),
        isTrue,
      );
      expect(
        ControlCommandConfirmation.mqttPendingAcknowledged(
          pendingAtSend: 'lock',
          pendingNow: 'lock',
        ),
        isFalse,
      );
      expect(
        ControlCommandConfirmation.mqttPendingAcknowledged(
          pendingAtSend: null,
          pendingNow: null,
        ),
        isFalse,
      );
    });

    test('BLE transport success is confirmed without cloud state', () {
      final confirmed = ControlCommandConfirmation.isConfirmed(
        command: CommandCode.lock,
        transport: ControlCommandTransport.ble,
        expectedOfficialVehicleKey: 'v1',
        currentOfficialVehicleKey: 'v1',
        baseline: const ControlCommandVehicleStateSnapshot(isLocked: false),
        current: const ControlCommandVehicleStateSnapshot(isLocked: false),
        mqttAcked: false,
      );
      expect(confirmed, isTrue);
    });

    test('cloud publish alone does not confirm lock when state unchanged', () {
      // Already locked before send → MQTT publish returning success must not
      // look like vehicle executed until ACK or state change.
      final confirmed = ControlCommandConfirmation.isConfirmed(
        command: CommandCode.lock,
        transport: ControlCommandTransport.officialCloud,
        expectedOfficialVehicleKey: 'v1',
        currentOfficialVehicleKey: 'v1',
        baseline: const ControlCommandVehicleStateSnapshot(isLocked: true),
        current: const ControlCommandVehicleStateSnapshot(isLocked: true),
        mqttAcked: false,
      );
      expect(confirmed, isFalse);
    });

    test('cloud confirms lock when defence flips after publish', () {
      final confirmed = ControlCommandConfirmation.isConfirmed(
        command: CommandCode.lock,
        transport: ControlCommandTransport.officialCloud,
        expectedOfficialVehicleKey: 'v1',
        currentOfficialVehicleKey: 'v1',
        baseline: const ControlCommandVehicleStateSnapshot(isLocked: false),
        current: const ControlCommandVehicleStateSnapshot(isLocked: true),
        mqttAcked: false,
      );
      expect(confirmed, isTrue);
    });

    test('cloud confirms lock on MQTT ACK even if baseline already matched', () {
      final confirmed = ControlCommandConfirmation.isConfirmed(
        command: CommandCode.lock,
        transport: ControlCommandTransport.officialCloud,
        expectedOfficialVehicleKey: 'v1',
        currentOfficialVehicleKey: 'v1',
        baseline: const ControlCommandVehicleStateSnapshot(isLocked: true),
        current: const ControlCommandVehicleStateSnapshot(isLocked: true),
        mqttAcked: true,
      );
      expect(confirmed, isTrue);
    });

    test('cloud rejects confirmation when selected vehicle changed', () {
      final confirmed = ControlCommandConfirmation.isConfirmed(
        command: CommandCode.powerOn,
        transport: ControlCommandTransport.officialCloud,
        expectedOfficialVehicleKey: 'v1',
        currentOfficialVehicleKey: 'v2',
        baseline: const ControlCommandVehicleStateSnapshot(isPowerOn: false),
        current: const ControlCommandVehicleStateSnapshot(isPowerOn: true),
        mqttAcked: true,
      );
      expect(confirmed, isFalse);
    });

    test('find command accepts cloud transport without ACC flip', () {
      final confirmed = ControlCommandConfirmation.isConfirmed(
        command: CommandCode.find,
        transport: ControlCommandTransport.officialCloud,
        expectedOfficialVehicleKey: 'v1',
        currentOfficialVehicleKey: 'v1',
        baseline: const ControlCommandVehicleStateSnapshot(),
        current: const ControlCommandVehicleStateSnapshot(),
        mqttAcked: false,
      );
      expect(confirmed, isTrue);
    });
  });
}
