import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/control_command_confirmation.dart';
import 'package:tailg_ble_app/services/control_command_result.dart';

void main() {
  group('ControlCommandConfirmationGuard', () {
    test('keeps BLE confirmation bound to complete local and BLE targets', () {
      const guard = ControlCommandConfirmationGuard();

      expect(
        guard.allows(
          context: const PendingControlCommandConfirmationContext(
            defaultVehicleId: 'local-1',
            bleDeviceId: 'ble-1',
          ).forTransport(ControlCommandTransport.ble),
          currentDefaultVehicleId: 'local-1',
          currentBleDeviceId: 'ble-1',
          currentOfficialVehicleKey: 'official-1',
        ),
        isTrue,
      );
      expect(
        guard.allows(
          context: const PendingControlCommandConfirmationContext(
            bleDeviceId: 'ble-1',
          ).forTransport(ControlCommandTransport.ble),
          currentDefaultVehicleId: 'local-1',
          currentBleDeviceId: 'ble-1',
          currentOfficialVehicleKey: 'official-1',
        ),
        isFalse,
      );
      expect(
        guard.allows(
          context: const PendingControlCommandConfirmationContext(
            defaultVehicleId: 'local-1',
          ).forTransport(ControlCommandTransport.ble),
          currentDefaultVehicleId: 'local-1',
          currentBleDeviceId: 'ble-1',
          currentOfficialVehicleKey: 'official-1',
        ),
        isFalse,
      );
      expect(
        guard.allows(
          context: const PendingControlCommandConfirmationContext(
            defaultVehicleId: '',
            bleDeviceId: 'ble-1',
          ).forTransport(ControlCommandTransport.ble),
          currentDefaultVehicleId: 'local-1',
          currentBleDeviceId: 'ble-1',
          currentOfficialVehicleKey: 'official-1',
        ),
        isFalse,
      );
      expect(
        guard.allows(
          context: const PendingControlCommandConfirmationContext(
            defaultVehicleId: 'local-1',
            bleDeviceId: '',
          ).forTransport(ControlCommandTransport.ble),
          currentDefaultVehicleId: 'local-1',
          currentBleDeviceId: 'ble-1',
          currentOfficialVehicleKey: 'official-1',
        ),
        isFalse,
      );
      expect(
        guard.allows(
          context: const PendingControlCommandConfirmationContext(
            defaultVehicleId: 'local-1',
            bleDeviceId: 'ble-1',
          ).forTransport(ControlCommandTransport.ble),
          currentDefaultVehicleId: 'local-2',
          currentBleDeviceId: 'ble-1',
          currentOfficialVehicleKey: 'official-1',
        ),
        isFalse,
      );
      expect(
        guard.allows(
          context: const PendingControlCommandConfirmationContext(
            defaultVehicleId: 'local-1',
            bleDeviceId: 'ble-1',
          ).forTransport(ControlCommandTransport.ble),
          currentDefaultVehicleId: 'local-1',
          currentBleDeviceId: 'ble-2',
          currentOfficialVehicleKey: 'official-1',
        ),
        isFalse,
      );
    });

    test('keeps cloud confirmation bound to the selected official vehicle', () {
      const guard = ControlCommandConfirmationGuard();

      expect(
        guard.allows(
          context: const PendingControlCommandConfirmationContext(
            officialVehicleKey: 'official-1',
          ).forTransport(ControlCommandTransport.officialCloud),
          currentDefaultVehicleId: 'local-1',
          currentBleDeviceId: 'ble-1',
          currentOfficialVehicleKey: 'official-1',
        ),
        isTrue,
      );
      expect(
        guard.allows(
          context: const PendingControlCommandConfirmationContext(
            officialVehicleKey: 'official-1',
          ).forTransport(ControlCommandTransport.officialCloud),
          currentDefaultVehicleId: 'local-1',
          currentBleDeviceId: 'ble-1',
          currentOfficialVehicleKey: 'official-2',
        ),
        isFalse,
      );
      expect(
        guard.allows(
          context: const PendingControlCommandConfirmationContext(
            officialVehicleKey: '',
          ).forTransport(ControlCommandTransport.officialCloud),
          currentDefaultVehicleId: 'local-1',
          currentBleDeviceId: 'ble-1',
          currentOfficialVehicleKey: 'official-1',
        ),
        isFalse,
      );
    });
  });
}
