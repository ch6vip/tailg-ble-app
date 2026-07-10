import 'package:flutter_test/flutter_test.dart';
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
}
