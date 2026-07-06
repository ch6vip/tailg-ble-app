String parsePersistedString(Object? value) {
  return value?.toString().trim() ?? '';
}

String parsePersistedStringOr(Object? value, String fallback) {
  final parsed = parsePersistedString(value);
  return parsed.isEmpty ? fallback : parsed;
}

List<String> parsePersistedStringList(Object? value) {
  final strings = <String>[];
  for (final item in _persistedListItems(value)) {
    if (item is String) strings.add(item);
  }
  return strings;
}

Map<String, dynamic>? parsePersistedMap(Object? value) {
  if (value is! Map) return null;
  final parsed = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw FormatException('Persisted map keys must be strings', key);
    }
    parsed[key] = entry.value;
  }
  return parsed;
}

List<Map<String, dynamic>> parsePersistedMapList(Object? value) {
  final maps = <Map<String, dynamic>>[];
  for (final item in _persistedListItems(value)) {
    final parsed = parsePersistedMap(item);
    if (parsed != null) maps.add(parsed);
  }
  return maps.toList(growable: false);
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

DateTime parsePersistedDateOr(
  Object? value,
  DateTime? fallback, {
  DateTime Function()? clock,
}) {
  return parsePersistedDate(value) ?? fallback ?? (clock ?? DateTime.now)();
}
