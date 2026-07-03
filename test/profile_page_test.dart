import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/pages/profile_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/snack_finders.dart';
import 'helpers/test_app.dart';

void main() {
  setUp(() {
    app.officialCloudService.resetForTest();
  });

  tearDown(() {
    app.officialCloudService.resetForTest();
  });

  testWidgets('membership entry shows info snack', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const TestApp(home: ProfilePage()));
      await tester.pump();

      const membershipLabel = '会员中心，即将上线';
      final membershipEntry = find.bySemanticsLabel(membershipLabel);
      expect(membershipEntry, findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('会员中心 · 即将上线'),
          matching: find.byType(AppPressable),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(membershipEntry),
        matchesSemantics(
          label: membershipLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(membershipLabel));
      await tester.pump();

      expect(find.text('会员中心功能开发中'), findsOneWidget);
      expect(snackIcon(Icons.info_outline), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('profile edit action keeps a 44dp touch target', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const TestApp(home: ProfilePage()));
      await tester.pump();

      final editAction = find.ancestor(
        of: find.byIcon(Icons.edit_outlined),
        matching: find.byType(GestureDetector),
      );
      expect(editAction, findsOneWidget);
      expect(tester.getSize(editAction).height, greaterThanOrEqualTo(44));

      const loginActionLabel = '登录官方账号';
      final loginAction = find.bySemanticsLabel(loginActionLabel);
      expect(loginAction, findsOneWidget);
      expect(
        tester.getSemantics(loginAction),
        matchesSemantics(
          label: loginActionLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('profile setting tiles expose semantics and 44dp targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      tester.view.physicalSize = const Size(430, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const TestApp(home: ProfilePage()));
      await tester.pump();

      const messageLabel = '消息通知';
      final messageTile = find.bySemanticsLabel(messageLabel);
      expect(messageTile, findsOneWidget);
      expect(tester.getSize(messageTile).height, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(messageTile),
        matchesSemantics(
          label: messageLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(messageLabel));
      await tester.pumpAndSettle();

      expect(find.text('消息中心'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('profile data metrics avoid negative letter spacing', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(home: ProfilePage()));
    await tester.pump();

    final metricTexts = tester
        .widgetList<Text>(find.text('--'))
        .map((text) => text.style?.letterSpacing)
        .toList();

    expect(metricTexts, hasLength(3));
    expect(metricTexts, everyElement(anyOf(isNull, greaterThanOrEqualTo(0))));
  });

  testWidgets('profile logout action exposes semantics and 44dp target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      tester.view.physicalSize = const Size(430, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const TestApp(home: ProfilePage()));
      await tester.pump();

      const logoutLabel = '退出登录';
      final logoutAction = find.bySemanticsLabel(logoutLabel);
      expect(logoutAction, findsOneWidget);
      expect(tester.getSize(logoutAction).height, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(logoutAction),
        matchesSemantics(
          label: logoutLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(logoutLabel));
      await tester.pumpAndSettle();

      expect(find.text('确定要退出当前账号吗？'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('profile header follows official cloud state stream', (
    tester,
  ) async {
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token-before-logout',
        phone: '18812345678',
        userId: 'user-before-logout',
      ),
    );

    await tester.pumpWidget(const TestApp(home: ProfilePage()));
    await tester.pump();

    expect(find.text('188****5678'), findsOneWidget);

    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(initialized: true),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('138****8888'), findsOneWidget);
    expect(find.text('188****5678'), findsNothing);
  });
}
