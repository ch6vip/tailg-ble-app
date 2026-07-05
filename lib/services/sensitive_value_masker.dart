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
