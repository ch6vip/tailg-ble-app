import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/display_time_formatter.dart';

void main() {
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
}
