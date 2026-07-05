import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/persistence_value.dart';

void main() {
  test('parsePersistedString trims stored values and falls back to empty', () {
    expect(parsePersistedString(null), '');
    expect(parsePersistedString('  bike  '), 'bike');
    expect(parsePersistedString(123), '123');
  });

  test('parsePersistedDouble preserves previous numeric parsing', () {
    expect(parsePersistedDouble(12), 12.0);
    expect(parsePersistedDouble(12.5), 12.5);
    expect(parsePersistedDouble(' 31.2304 '), 31.2304);
    expect(parsePersistedDouble('bad'), isNull);
  });

  test('parsePersistedInt preserves previous integer parsing', () {
    expect(parsePersistedInt(12), 12);
    expect(parsePersistedInt(12.9), 12);
    expect(parsePersistedInt(' 123456 '), 123456);
    expect(parsePersistedInt('12.9'), isNull);
    expect(parsePersistedInt('bad'), isNull);
  });

  test('parsePersistedDate preserves previous persistence date parsing', () {
    expect(parsePersistedDate(null), isNull);
    expect(parsePersistedDate('bad-date'), isNull);
    expect(
      parsePersistedDate('2026-06-09T10:30:00.000'),
      DateTime(2026, 6, 9, 10, 30),
    );
    expect(parsePersistedDate(789), isNull);
  });
}
