import 'dart:collection';
import 'dart:async';

import 'sensitive_value_masker.dart';

enum LogLevel { debug, info, warning, error }

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
  final _controller = StreamController<void>.broadcast();
  Stream<void> get changes => _controller.stream;

  List<LogEntry> get all => _logs.toList();
  int get evictedCount => _evictedCount;

  List<LogEntry> byCategory(LogCategory cat) =>
      _logs.where((e) => e.category == cat).toList();

  void resetForTest({DateTime Function()? clock}) {
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

  /// Redacts sensitive BLE login payloads before they hit the in-memory log
  /// ring buffer (P2-4). Previously the raw QGJ login frame — which carries
  /// password/userId — was logged verbatim and could be exported/shared.
  static final RegExp _qgjLoginHint = RegExp(
    r'(登录|login|QGJ 登录)',
    caseSensitive: false,
  );
  static final RegExp _sensitiveKeyValuePattern = RegExp(
    r'''(["']?\b(?:phone|token|imei|carId|uid|btmac)\b["']?\s*[:=]\s*["']?)([^"'\s,&}]+)(["']?)''',
    caseSensitive: false,
  );
  static final RegExp _authorizationValuePattern = RegExp(
    r'''(["']?\bauthorization\b["']?\s*[:=]\s*["']?)(?!Bearer\b)([^"'\s,&}]+)(["']?)''',
    caseSensitive: false,
  );
  static final RegExp _bearerTokenPattern = RegExp(
    r'\bBearer\s+([A-Za-z0-9._~+/=-]+)',
    caseSensitive: false,
  );
  static final RegExp _phonePattern = RegExp(r'\b1\d{10}\b');
  static final RegExp _imeiPattern = RegExp(r'\b\d{14,17}\b');

  String? _redactDetail(String message, String? detail) {
    if (detail == null) return null;
    if (!_qgjLoginHint.hasMatch(message)) return _redactSensitiveText(detail);
    // Replace hex payloads containing login frames with a length summary so
    // troubleshooting can still see "frame sent, N bytes" without leaking
    // credentials.
    final hexByteCount = detail.split(' ').where((s) => s.isNotEmpty).length;
    return '<redacted login frame, $hexByteCount bytes>';
  }

  String _redactSensitiveText(String value) {
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
        .replaceAllMapped(_imeiPattern, _maskMatch);
  }

  String _mask(String value) {
    return SensitiveValueMasker.compact(value);
  }

  String _maskMatch(Match match) {
    return _mask(match.group(0) ?? '');
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
    _controller.close();
  }
}
