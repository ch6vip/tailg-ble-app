import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'log_service.dart';

enum AppLanguagePreference {
  system('system', '跟随系统'),
  simplifiedChinese('zh-Hans', '简体中文'),
  english('en', 'English');

  final String value;
  final String label;
  const AppLanguagePreference(this.value, this.label);

  static AppLanguagePreference fromValue(String? value) {
    return AppLanguagePreference.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AppLanguagePreference.system,
    );
  }
}

enum DistanceUnitPreference {
  metric('metric', '公制', 'km / m'),
  imperial('imperial', '英制', 'mi / ft');

  final String value;
  final String label;
  final String hint;
  const DistanceUnitPreference(this.value, this.label, this.hint);

  static DistanceUnitPreference fromValue(String? value) {
    return DistanceUnitPreference.values.firstWhere(
      (item) => item.value == value,
      orElse: () => DistanceUnitPreference.metric,
    );
  }
}

class AppPreferencesService {
  static final AppPreferencesService _instance = AppPreferencesService._();
  factory AppPreferencesService() => _instance;
  AppPreferencesService._();

  static const _prefLanguage = 'app_language_preference';
  static const _prefDistanceUnit = 'app_distance_unit_preference';
  static const _prefRespectTextScale = 'app_respect_text_scale';

  final _languageController =
      StreamController<AppLanguagePreference>.broadcast();
  final _distanceUnitController =
      StreamController<DistanceUnitPreference>.broadcast();
  final _respectTextScaleController = StreamController<bool>.broadcast();

  AppLanguagePreference _language = AppLanguagePreference.system;
  DistanceUnitPreference _distanceUnit = DistanceUnitPreference.metric;
  bool _respectTextScale = true;
  bool _initialized = false;
  Future<void>? _initializing;

  AppLanguagePreference get language => _language;
  DistanceUnitPreference get distanceUnit => _distanceUnit;
  bool get respectSystemTextScale => _respectTextScale;
  Stream<AppLanguagePreference> get languageStream =>
      _languageController.stream;
  Stream<DistanceUnitPreference> get distanceUnitStream =>
      _distanceUnitController.stream;
  Stream<bool> get respectTextScaleStream => _respectTextScaleController.stream;

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
      _language = AppLanguagePreference.fromValue(
        prefs.getString(_prefLanguage),
      );
      _distanceUnit = DistanceUnitPreference.fromValue(
        prefs.getString(_prefDistanceUnit),
      );
      _respectTextScale = prefs.getBool(_prefRespectTextScale) ?? true;
      _initialized = true;
      _emit();
    } finally {
      _initializing = null;
    }
  }

  void resetForTest() {
    _language = AppLanguagePreference.system;
    _distanceUnit = DistanceUnitPreference.metric;
    _respectTextScale = true;
    _initialized = false;
    _initializing = null;
  }

  Future<void> setLanguage(AppLanguagePreference preference) async {
    await init();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLanguage, preference.value);
      _language = preference;
      _emit();
    } catch (e) {
      // Persistence failed — do not update in-memory state
      LogService().operation('setLanguage failed', detail: '$e');
    }
  }

  Future<void> setDistanceUnit(DistanceUnitPreference preference) async {
    await init();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefDistanceUnit, preference.value);
      _distanceUnit = preference;
      _emit();
    } catch (e) {
      // Persistence failed — do not update in-memory state
      LogService().operation('setDistanceUnit failed', detail: '$e');
    }
  }

  Future<void> setRespectSystemTextScale(bool value) async {
    await init();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefRespectTextScale, value);
      _respectTextScale = value;
      _emitRespectTextScale();
    } catch (e) {
      // Persistence failed — do not update in-memory state
      LogService().operation('setRespectSystemTextScale failed', detail: '$e');
    }
  }

  void _emit() {
    if (!_languageController.isClosed) _languageController.add(_language);
    if (!_distanceUnitController.isClosed) {
      _distanceUnitController.add(_distanceUnit);
    }
    _emitRespectTextScale();
  }

  void _emitRespectTextScale() {
    if (!_respectTextScaleController.isClosed) {
      _respectTextScaleController.add(_respectTextScale);
    }
  }

  void dispose() {
    _languageController.close();
    _distanceUnitController.close();
    _respectTextScaleController.close();
  }
}
