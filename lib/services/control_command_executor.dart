import 'dart:async';

import '../models/command_types.dart';
import 'control_channel_resolver.dart';
import 'control_command_result.dart';
import 'official_cloud_service.dart';
import 'official_remote_error_messages.dart';

typedef BleCommandSender = Future<bool> Function(CommandCode command);
typedef CloudCommandSender = Future<String> Function(CommandCode command);
typedef CommandErrorMessage = String Function(Object error);

const _defaultBleCommandTimeout = Duration(seconds: 15);
const _defaultCloudCommandTimeout = Duration(seconds: 20);

class ControlCommandExecutor {
  final BleCommandSender? sendBleCommand;
  final CloudCommandSender sendCloudCommand;
  final CommandErrorMessage errorMessage;
  final Duration bleTimeout;
  final Duration cloudTimeout;

  const ControlCommandExecutor({
    this.sendBleCommand,
    required this.sendCloudCommand,
    this.errorMessage = _defaultErrorMessage,
    this.bleTimeout = _defaultBleCommandTimeout,
    this.cloudTimeout = _defaultCloudCommandTimeout,
  });

  Future<ControlCommandResult> send({
    required CommandCode command,
    required ControlChannelAvailability availability,
  }) async {
    switch (availability.channel) {
      case OfficialControlChannel.ble:
        if (!availability.canUseBle) return _unavailable(command, availability);
        return _sendBle(command);
      case OfficialControlChannel.officialCloud:
        if (!availability.canUseCloud) {
          return _unavailable(command, availability);
        }
        return _sendCloud(command);
      case OfficialControlChannel.automatic:
        if (availability.canUseBle) return _sendBle(command);
        if (availability.canUseCloud) return _sendCloud(command);
        return _unavailable(command, availability);
    }
  }

  Future<ControlCommandResult> _sendBle(CommandCode command) async {
    final sender = sendBleCommand;
    if (sender == null) {
      return ControlCommandResult.failure(
        command,
        transport: ControlCommandTransport.ble,
        message: 'BLE 通道未配置',
      );
    }
    try {
      final success = await sender(command).timeout(
        bleTimeout,
        onTimeout: () => throw TimeoutException('BLE command timed out'),
      );
      if (success) return ControlCommandResult.bleSuccess(command);
      return ControlCommandResult.failure(
        command,
        transport: ControlCommandTransport.ble,
        message: '${command.label}失败',
      );
    } on TimeoutException catch (e) {
      return ControlCommandResult.failure(
        command,
        transport: ControlCommandTransport.ble,
        message: e.message ?? 'BLE command timed out',
      );
    } catch (e) {
      return ControlCommandResult.failure(
        command,
        transport: ControlCommandTransport.ble,
        message: errorMessage(e),
      );
    }
  }

  Future<ControlCommandResult> _sendCloud(CommandCode command) async {
    try {
      final message = await sendCloudCommand(command).timeout(
        cloudTimeout,
        onTimeout: () => throw TimeoutException('Cloud command timed out'),
      );
      return ControlCommandResult.cloudSuccess(command, message: message);
    } on TimeoutException {
      return ControlCommandResult.failure(
        command,
        transport: ControlCommandTransport.officialCloud,
        message: OfficialRemoteErrorMessages.networkUnavailable,
      );
    } catch (e) {
      return ControlCommandResult.failure(
        command,
        transport: ControlCommandTransport.officialCloud,
        message: errorMessage(e),
      );
    }
  }

  ControlCommandResult _unavailable(
    CommandCode command,
    ControlChannelAvailability availability,
  ) {
    return ControlCommandResult.unavailable(
      command,
      availability.disabledReason,
    );
  }
}

String _defaultErrorMessage(Object error) {
  if (error is OfficialCloudApiException) {
    return OfficialRemoteErrorMessages.describe(error);
  }
  return OfficialRemoteErrorMessages.describe(error);
}
