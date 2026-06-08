import '../ble/connection_manager.dart';

class BleConnectionSnapshotGuard {
  const BleConnectionSnapshotGuard();

  bool allowsReadyTarget({
    required Object? startManager,
    required Object? currentManager,
    required Object? startDevice,
    required Object? currentDevice,
    required String? currentDeviceId,
    required String expectedDeviceId,
    required ConnectionState currentState,
  }) {
    return currentState == ConnectionState.ready &&
        expectedDeviceId.isNotEmpty &&
        startManager != null &&
        startDevice != null &&
        identical(startManager, currentManager) &&
        identical(startDevice, currentDevice) &&
        currentDeviceId == expectedDeviceId;
  }
}
