import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/pages/profile_page.dart';

import 'helpers/test_app.dart';

void main() {
  setUp(() {
    app.officialCloudService.resetForTest();
  });

  testWidgets('membership entry shows info snack', (tester) async {
    await tester.pumpWidget(const TestApp(home: ProfilePage()));
    await tester.pump();

    await tester.tap(find.text('会员中心 · 即将上线'));
    await tester.pump();

    expect(find.text('会员中心功能开发中'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byIcon(Icons.info_outline),
      ),
      findsOneWidget,
    );
  });
}
