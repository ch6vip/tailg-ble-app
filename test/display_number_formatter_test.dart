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
}
