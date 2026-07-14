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
