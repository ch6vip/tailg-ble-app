import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/pages/settings_page.dart';

import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';

void main() {
  setUp(() {
    resetMockPreferences();
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
      expectMinTouchTargetHeight(tester, find.byWidget(element.widget));
    }
  });

  testWidgets('settings switches expose labeled toggle semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(const TestApp(home: SettingsPage()));
      await tester.pump();

      const autoConnectLabel = '自动连接开关';
      final autoConnectSwitch = find.bySemanticsLabel(autoConnectLabel);
      expect(autoConnectSwitch, findsOneWidget);
      expect(
        tester.getSemantics(autoConnectSwitch),
        matchesSemantics(
          label: autoConnectLabel,
          hasEnabledState: true,
          isEnabled: true,
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );

      final autoEnabled = app.autoConnectService.enabledStream.firstWhere(
        (value) => value,
      );
      tester.semantics.tap(find.semantics.byLabel(autoConnectLabel));
      await autoEnabled;
      await tester.pump();

      expect(app.autoConnectService.enabled, isTrue);

      const proximityLabel = '感应解锁开关';
      final proximitySwitch = find.bySemanticsLabel(proximityLabel);
      expect(proximitySwitch, findsOneWidget);
      expect(
        tester.getSemantics(proximitySwitch),
        matchesSemantics(
          label: proximityLabel,
          hasEnabledState: true,
          isEnabled: true,
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );

      final proximityEnabled = app.proximityService.enabledStream.firstWhere(
        (value) => value,
      );
      tester.semantics.tap(find.semantics.byLabel(proximityLabel));
      await proximityEnabled;
      await tester.pump();

      expect(app.proximityService.enabled, isTrue);

      const textScaleLabel = '跟随系统字号开关';
      final textScaleSwitch = find.bySemanticsLabel(textScaleLabel);
      expect(textScaleSwitch, findsOneWidget);
      expect(
        tester.getSemantics(textScaleSwitch),
        matchesSemantics(
          label: textScaleLabel,
          hasEnabledState: true,
          isEnabled: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );

      final textScaleDisabled = app.appPreferencesService.respectTextScaleStream
          .firstWhere((value) => !value);
      tester.semantics.tap(find.semantics.byLabel(textScaleLabel));
      await textScaleDisabled;
      await tester.pump();

      expect(app.appPreferencesService.respectSystemTextScale, isFalse);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('settings navigation rows expose semantics and 44dp targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(const TestApp(home: SettingsPage()));
      await tester.pump();

      const languageLabel = '语言设置，跟随系统';
      final languageRow = find.bySemanticsLabel(languageLabel);
      expect(languageRow, findsOneWidget);
      expectMinTouchTargetHeight(tester, languageRow);
      expect(
        tester.getSemantics(languageRow),
        matchesSemantics(
          label: languageLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(languageLabel));
      await tester.pumpAndSettle();

      expect(find.text('语言设置'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
