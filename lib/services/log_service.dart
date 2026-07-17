import 'dart:collection';
import 'dart:async';

import 'sensitive_value_masker.dart';

enum LogLevel { debug, info, warning, error }

/// Log categories for cloud operations and local BLE connection activity.
enum LogCategory { ble, operation }

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final LogCategory category;
  final String message;
  final String? detail;

  const LogEntry({
    required this.time,
    required this.level,
    required this.category,
    required this.message,
    this.detail,
  });
}

class LogService {
  static final LogService _instance = LogService._();
  factory LogService() => _instance;
  LogService._();

  static const _maxEntries = 2000;
  final _logs = Queue<LogEntry>();
  int _evictedCount = 0;
  DateTime Function() _clock = DateTime.now;

  // Broadcast stream so UI pages can subscribe and rebuild on new entries
  // instead of polling with empty setState(() {}) (P3-12).
  StreamController<void> _controller = StreamController<void>.broadcast();
  Stream<void> get changes => _controller.stream;

  List<LogEntry> get all => _snapshot();
  int get evictedCount => _evictedCount;

  List<LogEntry> byCategory(LogCategory cat) {
    return _snapshot(category: cat);
  }

  List<LogEntry> _snapshot({LogCategory? category}) {
    final entries = <LogEntry>[];
    for (final entry in _logs) {
      if (category != null && entry.category != category) continue;
      entries.add(entry);
    }
    return entries;
  }

  void resetForTest({DateTime Function()? clock}) {
    if (_controller.isClosed) {
      _controller = StreamController<void>.broadcast();
    }
    clear();
    _clock = clock ?? DateTime.now;
  }

  void ble(
    String message, {
    String? detail,
    LogLevel level = LogLevel.debug,
    DateTime? time,
  }) {
    _add(
      _redactedEntry(
        LogCategory.ble,
        message,
        detail: detail,
        level: level,
        time: time,
      ),
    );
  }

  void operation(
    String message, {
    String? detail,
    LogLevel level = LogLevel.info,
    DateTime? time,
  }) {
    _add(
      _redactedEntry(
        LogCategory.operation,
        message,
        detail: detail,
        level: level,
        time: time,
      ),
    );
  }

  LogEntry _redactedEntry(
    LogCategory category,
    String message, {
    String? detail,
    required LogLevel level,
    DateTime? time,
  }) {
    final redactedMessage = _redactSensitiveText(message);
    return LogEntry(
      time: time ?? _clock(),
      level: level,
      category: category,
      message: redactedMessage,
      detail: _redactDetail(message, detail),
    );
  }

  /// Redacts sensitive login payloads before they hit the in-memory log
  /// ring buffer (P2-4).
  static final RegExp _loginHint = RegExp(r'(登录|login)', caseSensitive: false);
  String? _redactDetail(String message, String? detail) {
    if (detail == null) return null;
    if (!_loginHint.hasMatch(message)) return _redactSensitiveText(detail);
    // Replace hex payloads containing login frames with a length summary so
    // troubleshooting can still see "frame sent, N bytes" without leaking
    // credentials.
    final hexByteCount = detail.split(' ').where((s) => s.isNotEmpty).length;
    return '<redacted login frame, $hexByteCount bytes>';
  }

  String _redactSensitiveText(String value) {
    return SensitiveTextRedactor.redact(value);
  }

  void _add(LogEntry entry) {
    _logs.addLast(entry);
    while (_logs.length > _maxEntries) {
      _logs.removeFirst();
      _evictedCount++;
    }
    if (_controller.hasListener && !_controller.isClosed) {
      _controller.add(null);
    }
  }

  void clear() {
    _logs.clear();
    _evictedCount = 0;
    if (_controller.hasListener && !_controller.isClosed) {
      _controller.add(null);
    }
  }

  void dispose() {
    if (!_controller.isClosed) {
      unawaited(_controller.close());
    }
  }
}
