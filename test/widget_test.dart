import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart';

import 'helpers/view_size.dart';

void main() {
  setUp(() {
    homeTabIndex.value = 1;
  });

  testWidgets('App renders home page', (WidgetTester tester) async {
    await tester.pumpWidget(const TailgBleApp());
    await tester.pump(); // Allow combined stream initial emission
    expect(find.text('未绑定车辆'), findsOneWidget);
    expect(find.text('爱车'), findsOneWidget);
    expect(find.text('服务'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('消息'), findsNothing);
    expect(find.text('车库'), findsNothing);
  });

  testWidgets('Bottom nav keeps vehicle in the center', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TailgBleApp());
    await tester.pump();

    final navBar = find.byType(BottomNavigationBar);
    expect(navBar, findsNothing);

    final serviceCenter = tester.getCenter(find.text('服务'));
    final vehicleCenter = tester.getCenter(find.text('爱车'));
    final mineCenter = tester.getCenter(find.text('我的'));

    expect(serviceCenter.dx, lessThan(vehicleCenter.dx));
    expect(vehicleCenter.dx, lessThan(mineCenter.dx));
  });

  testWidgets('Bottom nav uses uniform compact bar geometry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TailgBleApp());
    await tester.pump();

    final barFinder = find.byKey(const ValueKey('official-bottom-nav-bar'));
    final serviceItemFinder = find.byKey(
      const ValueKey('official-bottom-nav-item-service'),
    );
    final vehicleItemFinder = find.byKey(
      const ValueKey('official-bottom-nav-item-vehicle'),
    );
    final mineItemFinder = find.byKey(
      const ValueKey('official-bottom-nav-item-mine'),
    );

    expect(barFinder, findsOneWidget);
    expect(serviceItemFinder, findsOneWidget);
    expect(vehicleItemFinder, findsOneWidget);
    expect(mineItemFinder, findsOneWidget);

    // White bar is 65; system inset is 0 in tests so bar height is 65.
    // All three tabs share the same slot height (no raised center icon).
    expect(tester.getSize(barFinder).height, 65);
    expect(tester.getSize(serviceItemFinder).height, 65);
    expect(tester.getSize(vehicleItemFinder).height, 65);
    expect(tester.getSize(mineItemFinder).height, 65);

    final barTop = tester.getTopLeft(barFinder).dy;
    final serviceTop = tester.getTopLeft(serviceItemFinder).dy;
    final vehicleTop = tester.getTopLeft(vehicleItemFinder).dy;
    final mineTop = tester.getTopLeft(mineItemFinder).dy;
    expect(serviceTop, closeTo(barTop, 0.5));
    expect(vehicleTop, closeTo(barTop, 0.5));
    expect(mineTop, closeTo(barTop, 0.5));

    // Labels share the same baseline.
    final serviceBottom = tester.getBottomLeft(find.text('服务')).dy;
    final vehicleBottom = tester.getBottomLeft(find.text('爱车')).dy;
    final mineBottom = tester.getBottomLeft(find.text('我的')).dy;
    expect(serviceBottom, closeTo(vehicleBottom, 1.0));
    expect(mineBottom, closeTo(vehicleBottom, 1.0));
  });

  testWidgets('Service tab opens aggregate service hub', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TailgBleApp());
    await tester.pump();

    await tester.tap(find.text('服务'));
    await tester.pumpAndSettle();

    expect(find.text('服务中心'), findsOneWidget);
    for (final label in ['车辆定位', '历史轨迹', '电子围栏', 'NFC钥匙', '车辆设置', '电池服务']) {
      expect(find.text(label), findsOneWidget);
    }
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
