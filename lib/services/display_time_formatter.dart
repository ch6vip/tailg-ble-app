String formatDateText(DateTime time) {
  return '${time.year}-${_twoDigits(time.month)}-${_twoDigits(time.day)}';
}

/// Normalize official travel/date payloads to a `yyyy-MM-dd` day key.
///
/// Accepts `yyyy-MM-dd`, `yyyy/MM/dd`, and longer timestamps such as
/// `yyyy-MM-dd HH:mm:ss`. Empty input returns an empty string.
String normalizeOfficialDateKey(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final datePart = trimmed.length >= 10 ? trimmed.substring(0, 10) : trimmed;
  return datePart.replaceAll('/', '-');
}

String formatDateMinuteText(DateTime time) {
  return '${formatDateText(time)} ${formatHourMinuteText(time.hour, time.minute)}';
}

String formatMonthText(DateTime time) {
  return '${time.year}-${_twoDigits(time.month)}';
}

DateTime? parseMonthText(String value) {
  final parts = value.trim().split('-');
  if (parts.length != 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return null;
  return DateTime(year, month);
}

/// Shift a `yyyy-MM` value by [delta] months.
///
/// Returns null when [month] is invalid, or when advancing past the current
/// calendar month (future months are blocked for travel/stats navigation).
String? shiftMonthText(String month, int delta, {DateTime Function()? clock}) {
  final current = parseMonthText(month);
  if (current == null) return null;
  return shiftMonthDate(current, delta, clock: clock);
}

/// Same bounds as [shiftMonthText] for an already-parsed month.
String? shiftMonthDate(
  DateTime current,
  int delta, {
  DateTime Function()? clock,
}) {
  final next = DateTime(current.year, current.month + delta);
  if (delta > 0) {
    final now = (clock ?? DateTime.now)();
    if (next.isAfter(DateTime(now.year, now.month))) return null;
  }
  return formatMonthText(next);
}

String formatMonthDayMinuteText(DateTime time) {
  return '${_twoDigits(time.month)}/${_twoDigits(time.day)} '
      '${formatHourMinuteText(time.hour, time.minute)}';
}

/// Padded `HH:mm` for pickers, schedules, and compact clock labels.
String formatHourMinuteText(int hour, int minute) {
  return '${_twoDigits(hour)}:${_twoDigits(minute)}';
}

String formatLogClockTime(DateTime time) {
  return '${formatHourMinuteText(time.hour, time.minute)}:'
      '${_twoDigits(time.second)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Human-readable sync age for control-page status.
String formatRelativeSyncText(DateTime? time, {DateTime Function()? clock}) {
  if (time == null) return '尚未同步';
  final now = (clock ?? DateTime.now)();
  final seconds = now.difference(time).inSeconds;
  if (seconds < 15) return '刚刚同步';
  if (seconds < 60) return '$seconds秒前同步';
  final minutes = now.difference(time).inMinutes;
  if (minutes < 60) return '$minutes分钟前同步';
  final hours = now.difference(time).inHours;
  if (hours < 24) return '$hours小时前同步';
  return '${formatMonthDayMinuteText(time)} 同步';
}
