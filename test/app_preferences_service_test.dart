import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/services/app_preferences_service.dart';

void main() {
  setUp(() {
    AppPreferencesService().resetForTest();
    SharedPreferences.setMockInitialValues({});
  });

  test('loads persisted app preferences before UI reads them', () async {
    SharedPreferences.setMockInitialValues({
      'app_language_preference': 'en',
      'app_distance_unit_preference': 'imperial',
      'app_respect_text_scale': false,
    });
    AppPreferencesService().resetForTest();

    final service = AppPreferencesService();
    await service.init();

    expect(service.language, AppLanguagePreference.english);
    expect(service.distanceUnit, DistanceUnitPreference.imperial);
    expect(service.respectSystemTextScale, isFalse);
  });

  test('coalesces concurrent init calls and preserves loaded values', () async {
    SharedPreferences.setMockInitialValues({
      'app_language_preference': 'zh-Hans',
      'app_distance_unit_preference': 'metric',
      'app_respect_text_scale': true,
    });
    AppPreferencesService().resetForTest();

    final service = AppPreferencesService();
    await Future.wait([service.init(), service.init()]);

    expect(service.language, AppLanguagePreference.simplifiedChinese);
    expect(service.distanceUnit, DistanceUnitPreference.metric);
    expect(service.respectSystemTextScale, isTrue);
  });

  test('falls back to safe defaults for unknown preference values', () async {
    SharedPreferences.setMockInitialValues({
      'app_language_preference': 'unknown',
      'app_distance_unit_preference': 'unknown',
    });
    AppPreferencesService().resetForTest();

    final service = AppPreferencesService();
    await service.init();

    expect(service.language, AppLanguagePreference.system);
    expect(service.distanceUnit, DistanceUnitPreference.metric);
    expect(service.respectSystemTextScale, isTrue);
  });

  test('persists preference updates after initialization', () async {
    final service = AppPreferencesService();
    await service.init();

    await service.setLanguage(AppLanguagePreference.english);
    await service.setDistanceUnit(DistanceUnitPreference.imperial);
    await service.setRespectSystemTextScale(false);

    final prefs = await SharedPreferences.getInstance();
    expect(service.language, AppLanguagePreference.english);
    expect(service.distanceUnit, DistanceUnitPreference.imperial);
    expect(service.respectSystemTextScale, isFalse);
    expect(prefs.getString('app_language_preference'), 'en');
    expect(prefs.getString('app_distance_unit_preference'), 'imperial');
    expect(prefs.getBool('app_respect_text_scale'), isFalse);
  });
}
