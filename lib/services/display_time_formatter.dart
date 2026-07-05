String formatDateMinuteText(DateTime time) {
  return '${time.year}-${_twoDigits(time.month)}-${_twoDigits(time.day)} '
      '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
