import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/services/ble_connection_snapshot_guard.dart';
import 'package:tailg_ble_app/services/auto_connect_service.dart';
import 'package:tailg_ble_app/services/manual_mode_service.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

import 'helpers/allowing_snapshot_guard.dart';
import 'helpers/ble_guard_fixtures.dart';
import 'helpers/source_scan.dart';
import 'helpers/storage_mocks.dart';

void main() {
  setUp(() {
    AutoConnectService().resetForTest();
    ManualModeService().resetForTest();
    VehicleStore().resetForTest();
    resetMockPreferences();
  });

  group('AutoConnectRunGate', () {
    test('coalesces concurrent runs into one operation', () async {
      final gate = AutoConnectRunGate();
      final completer = Completer<void>();
      var calls = 0;

      final first = gate.run(() {
        calls += 1;
        return completer.future;
      });
      final second = gate.run(() {
        calls += 1;
        return Future.value();
      });

      expect(identical(first, second), isTrue);
      expect(calls, 1);
      expect(gate.isRunning, isTrue);

      completer.complete();
      await first;

      expect(gate.isRunning, isFalse);
    });

    test('releases the gate after operation failure', () async {
      final gate = AutoConnectRunGate();
      var calls = 0;

      await expectLater(
        gate.run(() {
          calls += 1;
          throw StateError('scan failed');
        }),
        throwsStateError,
      );

      expect(gate.isRunning, isFalse);

      await gate.run(() async {
        calls += 1;
      });

      expect(calls, 2);
    });
  });

  group('AutoConnectService', () {
    test('coalesces init and migrates legacy target once', () async {
      SharedPreferences.setMockInitialValues({
        'auto_connect_enabled': true,
        'auto_connect_device_id': 'AA:BB:CC:DD:EE:FF',
        'auto_connect_device_name': 'Legacy Bike',
      });
      AutoConnectService().resetForTest();
      VehicleStore().resetForTest();

      final service = AutoConnectService();
      await Future.wait([
        service.init(ConnectionManager()),
        service.init(ConnectionManager()),
      ]);

      expect(service.enabled, isTrue);
      expect(service.lastDeviceName, 'Legacy Bike');
      expect(VehicleStore().vehicles, hasLength(1));
      expect(VehicleStore().defaultVehicle?.id, 'AA:BB:CC:DD:EE:FF');
    });

    test(
      'saveDevice persists the selected target as the default vehicle',
      () async {
        final fixture = BleGuardFixture();
        final lastConnectedAt = DateTime(2026, 6, 10, 9, 30);
        addTearDown(fixture.manager.dispose);

        final profile = await AutoConnectService().saveDevice(
          fixture.device,
          lastConnectedAt: lastConnectedAt,
        );

        final prefs = await SharedPreferences.getInstance();
        final defaultVehicle = VehicleStore().defaultVehicle;
        expect(profile, same(defaultVehicle));
        expect(prefs.getString('auto_connect_device_id'), testBleDeviceId);
        expect(prefs.containsKey('auto_connect_device_name'), isFalse);
        expect(AutoConnectService().lastDeviceName, isEmpty);
        expect(defaultVehicle?.id, testBleDeviceId);
        expect(defaultVehicle?.protocol, VehicleProtocol.auto);
        expect(defaultVehicle?.displayName, '未命名车辆');
        expect(defaultVehicle?.createdAt, lastConnectedAt);
        expect(defaultVehicle?.updatedAt, lastConnectedAt);
        expect(defaultVehicle?.lastConnectedAt, lastConnectedAt);
      },
    );

    test('saveDevice uses service clock for default timestamps', () async {
      final fixture = BleGuardFixture();
      final connectedAt = DateTime(2026, 6, 10, 10, 30);
      addTearDown(fixture.manager.dispose);
      AutoConnectService().resetForTest(clock: () => connectedAt);

      await AutoConnectService().saveDevice(fixture.device);

      final defaultVehicle = VehicleStore().defaultVehicle;
      expect(defaultVehicle?.createdAt, connectedAt);
      expect(defaultVehicle?.updatedAt, connectedAt);
      expect(defaultVehicle?.lastConnectedAt, connectedAt);
    });

    test('saveDevice persists the selected protocol', () async {
      final fixture = BleGuardFixture();
      addTearDown(fixture.manager.dispose);

      final profile = await AutoConnectService().saveDevice(
        fixture.device,
        protocol: VehicleProtocol.qgj,
      );

      expect(profile.protocol, VehicleProtocol.qgj);
      expect(VehicleStore().defaultVehicle?.protocol, VehicleProtocol.qgj);
    });

    test('resetForTest restores stream after dispose', () async {
      final service = AutoConnectService();

      service.dispose();
      service.resetForTest();

      final event = service.enabledStream.first;
      await service.setEnabled(true);

      await expectLater(event, completion(isTrue));
      expect(service.enabled, isTrue);
    });

    test('scan startup failures complete the auto connect attempt', () {
      final source = readSource('lib/services/auto_connect_service.dart');

      expect(source, contains('自动连接: 扫描启动失败'));
      expect(
        source,
        contains('if (!completer.isCompleted) completer.complete();'),
      );
      expect(source, contains('} catch (e) {'));
    });

    test('tryAutoConnect snapshots target id before scan listener starts', () {
      final source = readSource('lib/services/auto_connect_service.dart');
      final methodStart = source.indexOf('Future<void> _tryAutoConnectOnce()');
      final targetSnapshot = source.indexOf(
        'final targetDeviceId = _lastDeviceId;',
        methodStart,
      );
      final listenerStart = source.indexOf(
        'FlutterBluePlus.scanResults.listen',
        methodStart,
      );
      final listenerEnd = source.indexOf('      });', listenerStart);

      expect(methodStart, greaterThanOrEqualTo(0));
      expect(targetSnapshot, greaterThan(methodStart));
      expect(listenerStart, greaterThan(targetSnapshot));
      expect(listenerEnd, greaterThan(listenerStart));

      final listenerSource = source.substring(listenerStart, listenerEnd);
      expect(listenerSource, contains('== targetDeviceId'));
      expect(listenerSource, isNot(contains('== _lastDeviceId')));
    });

    test('tryAutoConnect rechecks enabled state before connecting', () {
      final source = readSource('lib/services/auto_connect_service.dart');
      final methodStart = source.indexOf('Future<void> _tryAutoConnectOnce()');
      final listenerStart = source.indexOf(
        'FlutterBluePlus.scanResults.listen',
        methodStart,
      );
      final enabledGuard = source.indexOf('if (!_enabled) {', listenerStart);
      final connectCall = source.indexOf('_doConnect(r.device)', listenerStart);

      expect(methodStart, greaterThanOrEqualTo(0));
      expect(listenerStart, greaterThan(methodStart));
      expect(enabledGuard, greaterThan(listenerStart));
      expect(connectCall, greaterThan(enabledGuard));
    });

    test(
      'tryAutoConnect loads manual mode before checking the guard',
      () async {
        SharedPreferences.setMockInitialValues({'manual_mode_enabled': true});
        ManualModeService().resetForTest();

        await AutoConnectService().tryAutoConnect();

        expect(ManualModeService().enabled, isTrue);
      },
    );
  });

  group('AutoConnectTargetGuard', () {
    test('blocks connected auto targets when manual mode is enabled', () {
      const guard = AutoConnectTargetGuard();
      final fixture = BleGuardFixture();
      addTearDown(fixture.manager.dispose);

      expect(
        guard.allowsConnectedTarget(
          autoConnectEnabled: true,
          manualModeEnabled: true,
          defaultVehicleId: testBleDeviceId,
          deviceId: testBleDeviceId,
          manager: fixture.manager,
          device: fixture.device,
          currentManager: fixture.manager,
          snapshotGuard: const BleConnectionSnapshotGuard(),
        ),
        isFalse,
      );
    });

    test('allows connected auto targets when manual mode is disabled', () {
      const guard = AutoConnectTargetGuard();
      final fixture = BleGuardFixture();
      addTearDown(fixture.manager.dispose);

      expect(
        guard.allowsConnectedTarget(
          autoConnectEnabled: true,
          manualModeEnabled: false,
          defaultVehicleId: testBleDeviceId,
          deviceId: testBleDeviceId,
          manager: fixture.manager,
          device: fixture.device,
          currentManager: fixture.manager,
          snapshotGuard: const AllowingSnapshotGuard(),
        ),
        isTrue,
      );
    });
  });
}
