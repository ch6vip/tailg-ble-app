import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/log_time_formatter.dart';

void main() {
  test('formatLogClockTime pads clock fields for log rows and reports', () {
    expect(formatLogClockTime(DateTime(2026, 7, 5, 1, 2, 3)), '01:02:03');
    expect(formatLogClockTime(DateTime(2026, 7, 5, 12, 30, 59)), '12:30:59');
  });
}
