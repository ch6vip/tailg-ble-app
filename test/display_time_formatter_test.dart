import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/display_time_formatter.dart';

void main() {
  test('formatDateText renders padded date display text', () {
    expect(formatDateText(DateTime(2026, 5, 29)), '2026-05-29');
    expect(formatDateText(DateTime(2026, 1, 2)), '2026-01-02');
  });

  test('formatDateMinuteText renders padded date and minute display text', () {
    expect(
      formatDateMinuteText(DateTime(2026, 5, 29, 10, 30)),
      '2026-05-29 10:30',
    );
    expect(
      formatDateMinuteText(DateTime(2026, 1, 2, 3, 4)),
      '2026-01-02 03:04',
    );
  });

  test('formatMonthText renders padded year-month display text', () {
    expect(formatMonthText(DateTime(2026, 7)), '2026-07');
    expect(formatMonthText(DateTime(2026, 1)), '2026-01');
  });

  test('formatMonthDayMinuteText renders padded compact time text', () {
    expect(
      formatMonthDayMinuteText(DateTime(2026, 5, 29, 10, 30)),
      '05/29 10:30',
    );
    expect(formatMonthDayMinuteText(DateTime(2026, 1, 2, 3, 4)), '01/02 03:04');
  });

  test('formatLogClockTime pads clock fields for log rows and reports', () {
    expect(formatLogClockTime(DateTime(2026, 7, 5, 1, 2, 3)), '01:02:03');
    expect(formatLogClockTime(DateTime(2026, 7, 5, 12, 30, 59)), '12:30:59');
  });
}
