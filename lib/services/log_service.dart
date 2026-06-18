import 'dart:collection';

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
        detail: detail,
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

  void _add(LogEntry entry) {
    _logs.addLast(entry);
    while (_logs.length > _maxEntries) {
      _logs.removeFirst();
      _evictedCount++;
    }
  }

  void clear() {
    _logs.clear();
    _evictedCount = 0;
  }
}
