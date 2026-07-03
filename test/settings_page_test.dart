import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/pages/settings_page.dart';

import 'helpers/test_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    app.autoConnectService.resetForTest();
    app.proximityService.resetForTest();
    app.appPreferencesService.resetForTest();
  });

  tearDown(() {
    app.autoConnectService.resetForTest();
    app.proximityService.resetForTest();
    app.appPreferencesService.resetForTest();
  });

  testWidgets('settings switches keep 44dp touch targets', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const TestApp(home: SettingsPage()));
    await tester.pump();

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(3));
    for (final element in switches.evaluate()) {
      expect(
        tester.getSize(find.byWidget(element.widget)).height,
        greaterThanOrEqualTo(44),
      );
    }
  });
}
