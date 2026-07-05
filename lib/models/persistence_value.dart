String parsePersistedString(Object? value) {
  return value?.toString().trim() ?? '';
}

double? parsePersistedDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int? parsePersistedInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

DateTime? parsePersistedDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
