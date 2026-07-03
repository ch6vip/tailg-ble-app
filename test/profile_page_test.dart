import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/pages/profile_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

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
