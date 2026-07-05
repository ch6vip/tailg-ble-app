String formatDateText(DateTime time) {
  return '${time.year}-${_twoDigits(time.month)}-${_twoDigits(time.day)}';
}

String formatDateMinuteText(DateTime time) {
  return '${formatDateText(time)} '
      '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
}

String formatMonthText(DateTime time) {
  return '${time.year}-${_twoDigits(time.month)}';
}

String formatMonthDayMinuteText(DateTime time) {
  return '${_twoDigits(time.month)}/${_twoDigits(time.day)} '
      '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
}

String formatLogClockTime(DateTime time) {
  return '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}:'
      '${_twoDigits(time.second)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
