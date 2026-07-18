import '../models/command_types.dart';

enum ControlCommandTransport { ble, officialCloud, unavailable }

class ControlCommandResult {
  final CommandCode command;
  final ControlCommandTransport transport;
  final bool success;
  final String? successMessage;
  final String? failureMessage;

  const ControlCommandResult._({
    required this.command,
    required this.transport,
    required this.success,
    this.successMessage,
    this.failureMessage,
  });

  factory ControlCommandResult.bleSuccess(CommandCode command) {
    return ControlCommandResult._(
      command: command,
      transport: ControlCommandTransport.ble,
      success: true,
    );
  }

  factory ControlCommandResult.cloudSuccess(
    CommandCode command, {
    required String message,
  }) {
    final trimmedMessage = message.trim();
    final normalizedMessage = trimmedMessage.isEmpty ? 'success' : message;
    final lower = normalizedMessage.toLowerCase();
    // Strip channel tags from sendCommandPreferMqtt (mqtt:success / http:…).
    final body = normalizedMessage.contains(':')
        ? normalizedMessage.substring(normalizedMessage.indexOf(':') + 1)
        : normalizedMessage;
    final bodyLower = body.toLowerCase();
    final display =
        bodyLower == 'success' || bodyLower == 'ok' || lower == 'success'
        ? '${command.label}已完成'
        : body;
    return ControlCommandResult._(
      command: command,
      transport: ControlCommandTransport.officialCloud,
      success: true,
      successMessage: display,
    );
  }

  factory ControlCommandResult.unavailable(
    CommandCode command,
    String message,
  ) {
    return ControlCommandResult._(
      command: command,
      transport: ControlCommandTransport.unavailable,
      success: false,
      failureMessage: message,
    );
  }

  factory ControlCommandResult.failure(
    CommandCode command, {
    ControlCommandTransport transport = ControlCommandTransport.officialCloud,
    required String message,
  }) {
    return ControlCommandResult._(
      command: command,
      transport: transport,
      success: false,
      failureMessage: message,
    );
  }

  bool get shouldRefreshBikeState =>
      success && transport == ControlCommandTransport.ble;
}
