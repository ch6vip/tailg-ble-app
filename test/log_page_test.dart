import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/pages/log_page.dart';

import 'helpers/snack_finders.dart';
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

  testWidgets('copy action shows info snack when logs are empty', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(home: LogPage()));

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();

    expect(find.text('当前没有可复制的日志'), findsOneWidget);
    expect(snackIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('new log entries refresh the visible list automatically', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(home: LogPage()));
    await tester.pump();

    expect(find.text('暂无日志'), findsOneWidget);

    app.logService.operation('测试操作');
    await tester.pump();
    await tester.pump();

    expect(find.text('测试操作'), findsOneWidget);
  });

  testWidgets('copy action exports logs and shows success snack', (
    tester,
  ) async {
    app.logService.operation('测试操作');

    await tester.pumpWidget(const TestApp(home: LogPage()));

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('已复制诊断报告（1 条日志）'), findsOneWidget);
    expect(snackIcon(Icons.check_circle_outline), findsOneWidget);
  });
}
