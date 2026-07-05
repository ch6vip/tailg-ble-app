import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/geo_coordinate.dart';

void main() {
  test('formatCoordinateText renders six decimal coordinate text', () {
    expect(formatCoordinateText(31.2304, 121.4737), '31.230400, 121.473700');
    expect(formatCoordinateText(-0.1, 0), '-0.100000, 0.000000');
  });

  test('isZeroCoordinate defaults to exact zero matching', () {
    expect(isZeroCoordinate(0, 0), isTrue);
    expect(isZeroCoordinate(0.0000005, 0), isFalse);
    expect(isZeroCoordinate(0, -0.0000005), isFalse);
    expect(isZeroCoordinate(31.2304, 121.4737), isFalse);
  });

  test('isZeroCoordinate supports tolerance based matching', () {
    expect(
      isZeroCoordinate(0.0000005, -0.0000005, tolerance: 0.000001),
      isTrue,
    );
    expect(isZeroCoordinate(0.000001, 0, tolerance: 0.000001), isFalse);
    expect(isZeroCoordinate(0, -0.000001, tolerance: 0.000001), isFalse);
    expect(
      isZeroCoordinate(0.0000005, 0.0000005, tolerance: -0.000001),
      isTrue,
    );
  });
}
