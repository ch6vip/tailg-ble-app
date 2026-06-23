import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    await tester.pumpWidget(const TailgBleApp());
    await tester.pump(); // Allow combined stream initial emission
    expect(find.text('未绑定车辆'), findsOneWidget);
    expect(find.text('控车'), findsOneWidget);
    expect(find.text('定位'), findsOneWidget);
    expect(find.text('车库'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('Unbound home stays stable on a narrow surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const TailgBleApp());
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('未绑定车辆'), findsOneWidget);
    expect(find.text('绑定设备'), findsOneWidget);
  });
}
