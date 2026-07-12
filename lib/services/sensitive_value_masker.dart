abstract final class SensitiveValueMasker {
  static String compact(
    String value, {
    String emptyValue = '***',
    bool trim = true,
  }) {
    final text = trim ? value.trim() : value;
    if (text.isEmpty) return emptyValue;
    if (text.length <= 6) return '***';
    return '${text.substring(0, 3)}***${text.substring(text.length - 3)}';
  }

  static String phone(
    String value, {
    int minMaskLength = 7,
    String? shortValue,
    bool trim = false,
  }) {
    final text = trim ? value.trim() : value;
    if (text.length < minMaskLength) return shortValue ?? text;
    return '${text.substring(0, 3)}****${text.substring(text.length - 4)}';
  }
}

abstract final class SensitiveTextRedactor {
  static final RegExp _authorizationValuePattern = RegExp(
    r'''(["']?\bauthorization\b["']?\s*[:=]\s*["']?)(?!Bearer\b)([^"'\s,&}]+)(["']?)''',
    caseSensitive: false,
  );
  static final RegExp _bearerTokenPattern = RegExp(
    r'\bBearer\s+([A-Za-z0-9._~+/=-]+)',
    caseSensitive: false,
  );
  static final RegExp _sensitiveKeyValuePattern = RegExp(
    r'''(["']?\b(?:phone|token|imei|carId|uid|userId|password|frame|btmac|mac)\b["']?\s*[:=]\s*["']?)([^"'\s,&}]+)(["']?)''',
    caseSensitive: false,
  );
  static final RegExp _phonePattern = RegExp(r'\b1\d{10}\b');
  static final RegExp _imeiPattern = RegExp(r'\b\d{14,17}\b');
  static final RegExp _macPattern = RegExp(
    r'\b(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b',
  );
  static final RegExp _compactMacPattern = RegExp(r'\b[0-9A-Fa-f]{12}\b');

  static String redact(String value) {
    return value
        .replaceAllMapped(_bearerTokenPattern, (match) {
          return 'Bearer ${_mask(match.group(1) ?? '')}';
        })
        .replaceAllMapped(_authorizationValuePattern, (match) {
          return '${match.group(1)}${_mask(match.group(2) ?? '')}${match.group(3)}';
        })
        .replaceAllMapped(_sensitiveKeyValuePattern, (match) {
          return '${match.group(1)}${_mask(match.group(2) ?? '')}${match.group(3)}';
        })
        .replaceAllMapped(_phonePattern, _maskMatch)
        .replaceAllMapped(_imeiPattern, _maskMatch)
        .replaceAllMapped(_macPattern, _maskMatch)
        .replaceAllMapped(_compactMacPattern, _maskMatch);
  }

  static String _mask(String value) => SensitiveValueMasker.compact(value);

  static String _maskMatch(Match match) => _mask(match.group(0) ?? '');
}
