import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/pages/cloud_token_page.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('saving token persists value and shows success snack', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TestApp(home: CloudTokenPage()));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'shared-token');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cloud_token'), 'shared-token');
    expect(find.text('Token 已保存'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });
}
