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
  bool get enabled => _enabled;

  final _enabledController = StreamController<bool>.broadcast();
  Stream<bool> get enabledStream => _enabledController.stream;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? false;
    _enabledController.add(_enabled);
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
