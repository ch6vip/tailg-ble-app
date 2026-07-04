import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/services/location_service.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

import 'helpers/storage_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VehicleStore().resetForTest();
    resetMockStorage();
  });

  test(
    'recordDefaultVehicleLocation initializes vehicle store before lookup',
    () async {
      final recordedAt = DateTime.now().toIso8601String();
      SharedPreferences.setMockInitialValues({
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
      });
      VehicleStore().resetForTest();

      final location = await LocationService().recordDefaultVehicleLocation();

      expect(location, isNotNull);
      expect(location!.coordinateText, '31.230400, 121.473700');
    },
  );

  test(
    'recordVehicleLocation normalizes ids before cached throttle lookup',
    () async {
      final recordedAt = DateTime.now().toIso8601String();
      SharedPreferences.setMockInitialValues({
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
      });
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
}
