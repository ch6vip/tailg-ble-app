import 'dart:collection';
import 'dart:async';

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

  static const _maxEntries = 500;
  final _logs = Queue<LogEntry>();
  int _evictedCount = 0;

  // Broadcast stream so UI pages can subscribe and rebuild on new entries
  // instead of polling with empty setState(() {}) (P3-12).
  final _controller = StreamController<void>.broadcast();
  Stream<void> get changes => _controller.stream;

  List<LogEntry> get all => _logs.toList();
  int get evictedCount => _evictedCount;

  List<LogEntry> byCategory(LogCategory cat) =>
      _logs.where((e) => e.category == cat).toList();

  void ble(String message, {String? detail, LogLevel level = LogLevel.debug}) {
    _add(
      LogEntry(
        time: DateTime.now(),
        level: level,
        category: LogCategory.ble,
        message: message,
        detail: _redactDetail(message, detail),
      ),
    );
  }

  void operation(
    String message, {
    String? detail,
    LogLevel level = LogLevel.info,
  }) {
    _add(
      LogEntry(
        time: DateTime.now(),
        level: level,
        category: LogCategory.operation,
        message: message,
        detail: detail,
      ),
    );
  }

  /// Redacts sensitive BLE login payloads before they hit the in-memory log
  /// ring buffer (P2-9). Previously the raw QGJ login frame — which carries
  /// password/userId — was logged verbatim and could be exported/shared.
  static final RegExp _qgjLoginHint = RegExp(
    r'(登录|login|QGJ 登录)',
    caseSensitive: false,
  );

  String? _redactDetail(String message, String? detail) {
    if (detail == null) return null;
    if (!_qgjLoginHint.hasMatch(message)) return detail;
    // Replace hex payloads containing login frames with a length summary so
    // troubleshooting can still see "frame sent, N bytes" without leaking
    // credentials.
    final hexByteCount = detail.split(' ').where((s) => s.isNotEmpty).length;
    return '<redacted login frame, $hexByteCount bytes>';
  }

  void _add(LogEntry entry) {
    _logs.addLast(entry);
    while (_logs.length > _maxEntries) {
      _logs.removeFirst();
      _evictedCount++;
    }
    if (_controller.hasListener) {
      _controller.add(null);
    }
  }

  void clear() {
    _logs.clear();
    _evictedCount = 0;
    if (_controller.hasListener) {
      _controller.add(null);
    }
  }

  void dispose() {
    _controller.close();
  }
}
