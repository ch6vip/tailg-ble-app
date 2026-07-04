import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/pages/app_preferences_pages.dart';

import 'helpers/platform_mocks.dart';
import 'helpers/snack_finders.dart';
import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';

void main() {
  setUp(() {
    resetMockPreferences();
    app.appPreferencesService.resetForTest();
    app.logService.clear();
    mockClipboardWrites();
  });

  tearDown(() {
    resetMockPreferences();
    app.appPreferencesService.resetForTest();
    app.logService.clear();
    clearPlatformChannelMock();
  });

  testWidgets('copying diagnostic report shows success snack', (tester) async {
    await tester.pumpWidget(const TestApp(home: AboutAppPage()));

    await tester.tap(find.text('服务诊断'));
    await tester.pump();

    expect(find.text('已复制诊断报告'), findsOneWidget);
    expect(snackIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('about action rows expose semantics and 44dp targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const copyLabel = '服务诊断，复制信息用于客服排查问题';

    try {
      await tester.pumpWidget(const TestApp(home: AboutAppPage()));

      final copyAction = find.bySemanticsLabel(copyLabel);
      expect(copyAction, findsOneWidget);
      expectMinTouchTargetHeight(tester, copyAction);
      expect(
        tester.getSemantics(copyAction),
        matchesSemantics(
          label: copyLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(copyLabel));
      await tester.pump();

      expect(find.text('已复制诊断报告'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('language options expose selected semantics and 44dp targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(const TestApp(home: LanguageSettingsPage()));
      await tester.pump();

      final systemOption = find.bySemanticsLabel('跟随系统');
      expect(systemOption, findsOneWidget);
      expectMinTouchTargetHeight(tester, systemOption);
      expect(
        tester.getSemantics(systemOption),
        matchesSemantics(
          label: '跟随系统',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.bySemanticsLabel('English'));
      await tester.pump();

      expect(
        tester.getSemantics(find.bySemanticsLabel('English')),
        matchesSemantics(
          label: 'English',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });
}
