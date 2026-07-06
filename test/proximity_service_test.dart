import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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

  test('ProximityService resetForTest restores stream after dispose', () async {
    final service = ProximityService();

    service.dispose();
    service.resetForTest();

    final event = service.enabledStream.first;
    await service.setEnabled(true);

    await expectLater(event, completion(isTrue));
    expect(service.enabled, isTrue);
  });

  test('ProximityService uses injected clock for nearby unlock cooldown', () {
    final fixture = BleGuardFixture();
    final now = DateTime(2026, 6, 9, 10, 30);
    addTearDown(fixture.manager.dispose);
    ProximityService().resetForTest(clock: () => now);

    final service = ProximityService();
    service.handleTargetFoundForTest(
      ScanResult(
        device: fixture.device,
        advertisementData: _advertisementData(),
        rssi: ProximityUnlockGuard.minUnlockRssi,
        timeStamp: now,
      ),
    );

    expect(service.lastUnlockTime, now);
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

  test('ProximityUnlockGuard allows nearby unlock outside cooldown', () {
    const guard = ProximityUnlockGuard();
    final now = DateTime(2026, 6, 9, 10, 30);

    expect(
      guard.allowsNearbyUnlock(
        rssi: -75,
        now: now,
        lastUnlockTime: now.subtract(const Duration(seconds: 30)),
      ),
      isTrue,
    );
  });

  test('ProximityUnlockGuard blocks weak RSSI and active cooldowns', () {
    const guard = ProximityUnlockGuard();
    final now = DateTime(2026, 6, 9, 10, 30);

    expect(
      guard.allowsNearbyUnlock(rssi: -76, now: now, lastUnlockTime: null),
      isFalse,
    );
    expect(
      guard.allowsNearbyUnlock(
        rssi: -60,
        now: now,
        lastUnlockTime: now.subtract(const Duration(seconds: 29)),
      ),
      isFalse,
    );
  });
}

AdvertisementData _advertisementData() {
  return AdvertisementData(
    advName: '',
    txPowerLevel: null,
    appearance: null,
    connectable: true,
    manufacturerData: const <int, List<int>>{},
    serviceData: const <Guid, List<int>>{},
    serviceUuids: const <Guid>[],
  );
}

VehicleLocation _location({required double accuracy}) {
  return VehicleLocation(
    latitude: 31.2304,
    longitude: 121.4737,
    accuracy: accuracy,
    recordedAt: DateTime(2026),
  );
}
