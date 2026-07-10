import 'dart:async';

import '../models/command_types.dart';
import 'control_command_result.dart';
import 'official_cloud_service.dart';

typedef CloudCommandSender = Future<String> Function(CommandCode command);
typedef CommandErrorMessage = String Function(Object error);

const _defaultCloudCommandTimeout = Duration(seconds: 20);

class ControlCommandExecutor {
  final CloudCommandSender sendCloudCommand;
  final CommandErrorMessage errorMessage;
  final Duration cloudTimeout;

  const ControlCommandExecutor({
    required this.sendCloudCommand,
    this.errorMessage = _defaultErrorMessage,
    this.cloudTimeout = _defaultCloudCommandTimeout,
  });

  Future<ControlCommandResult> send({required CommandCode command}) async {
    return _sendCloud(command);
  }

  Future<ControlCommandResult> _sendCloud(CommandCode command) async {
    try {
      final message = await sendCloudCommand(command).timeout(
        cloudTimeout,
        onTimeout: () => throw TimeoutException('Cloud command timed out'),
      );
      return ControlCommandResult.cloudSuccess(command, message: message);
    } on TimeoutException catch (e) {
      return ControlCommandResult.failure(
        command,
        message: e.message ?? 'Cloud command timed out',
      );
    } catch (e) {
      return ControlCommandResult.failure(command, message: errorMessage(e));
    }
  }
}

String _defaultErrorMessage(Object error) {
  if (error is OfficialCloudApiException) return error.message;
  return error.toString();
}
