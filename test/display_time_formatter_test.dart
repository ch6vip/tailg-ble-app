import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/display_time_formatter.dart';

void main() {
  test('formatDateText renders padded date display text', () {
    expect(formatDateText(DateTime(2026, 5, 29)), '2026-05-29');
    expect(formatDateText(DateTime(2026, 1, 2)), '2026-01-02');
  });

  test('normalizeOfficialDateKey accepts common official date shapes', () {
    expect(normalizeOfficialDateKey('2026-05-29'), '2026-05-29');
    expect(normalizeOfficialDateKey('2026/05/29'), '2026-05-29');
    expect(normalizeOfficialDateKey('2026-05-29 10:30:00'), '2026-05-29');
    expect(normalizeOfficialDateKey(' 2026/05/29 08:00 '), '2026-05-29');
    expect(normalizeOfficialDateKey(''), '');
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

  test('parseMonthText accepts valid months and rejects invalid input', () {
    expect(parseMonthText('2026-07'), DateTime(2026, 7));
    expect(parseMonthText(' 2026-01 '), DateTime(2026, 1));
    expect(parseMonthText('2026-00'), isNull);
    expect(parseMonthText('2026-13'), isNull);
    expect(parseMonthText('not-a-month'), isNull);
  });

  test('shiftMonthText navigates months and blocks future months', () {
    final clock = () => DateTime(2026, 7, 15);
    expect(shiftMonthText('2026-07', -1, clock: clock), '2026-06');
    expect(shiftMonthText('2026-07', 1, clock: clock), isNull);
    expect(shiftMonthText('2026-06', 1, clock: clock), '2026-07');
    expect(shiftMonthText('not-a-month', -1, clock: clock), isNull);
    expect(
      shiftMonthDate(DateTime(2026, 12), 1, clock: () => DateTime(2027, 1, 1)),
      '2027-01',
    );
  });

  test('formatMonthDayMinuteText renders padded compact time text', () {
    expect(
      formatMonthDayMinuteText(DateTime(2026, 5, 29, 10, 30)),
      '05/29 10:30',
    );
    expect(formatMonthDayMinuteText(DateTime(2026, 1, 2, 3, 4)), '01/02 03:04');
  });

  test('formatHourMinuteText pads hour and minute fields', () {
    expect(formatHourMinuteText(1, 2), '01:02');
    expect(formatHourMinuteText(12, 30), '12:30');
  });

  test('formatLogClockTime pads clock fields for log rows and reports', () {
    expect(formatLogClockTime(DateTime(2026, 7, 5, 1, 2, 3)), '01:02:03');
    expect(formatLogClockTime(DateTime(2026, 7, 5, 12, 30, 59)), '12:30:59');
  });

  test('formatRelativeSyncText covers recent ages', () {
    final now = DateTime(2026, 7, 11, 12, 0, 0);
    expect(formatRelativeSyncText(null, clock: () => now), '尚未同步');
    expect(
      formatRelativeSyncText(
        now.subtract(const Duration(seconds: 5)),
        clock: () => now,
      ),
      '刚刚同步',
    );
    expect(
      formatRelativeSyncText(
        now.subtract(const Duration(seconds: 40)),
        clock: () => now,
      ),
      '40秒前同步',
    );
    expect(
      formatRelativeSyncText(
        now.subtract(const Duration(minutes: 3)),
        clock: () => now,
      ),
      '3分钟前同步',
    );
    expect(
      formatRelativeSyncText(
        now.subtract(const Duration(hours: 2)),
        clock: () => now,
      ),
      '2小时前同步',
    );
  });
}
