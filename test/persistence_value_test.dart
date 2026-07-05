import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/persistence_value.dart';

void main() {
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
