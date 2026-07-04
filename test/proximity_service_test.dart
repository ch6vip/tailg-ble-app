import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/services/ble_connection_snapshot_guard.dart';
import 'package:tailg_ble_app/services/proximity_service.dart';

import 'helpers/allowing_snapshot_guard.dart';
import 'helpers/ble_guard_fixtures.dart';
import 'helpers/storage_mocks.dart';

void main() {
  setUp(() {
    ProximityService().resetForTest();
    resetMockPreferences();
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
    final fixture = BleGuardFixture();
    addTearDown(fixture.manager.dispose);

    expect(
      guard.allowsUnlock(
        proximityEnabled: true,
        manualModeEnabled: true,
        targetDeviceId: testBleDeviceId,
        deviceId: testBleDeviceId,
        manager: fixture.manager,
        device: fixture.device,
        currentManager: fixture.manager,
        snapshotGuard: const BleConnectionSnapshotGuard(),
      ),
      isFalse,
    );
  });

  test('ProximityUnlockGuard allows unlock when manual mode is disabled', () {
    const guard = ProximityUnlockGuard();
    final fixture = BleGuardFixture();
    addTearDown(fixture.manager.dispose);

    expect(
      guard.allowsUnlock(
        proximityEnabled: true,
        manualModeEnabled: false,
        targetDeviceId: testBleDeviceId,
        deviceId: testBleDeviceId,
        manager: fixture.manager,
        device: fixture.device,
        currentManager: fixture.manager,
        snapshotGuard: const AllowingSnapshotGuard(),
      ),
      isTrue,
    );
  });
}
