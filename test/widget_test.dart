import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart';

import 'helpers/view_size.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    await tester.pumpWidget(const TailgBleApp());
    await tester.pump(); // Allow combined stream initial emission
    expect(find.text('未绑定车辆'), findsOneWidget);
    expect(find.text('消息'), findsOneWidget);
    expect(find.text('车库'), findsOneWidget);
    expect(find.text('爱车'), findsOneWidget);
    expect(find.text('服务'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('Message nav opens message center', (WidgetTester tester) async {
    await tester.pumpWidget(const TailgBleApp());
    await tester.pump();

    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();

    expect(find.text('消息中心'), findsOneWidget);
  });

  testWidgets('Unbound home stays stable on a narrow surface', (
    WidgetTester tester,
  ) async {
    setTestViewSize(tester, const Size(320, 1800));

    await tester.pumpWidget(const TailgBleApp());
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('未绑定车辆'), findsOneWidget);
    expect(find.text('绑定设备'), findsOneWidget);
  });
}
