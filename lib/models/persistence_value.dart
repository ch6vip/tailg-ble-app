String parsePersistedString(Object? value) {
  return value?.toString().trim() ?? '';
}

String parsePersistedStringOr(Object? value, String fallback) {
  final parsed = parsePersistedString(value);
  return parsed.isEmpty ? fallback : parsed;
}

List<String> parsePersistedStringList(Object? value) {
  return _persistedStringItems(value).toList();
}

Map<String, dynamic>? parsePersistedMap(Object? value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> parsePersistedMapList(Object? value) {
  return _persistedMapItems(value).toList(growable: false);
}

Iterable<Map<String, dynamic>> _persistedMapItems(Object? value) {
  return _persistedListItems(
    value,
  ).map(parsePersistedMap).whereType<Map<String, dynamic>>();
}

Iterable<String> _persistedStringItems(Object? value) {
  return _persistedListItems(value).whereType<String>();
}

Iterable<Object?> _persistedListItems(Object? value) {
  if (value is! List) return const [];
  return value.cast<Object?>();
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

bool parsePersistedBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

DateTime? parsePersistedDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

DateTime parsePersistedDateOr(Object? value, DateTime? fallback) {
  return parsePersistedDate(value) ?? fallback ?? DateTime.now();
}
