import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/services/ble_connection_snapshot_guard.dart';
import 'package:tailg_ble_app/services/proximity_service.dart';

import 'helpers/allowing_snapshot_guard.dart';

void main() {
  setUp(() {
    ProximityService().resetForTest();
    SharedPreferences.setMockInitialValues({});
  });

  test('ProximityService coalesces init and loads persisted switch', () async {
    SharedPreferences.setMockInitialValues({'proximity_unlock_enabled': true});
    ProximityService().resetForTest();

    final service = ProximityService();
    await Future.wait([
      service.init(ConnectionManager()),
      service.init(ConnectionManager()),
    ]);

    expect(service.enabled, isTrue);
  });

  test('ProximityService ignores blank target device ids', () async {
    final service = ProximityService();
    await service.init(ConnectionManager());

    service.setTargetDevice('   ');

    expect(service.targetDeviceId, isNull);
  });

  test('ProximityUnlockGuard blocks unlock when manual mode is enabled', () {
    const guard = ProximityUnlockGuard();
    final manager = ConnectionManager();
    final device = BluetoothDevice(remoteId: const DeviceIdentifier('bike-1'));
    addTearDown(manager.dispose);

    expect(
      guard.allowsUnlock(
        proximityEnabled: true,
        manualModeEnabled: true,
        targetDeviceId: 'bike-1',
        deviceId: 'bike-1',
        manager: manager,
        device: device,
        currentManager: manager,
        snapshotGuard: const BleConnectionSnapshotGuard(),
      ),
      isFalse,
    );
  });

  test('ProximityUnlockGuard allows unlock when manual mode is disabled', () {
    const guard = ProximityUnlockGuard();
    final manager = ConnectionManager();
    final device = BluetoothDevice(remoteId: const DeviceIdentifier('bike-1'));
    addTearDown(manager.dispose);

    expect(
      guard.allowsUnlock(
        proximityEnabled: true,
        manualModeEnabled: false,
        targetDeviceId: 'bike-1',
        deviceId: 'bike-1',
        manager: manager,
        device: device,
        currentManager: manager,
        snapshotGuard: const AllowingSnapshotGuard(),
      ),
      isTrue,
    );
  });
}
