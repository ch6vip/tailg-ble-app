import 'package:flutter/services.dart';

/// Read plain text from the system clipboard.
///
/// Returns null when the clipboard has no text payload. When [trim] is true
/// (default), empty-after-trim values also become null so callers can treat
/// "missing" and "blank" the same.
Future<String?> readClipboardText({bool trim = true}) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text;
  if (text == null) return null;
  final value = trim ? text.trim() : text;
  if (trim && value.isEmpty) return null;
  return value;
}

/// Write plain text to the system clipboard.
Future<void> writeClipboardText(String text) {
  return Clipboard.setData(ClipboardData(text: text));
}
