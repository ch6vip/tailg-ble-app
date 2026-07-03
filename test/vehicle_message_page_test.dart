import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/pages/vehicle_message_page.dart';

import 'helpers/snack_finders.dart';
import 'helpers/test_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    app.logService.clear();
  });

  tearDown(app.logService.clear);

  testWidgets('new log entries refresh visible messages automatically', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(home: VehicleMessagePage()));
    await tester.pump();

    expect(find.text('暂无消息'), findsOneWidget);

    app.logService.operation('发送指令');
    await tester.pump();
    await tester.pump();

    expect(find.text('发送指令'), findsOneWidget);
  });

  testWidgets('clearing current message group shows success snack', (
    tester,
  ) async {
    app.logService.operation('发送指令');

    await tester.pumpWidget(const TestApp(home: VehicleMessagePage()));
    await tester.pump();

    expect(find.text('发送指令'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('已清空 1 条当前分组消息'), findsOneWidget);
    expect(snackIcon(Icons.check_circle_outline), findsOneWidget);
  });
}
