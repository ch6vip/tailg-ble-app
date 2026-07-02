import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/pages/app_preferences_pages.dart';

import 'helpers/test_app.dart';

void main() {
  setUp(() {
    app.logService.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') return null;
          return null;
        });
  });

  tearDown(() {
    app.logService.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('copying diagnostic report shows success snack', (tester) async {
    await tester.pumpWidget(const TestApp(home: AboutAppPage()));

    await tester.tap(find.text('复制诊断报告'));
    await tester.pump();

    expect(find.text('已复制诊断报告'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });
}
