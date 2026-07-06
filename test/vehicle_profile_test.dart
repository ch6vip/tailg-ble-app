import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';

void main() {
  group('VehicleProfile', () {
    test('decodes persisted last location maps', () {
      final profile = VehicleProfile.fromJson({
        'id': 'AA:BB:CC:DD:EE:FF',
        'lastLocation': {
          'latitude': '31.2304',
          'longitude': '121.4737',
          'accuracy': '12',
          'recordedAt': '2026-06-09T10:30:00.000',
        },
      });

      expect(profile.lastLocation, isNotNull);
      expect(profile.lastLocation?.latitude, 31.2304);
      expect(profile.lastLocation?.longitude, 121.4737);
      expect(profile.lastLocation?.accuracy, 12);
      expect(profile.lastLocation?.recordedAt, DateTime(2026, 6, 9, 10, 30));
    });

    test('ignores non-map persisted last locations', () {
      final profile = VehicleProfile.fromJson({
        'id': 'AA:BB:CC:DD:EE:FF',
        'lastLocation': 42,
      });

      expect(profile.lastLocation, isNull);
    });

    test('copies persisted last location map before decoding', () {
      final lastLocation = <String, Object?>{
        'latitude': '31.2304',
        'longitude': '121.4737',
        'accuracy': '12',
        'recordedAt': '2026-06-09T10:30:00.000',
      };

      final profile = VehicleProfile.fromJson({
        'id': 'AA:BB:CC:DD:EE:FF',
        'lastLocation': lastLocation,
      });
      lastLocation['latitude'] = '0';

      expect(profile.lastLocation?.latitude, 31.2304);
    });

    test('uses provided fallback time for malformed timestamps', () {
      final fallbackNow = DateTime(2026, 6, 9, 10, 30);

      final profile = VehicleProfile.fromJson({
        'id': 'AA:BB:CC:DD:EE:FF',
        'createdAt': 'bad-date',
        'updatedAt': 'bad-date',
        'lastLocation': {'recordedAt': 'bad-date'},
      }, fallbackNow: fallbackNow);

      expect(profile.createdAt, fallbackNow);
      expect(profile.updatedAt, fallbackNow);
      expect(profile.lastLocation?.recordedAt, fallbackNow);
    });

    test('uses injected clock when fallback time is omitted', () {
      final generatedAt = DateTime(2026, 6, 9, 10, 30);

      final profile = VehicleProfile.fromJson({
        'id': 'AA:BB:CC:DD:EE:FF',
        'createdAt': 'bad-date',
        'updatedAt': 'bad-date',
        'lastLocation': {'recordedAt': 'bad-date'},
      }, clock: () => generatedAt);

      expect(profile.createdAt, generatedAt);
      expect(profile.updatedAt, generatedAt);
      expect(profile.lastLocation?.recordedAt, generatedAt);
    });
  });
}
