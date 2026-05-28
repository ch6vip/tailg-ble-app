import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

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

  final _languageController =
      StreamController<AppLanguagePreference>.broadcast();
  final _distanceUnitController =
      StreamController<DistanceUnitPreference>.broadcast();

  AppLanguagePreference _language = AppLanguagePreference.system;
  DistanceUnitPreference _distanceUnit = DistanceUnitPreference.metric;
  bool _initialized = false;

  AppLanguagePreference get language => _language;
  DistanceUnitPreference get distanceUnit => _distanceUnit;
  Stream<AppLanguagePreference> get languageStream =>
      _languageController.stream;
  Stream<DistanceUnitPreference> get distanceUnitStream =>
      _distanceUnitController.stream;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _language = AppLanguagePreference.fromValue(prefs.getString(_prefLanguage));
    _distanceUnit = DistanceUnitPreference.fromValue(
      prefs.getString(_prefDistanceUnit),
    );
    _initialized = true;
    _emit();
  }

  Future<void> setLanguage(AppLanguagePreference preference) async {
    await init();
    _language = preference;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLanguage, preference.value);
    _emit();
  }

  Future<void> setDistanceUnit(DistanceUnitPreference preference) async {
    await init();
    _distanceUnit = preference;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefDistanceUnit, preference.value);
    _emit();
  }

  void _emit() {
    _languageController.add(_language);
    _distanceUnitController.add(_distanceUnit);
  }
}
