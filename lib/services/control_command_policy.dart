import '../models/command_types.dart';

class ControlCommandPolicyResult {
  final bool allowed;
  final String? disabledReason;

  const ControlCommandPolicyResult.allowed()
    : allowed = true,
      disabledReason = null;

  const ControlCommandPolicyResult.denied(String reason)
    : allowed = false,
      disabledReason = reason;
}

class ControlCommandPolicy {
  static const powerOnFindDisabledReason = '车辆已上电，不能寻车';
  static const vehicleMovingDisabledReason = '车辆行驶中，请勿操作';
  static const keyStartedDisabledReason = '您已使用钥匙启动车辆，当前不支持此操作';
  static const notPoweredOffDisabledReason = '车辆未断电，请勿操作';

  const ControlCommandPolicy._();

  /// 评估命令是否可执行。
  ///
  /// MQTT error fields are command responses, not durable vehicle state. They
  /// are evaluated by OfficialMqttStatusPayload against the pending command.
  static ControlCommandPolicyResult evaluate({
    required CommandCode command,
    required bool isPowerOn,
  }) {
    if (command == CommandCode.find && isPowerOn) {
      return const ControlCommandPolicyResult.denied(powerOnFindDisabledReason);
    }
    return const ControlCommandPolicyResult.allowed();
  }
}
