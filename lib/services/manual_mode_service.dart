import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Tracks the user-facing "手动模式" (manual mode) switch on the control page.
///
/// When enabled, the app must not perform any automatic vehicle actions:
/// proximity unlock and auto-connect both consult [enabled] before scanning,
/// so the toggle's promise ("禁用自动控车") is actually honoured. The flag is
/// persisted so it survives app restarts.
class ManualModeService {
  static final ManualModeService _instance = ManualModeService._();
  factory ManualModeService() => _instance;
  ManualModeService._();

  static const _prefKey = 'manual_mode_enabled';

  bool _enabled = false;
  bool _initialized = false;
  Future<void>? _initializing;
  bool get enabled => _enabled;

  final _enabledController = StreamController<bool>.broadcast();
  Stream<bool> get enabledStream => _enabledController.stream;

  Future<void> init() async {
    if (_initialized) return;
    final initializing = _initializing;
    if (initializing != null) return initializing;
    _initializing = _load();
    return _initializing!;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      _enabled = prefs.getBool(_prefKey) ?? false;
      _initialized = true;
      _enabledController.add(_enabled);
    } finally {
      _initializing = null;
    }
  }

  void resetForTest() {
    _enabled = false;
    _initialized = false;
    _initializing = null;
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    _enabledController.add(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  void dispose() {
    _enabledController.close();
  }
}
