import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/services/ble_connection_snapshot_guard.dart';
import 'package:tailg_ble_app/services/auto_connect_service.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

import 'helpers/allowing_snapshot_guard.dart';

void main() {
  setUp(() {
    AutoConnectService().resetForTest();
    VehicleStore().resetForTest();
    SharedPreferences.setMockInitialValues({});
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
  });

  group('AutoConnectTargetGuard', () {
    test('blocks connected auto targets when manual mode is enabled', () {
      const guard = AutoConnectTargetGuard();
      final manager = ConnectionManager();
      final device = BluetoothDevice(
        remoteId: const DeviceIdentifier('bike-1'),
      );
      addTearDown(manager.dispose);

      expect(
        guard.allowsConnectedTarget(
          autoConnectEnabled: true,
          manualModeEnabled: true,
          defaultVehicleId: 'bike-1',
          deviceId: 'bike-1',
          manager: manager,
          device: device,
          currentManager: manager,
          snapshotGuard: const BleConnectionSnapshotGuard(),
        ),
        isFalse,
      );
    });

    test('allows connected auto targets when manual mode is disabled', () {
      const guard = AutoConnectTargetGuard();
      final manager = ConnectionManager();
      final device = BluetoothDevice(
        remoteId: const DeviceIdentifier('bike-1'),
      );
      addTearDown(manager.dispose);

      expect(
        guard.allowsConnectedTarget(
          autoConnectEnabled: true,
          manualModeEnabled: false,
          defaultVehicleId: 'bike-1',
          deviceId: 'bike-1',
          manager: manager,
          device: device,
          currentManager: manager,
          snapshotGuard: const AllowingSnapshotGuard(),
        ),
        isTrue,
      );
    });
  });
}
