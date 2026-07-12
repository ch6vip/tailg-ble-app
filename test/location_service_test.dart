import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/services/location_service.dart';
import 'package:tailg_ble_app/services/log_service.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

import 'helpers/platform_mocks.dart';
import 'helpers/storage_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocationService().resetForTest();
    LogService().resetForTest();
    VehicleStore().resetForTest();
    resetMockStorage();
  });

  tearDown(clearPlatformChannelMock);

  test(
    'captureCurrentLocation converts permission denial to domain error',
    () async {
      mockGeolocator(
        serviceEnabled: true,
        checkedPermission: LocationPermission.denied,
      );

      await expectLater(
        LocationService().captureCurrentLocation(),
        throwsA(
          isA<LocationCaptureException>().having(
            (error) => error.message,
            'message',
            '未授予定位权限',
          ),
        ),
      );
      expect(geolocatorMethodCalls, [
        'isLocationServiceEnabled',
        'checkPermission',
      ]);
    },
  );

  test(
    'captureCurrentLocation maps platform position with injected clock',
    () async {
      final now = DateTime(2026, 6, 20, 10, 15);
      LocationService().resetForTest(clock: () => now);
      mockGeolocator(
        serviceEnabled: true,
        checkedPermission: LocationPermission.always,
        currentPosition: const {
          'latitude': 22.5431,
          'longitude': 114.0579,
          'accuracy': 6.25,
        },
      );

      final location = await LocationService().captureCurrentLocation();

      expect(location.latitude, 22.5431);
      expect(location.longitude, 114.0579);
      expect(location.accuracy, 6.25);
      expect(location.recordedAt, now);
      expect(geolocatorMethodCalls, [
        'isLocationServiceEnabled',
        'checkPermission',
        'getCurrentPosition',
      ]);
    },
  );

  test(
    'recordDefaultVehicleLocation initializes vehicle store before lookup',
    () async {
      final now = DateTime(2026, 6, 20, 9, 30);
      LocationService().resetForTest(clock: () => now);
      final recordedAt = now.toIso8601String();
      SharedPreferences.setMockInitialValues(_storedVehiclePrefs(recordedAt));
      VehicleStore().resetForTest();

      final location = await LocationService().recordDefaultVehicleLocation();

      expect(location, isNotNull);
      expect(location!.coordinateText, '31.230400, 121.473700');
    },
  );

  test(
    'recordVehicleLocation normalizes ids before cached throttle lookup',
    () async {
      final now = DateTime(2026, 6, 20, 9, 30);
      LocationService().resetForTest(clock: () => now);
      final recordedAt = now.toIso8601String();
      SharedPreferences.setMockInitialValues(_storedVehiclePrefs(recordedAt));
      VehicleStore().resetForTest();

      final location = await LocationService().recordVehicleLocation(
        '  AA:BB:CC:DD:EE:FF  ',
      );

      expect(location, isNotNull);
      expect(location!.coordinateText, '31.230400, 121.473700');
    },
  );

  test('recordVehicleLocation ignores blank ids', () async {
    final location = await LocationService().recordVehicleLocation('   ');

    expect(location, isNull);
  });

  test(
    'recordVehicleLocation hides permission errors during silent capture',
    () async {
      final now = DateTime(2026, 6, 20, 10, 30);
      final stale = now.subtract(const Duration(minutes: 2));
      LocationService().resetForTest(clock: () => now);
      SharedPreferences.setMockInitialValues(
        _storedVehiclePrefs(stale.toIso8601String()),
      );
      VehicleStore().resetForTest();
      mockGeolocator(
        serviceEnabled: true,
        checkedPermission: LocationPermission.denied,
      );

      final location = await LocationService().recordVehicleLocation(
        'AA:BB:CC:DD:EE:FF',
      );

      expect(location, isNull);
      final entry = LogService().all.singleWhere(
        (item) => item.message == '记录车辆位置失败',
      );
      expect(entry.detail, '未授予定位权限');
      expect(entry.level, LogLevel.debug);
    },
  );

  test(
    'recordVehicleLocation rethrows permission errors for user requests',
    () async {
      final now = DateTime(2026, 6, 20, 10, 45);
      LocationService().resetForTest(clock: () => now);
      SharedPreferences.setMockInitialValues(
        _storedVehiclePrefs(now.toIso8601String()),
      );
      VehicleStore().resetForTest();
      mockGeolocator(
        serviceEnabled: true,
        checkedPermission: LocationPermission.denied,
        requestedPermission: LocationPermission.denied,
      );

      await expectLater(
        LocationService().recordVehicleLocation(
          'AA:BB:CC:DD:EE:FF',
          requestPermission: true,
        ),
        throwsA(isA<LocationCaptureException>()),
      );
      expect(geolocatorMethodCalls, [
        'isLocationServiceEnabled',
        'checkPermission',
        'requestPermission',
      ]);
    },
  );

  test('recordVehicleLocation persists a newly captured position', () async {
    final now = DateTime(2026, 6, 20, 11);
    final stale = now.subtract(const Duration(minutes: 2));
    LocationService().resetForTest(clock: () => now);
    SharedPreferences.setMockInitialValues(
      _storedVehiclePrefs(stale.toIso8601String()),
    );
    VehicleStore().resetForTest();
    mockGeolocator(
      serviceEnabled: true,
      checkedPermission: LocationPermission.whileInUse,
      currentPosition: const {
        'latitude': 23.1291,
        'longitude': 113.2644,
        'accuracy': 5.0,
      },
    );

    final location = await LocationService().recordVehicleLocation(
      'AA:BB:CC:DD:EE:FF',
      requestPermission: true,
    );

    expect(location, isNotNull);
    expect(location!.coordinateText, '23.129100, 113.264400');
    expect(location.recordedAt, now);
    expect(
      VehicleStore().defaultVehicle?.lastLocation?.coordinateText,
      '23.129100, 113.264400',
    );
  });
}

Map<String, Object> _storedVehiclePrefs(String recordedAt) {
  return {
    'vehicle_profiles': jsonEncode([
      {
        'id': 'AA:BB:CC:DD:EE:FF',
        'name': '默认车',
        'protocol': 'qgj',
        'createdAt': recordedAt,
        'updatedAt': recordedAt,
        'lastLocation': {
          'latitude': 31.2304,
          'longitude': 121.4737,
          'accuracy': 8.5,
          'recordedAt': recordedAt,
        },
      },
    ]),
    'vehicle_default_id': 'AA:BB:CC:DD:EE:FF',
  };
}
