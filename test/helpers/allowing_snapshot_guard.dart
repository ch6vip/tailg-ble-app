import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/services/ble_connection_snapshot_guard.dart';

class AllowingSnapshotGuard implements BleConnectionSnapshotGuard {
  const AllowingSnapshotGuard();

  @override
  bool allowsReadyTarget({
    required Object? startManager,
    required Object? currentManager,
    required Object? startDevice,
    required Object? currentDevice,
    required String? currentDeviceId,
    required String expectedDeviceId,
    required ConnectionState currentState,
  }) {
    return true;
  }
}
