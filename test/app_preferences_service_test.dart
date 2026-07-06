import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/services/app_preferences_service.dart';

import 'helpers/storage_mocks.dart';

void main() {
  setUp(() {
    AppPreferencesService().resetForTest();
    resetMockPreferences();
  });

  test('loads persisted app preferences before UI reads them', () async {
    SharedPreferences.setMockInitialValues(
      _storedAppPreferences(
        language: 'en',
        distanceUnit: 'imperial',
        respectTextScale: false,
      ),
    );
    AppPreferencesService().resetForTest();

    final service = AppPreferencesService();
    await service.init();

    expect(service.language, AppLanguagePreference.english);
    expect(service.distanceUnit, DistanceUnitPreference.imperial);
    expect(service.respectSystemTextScale, isFalse);
  });

  test('coalesces concurrent init calls and preserves loaded values', () async {
    SharedPreferences.setMockInitialValues(
      _storedAppPreferences(
        language: 'zh-Hans',
        distanceUnit: 'metric',
        respectTextScale: true,
      ),
    );
    AppPreferencesService().resetForTest();

    final service = AppPreferencesService();
    await Future.wait([service.init(), service.init()]);

    expect(service.language, AppLanguagePreference.simplifiedChinese);
    expect(service.distanceUnit, DistanceUnitPreference.metric);
    expect(service.respectSystemTextScale, isTrue);
  });

  test('falls back to safe defaults for unknown preference values', () async {
    SharedPreferences.setMockInitialValues(
      _storedAppPreferences(language: 'unknown', distanceUnit: 'unknown'),
    );
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

  test('resetForTest restores streams after dispose', () async {
    final service = AppPreferencesService();

    service.dispose();
    service.resetForTest();
    await service.init();

    final languageEvent = service.languageStream.first;
    await service.setLanguage(AppLanguagePreference.english);
    await expectLater(languageEvent, completion(AppLanguagePreference.english));

    final distanceUnitEvent = service.distanceUnitStream.first;
    await service.setDistanceUnit(DistanceUnitPreference.imperial);
    await expectLater(
      distanceUnitEvent,
      completion(DistanceUnitPreference.imperial),
    );

    final textScaleEvent = service.respectTextScaleStream.first;
    await service.setRespectSystemTextScale(false);
    await expectLater(textScaleEvent, completion(isFalse));
  });
}

Map<String, Object> _storedAppPreferences({
  required String language,
  required String distanceUnit,
  bool? respectTextScale,
}) {
  return {
    'app_language_preference': language,
    'app_distance_unit_preference': distanceUnit,
    if (respectTextScale != null) 'app_respect_text_scale': respectTextScale,
  };
}
