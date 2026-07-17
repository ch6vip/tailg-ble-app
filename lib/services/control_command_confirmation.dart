import 'control_command_result.dart';

class ControlCommandConfirmationContext {
  final ControlCommandTransport transport;
  final String? officialVehicleKey;

  const ControlCommandConfirmationContext({
    required this.transport,
    this.officialVehicleKey,
  });
}

class PendingControlCommandConfirmationContext {
  final String? officialVehicleKey;

  const PendingControlCommandConfirmationContext({this.officialVehicleKey});

  ControlCommandConfirmationContext forTransport(
    ControlCommandTransport transport,
  ) {
    return ControlCommandConfirmationContext(
      transport: transport,
      officialVehicleKey: officialVehicleKey,
    );
  }
}

class ControlCommandConfirmationGuard {
  const ControlCommandConfirmationGuard();

  bool allows({
    required ControlCommandConfirmationContext context,
    required String? currentOfficialVehicleKey,
  }) {
    return switch (context.transport) {
      ControlCommandTransport.ble => true,
      ControlCommandTransport.officialCloud => _sameOfficialVehicle(
        expectedOfficialVehicleKey: context.officialVehicleKey,
        currentOfficialVehicleKey: currentOfficialVehicleKey,
      ),
      ControlCommandTransport.unavailable => false,
    };
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
