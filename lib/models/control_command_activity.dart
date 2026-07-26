import 'command_types.dart';

enum ControlCommandActivityStatus { pending, succeeded, failed, cancelled }

class ControlCommandActivity {
  const ControlCommandActivity({
    required this.id,
    required this.command,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final int id;
  final CommandCode command;
  final String title;
  final String subtitle;
  final ControlCommandActivityStatus status;

  ControlCommandActivity copyWith({
    String? title,
    String? subtitle,
    ControlCommandActivityStatus? status,
  }) {
    return ControlCommandActivity(
      id: id,
      command: command,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      status: status ?? this.status,
    );
  }
}

/// Keeps one row per command and replaces its pending state with a terminal one.
class ControlCommandActivityLog {
  ControlCommandActivityLog({this.maxEntries = 4})
    : assert(maxEntries > 0, 'maxEntries must be positive');

  final int maxEntries;
  final List<ControlCommandActivity> _entries = [];
  int _nextId = 1;

  List<ControlCommandActivity> get entries => List.unmodifiable(_entries);

  int start({
    required CommandCode command,
    required String title,
    required String subtitle,
  }) {
    final id = _nextId++;
    _entries.insert(
      0,
      ControlCommandActivity(
        id: id,
        command: command,
        title: title,
        subtitle: subtitle,
        status: ControlCommandActivityStatus.pending,
      ),
    );
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    return id;
  }

  bool finish({
    required int id,
    required String title,
    required String subtitle,
    required ControlCommandActivityStatus status,
  }) {
    assert(
      status != ControlCommandActivityStatus.pending,
      'finish requires a terminal status',
    );
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index < 0) return false;
    _entries[index] = _entries[index].copyWith(
      title: title,
      subtitle: subtitle,
      status: status,
    );
    return true;
  }
}
