import '../models/command_types.dart';
import 'control_command_result.dart';

/// Snapshot of vehicle ACC/defence used as baseline before a command is sent.
class ControlCommandVehicleStateSnapshot {
  final bool? isLocked;
  final bool? isPowerOn;

  const ControlCommandVehicleStateSnapshot({
    this.isLocked,
    this.isPowerOn,
  });
}

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

/// Pure confirmation rules shared by UI and unit tests.
///
/// Official remote path: MQTT publish success ≠ vehicle executed. Confirmation
/// requires either a MQTT status ACK that clears the pending command, or an
/// observed ACC/defence change to the expected post-command state.
class ControlCommandConfirmation {
  const ControlCommandConfirmation._();

  static const guard = ControlCommandConfirmationGuard();

  /// lock / unlock / powerOn / powerOff need vehicle-state or MQTT ACK.
  /// find / openSeat have no durable ACC/defence signal → accept transport OK.
  static bool needsVehicleStateConfirmation(CommandCode command) {
    return switch (command) {
      CommandCode.lock ||
      CommandCode.unlock ||
      CommandCode.powerOn ||
      CommandCode.powerOff => true,
      _ => false,
    };
  }

  /// Whether [isLocked]/[isPowerOn] match the expected post-command state.
  static bool matchesExpectedState({
    required CommandCode command,
    required bool? isLocked,
    required bool? isPowerOn,
  }) {
    return switch (command) {
      CommandCode.lock => isLocked == true,
      CommandCode.unlock => isLocked == false,
      CommandCode.powerOn => isPowerOn == true,
      CommandCode.powerOff => isPowerOn == false,
      _ => true,
    };
  }

  /// MQTT layer confirmed when a non-empty pending command was cleared by status.
  static bool mqttPendingAcknowledged({
    required String? pendingAtSend,
    required String? pendingNow,
  }) {
    final start = pendingAtSend?.trim() ?? '';
    if (start.isEmpty) return false;
    final now = pendingNow?.trim() ?? '';
    return now.isEmpty;
  }

  /// Decide if a successful transport send may be shown as confirmed to the user.
  ///
  /// - BLE: device ACK is enough (official LOGIN path already executed locally).
  /// - Cloud: MQTT publish alone is **not** enough when [needsVehicleStateConfirmation].
  ///   Confirm via MQTT pending clear, or ACC/defence reaching expected **and**
  ///   differing from [baseline] (avoids false success when already locked).
  static bool isConfirmed({
    required CommandCode command,
    required ControlCommandTransport transport,
    required String? expectedOfficialVehicleKey,
    required String? currentOfficialVehicleKey,
    required ControlCommandVehicleStateSnapshot baseline,
    required ControlCommandVehicleStateSnapshot current,
    required bool mqttAcked,
  }) {
    if (!guard.allows(
      context: ControlCommandConfirmationContext(
        transport: transport,
        officialVehicleKey: expectedOfficialVehicleKey,
      ),
      currentOfficialVehicleKey: currentOfficialVehicleKey,
    )) {
      return false;
    }

    if (transport == ControlCommandTransport.ble) {
      return true;
    }

    if (transport != ControlCommandTransport.officialCloud) {
      return false;
    }

    if (!needsVehicleStateConfirmation(command)) {
      // find / seat: no durable state signal; transport success stands.
      return true;
    }

    if (mqttAcked) return true;

    final matches = matchesExpectedState(
      command: command,
      isLocked: current.isLocked,
      isPowerOn: current.isPowerOn,
    );
    if (!matches) return false;

    final baselineAlreadyMatched = matchesExpectedState(
      command: command,
      isLocked: baseline.isLocked,
      isPowerOn: baseline.isPowerOn,
    );
    // Already in target state before send → only MQTT ACK can confirm.
    if (baselineAlreadyMatched) return false;

    return true;
  }
}
