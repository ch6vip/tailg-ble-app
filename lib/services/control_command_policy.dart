import '../ble/constants.dart';

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

  const ControlCommandPolicy._();

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
