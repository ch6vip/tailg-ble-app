import 'control_command_result.dart';

class ControlCommandConfirmationContext {
  final ControlCommandTransport transport;
  final String? defaultVehicleId;
  final String? bleDeviceId;
  final String? officialVehicleKey;

  const ControlCommandConfirmationContext({
    required this.transport,
    this.defaultVehicleId,
    this.bleDeviceId,
    this.officialVehicleKey,
  });
}

class PendingControlCommandConfirmationContext {
  final String? defaultVehicleId;
  final String? bleDeviceId;
  final String? officialVehicleKey;

  const PendingControlCommandConfirmationContext({
    this.defaultVehicleId,
    this.bleDeviceId,
    this.officialVehicleKey,
  });

  ControlCommandConfirmationContext forTransport(
    ControlCommandTransport transport,
  ) {
    return ControlCommandConfirmationContext(
      transport: transport,
      defaultVehicleId: defaultVehicleId,
      bleDeviceId: bleDeviceId,
      officialVehicleKey: officialVehicleKey,
    );
  }
}

class ControlCommandConfirmationGuard {
  const ControlCommandConfirmationGuard();

  bool allows({
    required ControlCommandConfirmationContext context,
    required String? currentDefaultVehicleId,
    required String? currentBleDeviceId,
    required String? currentOfficialVehicleKey,
  }) {
    return switch (context.transport) {
      ControlCommandTransport.ble => _sameBleTarget(
        context: context,
        currentDefaultVehicleId: currentDefaultVehicleId,
        currentBleDeviceId: currentBleDeviceId,
      ),
      ControlCommandTransport.officialCloud => _sameOfficialVehicle(
        expectedOfficialVehicleKey: context.officialVehicleKey,
        currentOfficialVehicleKey: currentOfficialVehicleKey,
      ),
      ControlCommandTransport.unavailable => false,
    };
  }

  bool _sameBleTarget({
    required ControlCommandConfirmationContext context,
    required String? currentDefaultVehicleId,
    required String? currentBleDeviceId,
  }) {
    final expectedBleDeviceId = context.bleDeviceId;
    if (expectedBleDeviceId == null || expectedBleDeviceId.isEmpty) {
      return false;
    }
    final expectedDefaultVehicleId = context.defaultVehicleId;
    if (expectedDefaultVehicleId == null || expectedDefaultVehicleId.isEmpty) {
      return false;
    }
    return expectedBleDeviceId == currentBleDeviceId &&
        expectedDefaultVehicleId == currentDefaultVehicleId;
  }

  bool _sameOfficialVehicle({
    required String? expectedOfficialVehicleKey,
    required String? currentOfficialVehicleKey,
  }) {
    return expectedOfficialVehicleKey != null &&
        expectedOfficialVehicleKey.isNotEmpty &&
        expectedOfficialVehicleKey == currentOfficialVehicleKey;
  }
}
