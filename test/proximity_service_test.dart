import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/ble/constants.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/services/ble_connection_snapshot_guard.dart';
import 'package:tailg_ble_app/services/location_service.dart';
import 'package:tailg_ble_app/services/log_service.dart';
import 'package:tailg_ble_app/services/manual_mode_service.dart';
import 'package:tailg_ble_app/services/proximity_service.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

import 'helpers/allowing_snapshot_guard.dart';
import 'helpers/ble_guard_fixtures.dart';
import 'helpers/source_scan.dart';
import 'helpers/storage_mocks.dart';

void main() {
  setUp(() {
    ProximityService().resetForTest();
    ManualModeService().resetForTest();
    LocationService().resetForTest();
    VehicleStore().resetForTest();
    LogService().clear();
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

  test('ProximityService loads manual mode before starting scan', () async {
    SharedPreferences.setMockInitialValues({'manual_mode_enabled': true});
    ManualModeService().resetForTest();

    final service = ProximityService();
    service.setTargetDevice(testBleDeviceId);
    await service.setEnabled(true);

    expect(ManualModeService().enabled, isTrue);
  });

  test('ProximityService rechecks switch state after manual mode init', () {
    final source = readSource('lib/services/proximity_service.dart');
    final initIndex = source.indexOf('await ManualModeService().init();');
    final enabledGuardIndex = source.indexOf(
      'if (!_enabled || _targetDeviceId == null) return;',
      initIndex + 1,
    );
    final manualGuardIndex = source.indexOf(
      'if (ManualModeService().enabled) return;',
      initIndex,
    );
    final startScanIndex = source.indexOf(
      'FlutterBluePlus.startScan(',
      initIndex,
    );

    expect(initIndex, greaterThanOrEqualTo(0));
    expect(enabledGuardIndex, greaterThan(initIndex));
    expect(enabledGuardIndex, lessThan(manualGuardIndex));
    expect(enabledGuardIndex, lessThan(startScanIndex));
  });

  test('ProximityService rechecks scanning state after manual mode init', () {
    final source = readSource('lib/services/proximity_service.dart');
    final methodStart = source.indexOf('Future<void> start() async');
    final initIndex = source.indexOf(
      'await ManualModeService().init();',
      methodStart,
    );
    final scanningGuardIndex = source.indexOf(
      'if (_scanning) return;',
      initIndex + 1,
    );
    final scanningStartIndex = source.indexOf('_scanning = true;', initIndex);
    final startScanIndex = source.indexOf(
      'FlutterBluePlus.startScan(',
      initIndex,
    );

    expect(methodStart, greaterThanOrEqualTo(0));
    expect(initIndex, greaterThan(methodStart));
    expect(scanningGuardIndex, greaterThan(initIndex));
    expect(scanningGuardIndex, lessThan(scanningStartIndex));
    expect(scanningGuardIndex, lessThan(startScanIndex));
  });

  test('ProximityService snapshots target id before scan listener starts', () {
    final source = readSource('lib/services/proximity_service.dart');
    final methodStart = source.indexOf('Future<void> start() async');
    final targetSnapshot = source.indexOf(
      'final targetDeviceId = _targetDeviceId;',
      methodStart,
    );
    final listenerStart = source.indexOf(
      'FlutterBluePlus.scanResults.listen',
      methodStart,
    );
    final listenerEnd = source.indexOf('    });', listenerStart);

    expect(methodStart, greaterThanOrEqualTo(0));
    expect(targetSnapshot, greaterThan(methodStart));
    expect(listenerStart, greaterThan(targetSnapshot));
    expect(listenerEnd, greaterThan(listenerStart));

    final listenerSource = source.substring(listenerStart, listenerEnd);
    expect(listenerSource, contains('== targetDeviceId'));
    expect(listenerSource, isNot(contains('== _targetDeviceId')));
  });

  test('ProximityService rechecks unlock state before connecting', () {
    final source = readSource('lib/services/proximity_service.dart');
    final methodStart = source.indexOf(
      'Future<void> _connectAndUnlock(BluetoothDevice device) async',
    );
    final locationGuard = source.indexOf(
      'if (!_unlockGuard.hasUsableUnlockLocation(unlockLocation))',
      methodStart,
    );
    final enabledGuard = source.indexOf('if (!_enabled ||', locationGuard);
    final manualGuard = source.indexOf(
      'ManualModeService().enabled',
      enabledGuard,
    );
    final targetGuard = source.indexOf(
      '_targetDeviceId != deviceId',
      enabledGuard,
    );
    final connectCall = source.indexOf('await manager.connect(device);');

    expect(methodStart, greaterThanOrEqualTo(0));
    expect(locationGuard, greaterThan(methodStart));
    expect(enabledGuard, greaterThan(locationGuard));
    expect(manualGuard, greaterThan(enabledGuard));
    expect(targetGuard, greaterThan(enabledGuard));
    expect(connectCall, greaterThan(targetGuard));
  });

  test('ProximityService ignores target hits after unlock is disabled', () {
    final fixture = BleGuardFixture();
    final now = DateTime(2026, 6, 9, 10, 30);
    addTearDown(fixture.manager.dispose);
    ProximityService().resetForTest(clock: () => now);

    final service = ProximityService();
    service.setTargetDevice(testBleDeviceId);

    service.handleTargetFoundForTest(
      ScanResult(
        device: fixture.device,
        advertisementData: _advertisementData(),
        rssi: ProximityUnlockGuard.minUnlockRssi,
        timeStamp: now,
      ),
    );

    expect(service.lastUnlockTime, isNull);
  });

  test(
    'ProximityService uses injected clock for nearby unlock cooldown',
    () async {
      SharedPreferences.setMockInitialValues({
        'proximity_unlock_enabled': true,
      });
      final fixture = BleGuardFixture();
      final now = DateTime(2026, 6, 9, 10, 30);
      addTearDown(fixture.manager.dispose);
      ProximityService().resetForTest(clock: () => now);

      final service = ProximityService();
      await service.init(fixture.manager);
      service.setTargetDevice(testBleDeviceId);

      service.handleTargetFoundForTest(
        ScanResult(
          device: fixture.device,
          advertisementData: _advertisementData(),
          rssi: ProximityUnlockGuard.minUnlockRssi,
          timeStamp: now,
        ),
      );

      expect(service.lastUnlockTime, now);
    },
  );

  test(
    'ProximityService does not log success when unlock command fails',
    () async {
      final now = DateTime(2026, 6, 9, 10, 30);
      SharedPreferences.setMockInitialValues({
        'proximity_unlock_enabled': true,
      });
      LocationService().resetForTest(clock: () => now);
      ProximityService().resetForTest(clock: () => now);
      final device = BluetoothDevice(
        remoteId: const DeviceIdentifier(testBleDeviceId),
      );
      final manager = _UnlockResultConnectionManager(
        device: device,
        unlockResult: false,
      );
      addTearDown(manager.dispose);

      await VehicleStore().upsert(
        id: testBleDeviceId,
        name: '测试车辆',
        makeDefault: true,
        savedAt: now,
      );
      await VehicleStore().updateLastLocation(
        testBleDeviceId,
        _location(accuracy: 8, recordedAt: now),
        savedAt: now,
      );

      final service = ProximityService();
      await service.init(manager);
      service.setTargetDevice(testBleDeviceId);

      service.handleTargetFoundForTest(
        ScanResult(
          device: device,
          advertisementData: _advertisementData(),
          rssi: ProximityUnlockGuard.minUnlockRssi,
          timeStamp: now,
        ),
      );

      await manager.unlockAttempted.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);

      expect(
        LogService().all.where((entry) => entry.message == '感应解锁: 解锁成功'),
        isEmpty,
      );
      expect(
        LogService().all.where((entry) => entry.message == '感应解锁: 解锁指令失败'),
        isNotEmpty,
      );
    },
  );

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

VehicleLocation _location({required double accuracy, DateTime? recordedAt}) {
  return VehicleLocation(
    latitude: 31.2304,
    longitude: 121.4737,
    accuracy: accuracy,
    recordedAt: recordedAt ?? DateTime(2026),
  );
}

class _UnlockResultConnectionManager extends ConnectionManager {
  _UnlockResultConnectionManager({
    required BluetoothDevice device,
    required this.unlockResult,
  }) : _device = device;

  final BluetoothDevice _device;
  final bool unlockResult;
  final unlockAttempted = Completer<void>();
  bool _connected = false;

  @override
  ConnectionState get state =>
      _connected ? ConnectionState.ready : ConnectionState.disconnected;

  @override
  BluetoothDevice? get device => _connected ? _device : null;

  @override
  Future<void> connect(BluetoothDevice device) async {
    _connected = true;
  }

  @override
  Future<bool> sendCommand(CommandCode cmd) async {
    if (cmd == CommandCode.unlock && !unlockAttempted.isCompleted) {
      unlockAttempted.complete();
    }
    return unlockResult;
  }
}
