import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
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
        unlockLocation: _location(accuracy: 8),
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
        unlockLocation: _location(accuracy: 8),
        manager: fixture.manager,
        device: fixture.device,
        currentManager: fixture.manager,
        snapshotGuard: const AllowingSnapshotGuard(),
      ),
      isTrue,
    );
  });

  test('ProximityUnlockGuard blocks unlock without location evidence', () {
    const guard = ProximityUnlockGuard();
    final fixture = BleGuardFixture();
    addTearDown(fixture.manager.dispose);

    expect(
      guard.allowsUnlock(
        proximityEnabled: true,
        manualModeEnabled: false,
        targetDeviceId: testBleDeviceId,
        deviceId: testBleDeviceId,
        unlockLocation: null,
        manager: fixture.manager,
        device: fixture.device,
        currentManager: fixture.manager,
        snapshotGuard: const AllowingSnapshotGuard(),
      ),
      isFalse,
    );
    expect(guard.locationBlockReason(null), '定位不可用');
  });

  test('ProximityUnlockGuard blocks unlock when location is inaccurate', () {
    const guard = ProximityUnlockGuard();
    final fixture = BleGuardFixture();
    addTearDown(fixture.manager.dispose);

    expect(
      guard.allowsUnlock(
        proximityEnabled: true,
        manualModeEnabled: false,
        targetDeviceId: testBleDeviceId,
        deviceId: testBleDeviceId,
        unlockLocation: _location(accuracy: 45),
        manager: fixture.manager,
        device: fixture.device,
        currentManager: fixture.manager,
        snapshotGuard: const AllowingSnapshotGuard(),
      ),
      isFalse,
    );
    expect(
      guard.locationBlockReason(_location(accuracy: 45)),
      '定位精度 45.0m 超过 30m',
    );
  });
}

VehicleLocation _location({required double accuracy}) {
  return VehicleLocation(
    latitude: 31.2304,
    longitude: 121.4737,
    accuracy: accuracy,
    recordedAt: DateTime(2026),
  );
}
