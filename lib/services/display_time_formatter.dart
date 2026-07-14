String formatDateText(DateTime time) {
  return '${time.year}-${_twoDigits(time.month)}-${_twoDigits(time.day)}';
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
