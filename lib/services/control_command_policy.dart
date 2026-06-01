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
  static const vehicleMovingDisabledReason = '车辆行驶中，请勿操作！';
  static const keyStartedDisabledReason = '您已使用钥匙启动车辆，当前不支持此操作！';
  static const notPoweredOffDisabledReason = '车辆未断电，请勿操作！';

  const ControlCommandPolicy._();

  /// 评估命令是否可执行。
  ///
  /// [isMoving] 车辆行驶中（来自 MQTT accErrorStatus==4）
  /// [keyStarted] 钥匙启动（来自 MQTT accErrorStatus==8）
  /// [notPoweredOff] 车辆未断电（来自 MQTT defenceErrorStatus==3）
  /// 这些状态当前未接入，预留参数默认 false。
  static ControlCommandPolicyResult evaluate({
    required CommandCode command,
    required bool isPowerOn,
    bool isMoving = false,
    bool keyStarted = false,
    bool notPoweredOff = false,
  }) {
    if (isMoving) {
      return const ControlCommandPolicyResult.denied(
        vehicleMovingDisabledReason,
      );
    }
    if (keyStarted &&
        (command == CommandCode.powerOn || command == CommandCode.powerOff)) {
      return const ControlCommandPolicyResult.denied(keyStartedDisabledReason);
    }
    if (notPoweredOff && command == CommandCode.lock) {
      return const ControlCommandPolicyResult.denied(
        notPoweredOffDisabledReason,
      );
    }
    if (command == CommandCode.find && isPowerOn) {
      return const ControlCommandPolicyResult.denied(powerOnFindDisabledReason);
    }
    return const ControlCommandPolicyResult.allowed();
  }
}
