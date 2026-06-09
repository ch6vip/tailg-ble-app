import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/services/manual_mode_service.dart';

void main() {
  setUp(() {
    ManualModeService().resetForTest();
    SharedPreferences.setMockInitialValues({});
  });

  test('ManualModeService defaults to off and persists toggles', () async {
    final service = ManualModeService();
    await service.init();
    expect(service.enabled, isFalse);

    final events = <bool>[];
    final sub = service.enabledStream.listen(events.add);

    await service.setEnabled(true);
    expect(service.enabled, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('manual_mode_enabled'), isTrue);

    // Re-reading from storage restores the persisted value.
    await service.init();
    expect(service.enabled, isTrue);

    await service.setEnabled(false);
    expect(service.enabled, isFalse);

    await sub.cancel();
    expect(events, contains(true));
    expect(events, contains(false));
  });

  test('ManualModeService coalesces concurrent init calls', () async {
    SharedPreferences.setMockInitialValues({'manual_mode_enabled': true});
    ManualModeService().resetForTest();

    final service = ManualModeService();
    await Future.wait([service.init(), service.init()]);

    expect(service.enabled, isTrue);
  });
}
