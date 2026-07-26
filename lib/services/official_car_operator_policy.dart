import '../models/command_types.dart';
import '../models/official_vehicle.dart';

class OfficialCarOperatorUpdate {
  final String carId;
  final String operatorFlag;

  const OfficialCarOperatorUpdate({
    required this.carId,
    required this.operatorFlag,
  });
}

/// Mirrors the `ControlFragment.start()` setCarOperator branches.
class OfficialCarOperatorPolicy {
  static const _alwaysTrackedModelTypes = {1, 2};
  static const _sharedPowerOnModelTypes = {
    3,
    8,
    10,
    14,
    283,
    401,
    928,
    2103,
    2201,
  };

  const OfficialCarOperatorPolicy._();

  static OfficialCarOperatorUpdate? updateFor({
    required CommandCode command,
    required OfficialVehicle vehicle,
  }) {
    final carId = vehicle.carId.trim();
    if (carId.isEmpty) return null;

    final modelType = vehicle.modelType;
    if (_alwaysTrackedModelTypes.contains(modelType)) {
      return switch (command) {
        CommandCode.powerOn => OfficialCarOperatorUpdate(
          carId: carId,
          operatorFlag: '1',
        ),
        CommandCode.powerOff => OfficialCarOperatorUpdate(
          carId: carId,
          operatorFlag: '0',
        ),
        _ => null,
      };
    }

    if (command == CommandCode.powerOn &&
        vehicle.shareCarFlag &&
        _sharedPowerOnModelTypes.contains(modelType)) {
      return OfficialCarOperatorUpdate(carId: carId, operatorFlag: '1');
    }
    return null;
  }
}
