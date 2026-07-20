/// Format [value] with [fractionDigits], then drop a trailing ".0" so labels
/// like mileage stay compact (`12.0` → `12`, `12.5` stays `12.5`).
String formatCompactDecimal(num value, {int fractionDigits = 1}) {
  final fixed = value.toStringAsFixed(fractionDigits);
  if (fractionDigits > 0 && fixed.endsWith('.0')) {
    return fixed.substring(0, fixed.length - 2);
  }
  return fixed;
}

/// Same as [formatCompactDecimal] for text payloads; returns [value] unchanged
/// when it is not numeric.
String formatCompactDecimalText(String value, {int fractionDigits = 1}) {
  final parsed = double.tryParse(value);
  if (parsed == null) return value;
  return formatCompactDecimal(parsed, fractionDigits: fractionDigits);
}

/// Human-readable distance label: meters below 1 km, compact km otherwise.
String formatDistanceMeters(double meters) {
  if (meters >= 1000) {
    return '${formatCompactDecimal(meters / 1000)}km';
  }
  return '${meters.toStringAsFixed(0)}m';
}

/// Official `deviceTravel` mileage / totalMileage payloads are **meters**
/// (`ViewAdapter.setHisListItemMilage` / `setMilage` / `setTextViewSetMilageValue`).
///
/// Matches official parsing: take the integer part before `.`, then convert.
double parseTravelMileageMeters(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return 0;
  final head = text.split('.').first.trim();
  final match = RegExp(r'-?\d+').firstMatch(head);
  if (match != null) {
    return double.tryParse(match.group(0)!)?.abs() ?? 0;
  }
  return double.tryParse(text)?.abs() ?? 0;
}

/// Meters → kilometers (official always divides travel mileage by 1000).
double travelMetersToKm(num meters) => meters.toDouble() / 1000.0;

/// Format travel mileage like official list/detail adapters.
///
/// - [alwaysKm] false (list): `<1000m` → `500m`, else `57.29km`
/// - [alwaysKm] true (ride-stats style): always km with down-rounded decimals
String formatTravelMileageMeters(num meters, {bool alwaysKm = false}) {
  final value = meters.toDouble();
  if (value.isNaN || value.isInfinite) return '--';
  final intMeters = value.abs().truncate();
  if (!alwaysKm && intMeters < 1000) {
    return '${intMeters}m';
  }
  return '${formatDecimalDown(intMeters / 1000.0, fractionDigits: 2)}km';
}

/// Parse a travel mileage **text payload (meters)** and format for display.
String formatTravelMileageMetersText(String? raw, {bool alwaysKm = false}) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return '';
  return formatTravelMileageMeters(
    parseTravelMileageMeters(text),
    alwaysKm: alwaysKm,
  );
}

/// Decimal format with [RoundingMode.DOWN] semantics (truncate toward zero),
/// then strip trailing zeros / dot for compact UI labels.
String formatDecimalDown(num value, {int fractionDigits = 2}) {
  if (fractionDigits <= 0) {
    return value.truncate().toString();
  }
  var factor = 1;
  for (var i = 0; i < fractionDigits; i++) {
    factor *= 10;
  }
  final scaled = value.toDouble() * factor;
  final truncated = value.toDouble().isNegative
      ? scaled.ceilToDouble()
      : scaled.floorToDouble();
  final fixed = (truncated / factor).toStringAsFixed(fractionDigits);
  if (!fixed.contains('.')) return fixed;
  var trimmed = fixed;
  while (trimmed.contains('.') && trimmed.endsWith('0')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  if (trimmed.endsWith('.')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}
