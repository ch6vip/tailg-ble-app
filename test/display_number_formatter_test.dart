import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/display_number_formatter.dart';

void main() {
  test('formatCompactDecimal rounds and drops trailing .0', () {
    expect(formatCompactDecimal(12), '12');
    expect(formatCompactDecimal(12.0), '12');
    expect(formatCompactDecimal(12.5), '12.5');
    expect(formatCompactDecimal(20.133333333), '20.1');
    expect(formatCompactDecimal(45.6789), '45.7');
  });

  test('formatCompactDecimalText preserves non-numeric payloads', () {
    expect(formatCompactDecimalText('604.0'), '604');
    expect(formatCompactDecimalText('20.133333333'), '20.1');
    expect(formatCompactDecimalText('n/a'), 'n/a');
    expect(formatCompactDecimalText(''), '');
  });

  test('formatDistanceMeters switches units at 1 km', () {
    expect(formatDistanceMeters(500), '500m');
    expect(formatDistanceMeters(1000), '1km');
    expect(formatDistanceMeters(1500), '1.5km');
    expect(formatDistanceMeters(2040), '2km');
  });

  test('parseTravelMileageMeters takes integer meters like official app', () {
    expect(parseTravelMileageMeters('57291'), 57291);
    expect(parseTravelMileageMeters('57291.9'), 57291);
    expect(parseTravelMileageMeters('12.5'), 12);
    expect(parseTravelMileageMeters(''), 0);
    expect(parseTravelMileageMeters(null), 0);
  });

  test(
    'formatTravelMileageMeters matches ViewAdapter.setHisListItemMilage',
    () {
      // Real bug case: 57291 m → 57.29 km (official).
      expect(formatTravelMileageMeters(57291), '57.29km');
      expect(formatTravelMileageMetersText('57291.0'), '57.29km');
      expect(formatTravelMileageMeters(500), '500m');
      expect(formatTravelMileageMeters(999), '999m');
      expect(formatTravelMileageMeters(1000), '1km');
      expect(formatTravelMileageMeters(1500), '1.5km');
      // Ride-stats style always uses km.
      expect(formatTravelMileageMeters(500, alwaysKm: true), '0.5km');
      expect(formatTravelMileageMeters(57291, alwaysKm: true), '57.29km');
    },
  );

  test('formatDecimalDown truncates toward zero like RoundingMode.DOWN', () {
    expect(formatDecimalDown(57.291, fractionDigits: 2), '57.29');
    expect(formatDecimalDown(1.999, fractionDigits: 2), '1.99');
    expect(formatDecimalDown(12.0, fractionDigits: 2), '12');
    expect(formatDecimalDown(0.5, fractionDigits: 2), '0.5');
  });

  test('travelMetersToKm converts official payloads', () {
    expect(travelMetersToKm(57291), closeTo(57.291, 1e-9));
    expect(travelMetersToKm(0), 0);
  });
}
