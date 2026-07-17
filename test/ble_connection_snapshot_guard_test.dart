import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/services/ble_connection_snapshot_guard.dart';

void main() {
  group('BleConnectionSnapshotGuard', () {
    test('allows only the same ready manager and BLE device', () {
      const guard = BleConnectionSnapshotGuard();
      final manager = Object();
      final otherManager = Object();
      final device = Object();
      final otherDevice = Object();

      expect(
        guard.allowsReadyTarget(
          startManager: manager,
          currentManager: manager,
          startDevice: device,
          currentDevice: device,
          currentDeviceId: 'device-1',
          expectedDeviceId: 'device-1',
          currentState: ConnectionState.ready,
        ),
        isTrue,
      );
      expect(
        guard.allowsReadyTarget(
          startManager: manager,
          currentManager: otherManager,
          startDevice: device,
          currentDevice: device,
          currentDeviceId: 'device-1',
          expectedDeviceId: 'device-1',
          currentState: ConnectionState.ready,
        ),
        isFalse,
      );
      expect(
        guard.allowsReadyTarget(
          startManager: manager,
          currentManager: manager,
          startDevice: device,
          currentDevice: otherDevice,
          currentDeviceId: 'device-1',
          expectedDeviceId: 'device-1',
          currentState: ConnectionState.ready,
        ),
        isFalse,
      );
      expect(
        guard.allowsReadyTarget(
          startManager: manager,
          currentManager: manager,
          startDevice: device,
          currentDevice: device,
          currentDeviceId: 'device-2',
          expectedDeviceId: 'device-1',
          currentState: ConnectionState.ready,
        ),
        isFalse,
      );
      expect(
        guard.allowsReadyTarget(
          startManager: manager,
          currentManager: manager,
          startDevice: device,
          currentDevice: device,
          currentDeviceId: 'device-1',
          expectedDeviceId: 'device-1',
          currentState: ConnectionState.connected,
        ),
        isFalse,
      );
    });

    test('rejects incomplete snapshots instead of matching null devices', () {
      const guard = BleConnectionSnapshotGuard();

      expect(
        guard.allowsReadyTarget(
          startManager: null,
          currentManager: null,
          startDevice: Object(),
          currentDevice: Object(),
          currentDeviceId: 'device-1',
          expectedDeviceId: 'device-1',
          currentState: ConnectionState.ready,
        ),
        isFalse,
      );
      expect(
        guard.allowsReadyTarget(
          startManager: Object(),
          currentManager: Object(),
          startDevice: null,
          currentDevice: null,
          currentDeviceId: 'device-1',
          expectedDeviceId: 'device-1',
          currentState: ConnectionState.ready,
        ),
        isFalse,
      );
      expect(
        guard.allowsReadyTarget(
          startManager: Object(),
          currentManager: Object(),
          startDevice: Object(),
          currentDevice: Object(),
          currentDeviceId: 'device-1',
          expectedDeviceId: '',
          currentState: ConnectionState.ready,
        ),
        isFalse,
      );
    });
  });
}
