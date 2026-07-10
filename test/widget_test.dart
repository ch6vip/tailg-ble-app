import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart';

import 'helpers/source_scan.dart';
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

  testWidgets('Bottom nav uses official compact bar geometry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TailgBleApp());
    await tester.pump();

    final barFinder = find.byKey(const ValueKey('official-bottom-nav-bar'));
    final vehicleItemFinder = find.byKey(
      const ValueKey('official-bottom-nav-item-vehicle'),
    );

    expect(barFinder, findsOneWidget);
    expect(vehicleItemFinder, findsOneWidget);
    expect(tester.getSize(barFinder).height, 65);
    expect(tester.getSize(vehicleItemFinder).height, 80);

    final barTop = tester.getTopLeft(barFinder).dy;
    final vehicleTop = tester.getTopLeft(vehicleItemFinder).dy;
    expect(vehicleTop, closeTo(barTop - 15, 0.1));
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

  test('HomePage stream callbacks ignore events after unmount', () {
    final source = readSource('lib/pages/control_page_home_overview.dart');
    final manualModeListener = _listenerBlock(
      source,
      'manualModeService.enabledStream.listen',
    );

    expect(manualModeListener, contains('if (mounted)'));
  });
}

String _listenerBlock(String source, String listenerStart) {
  final start = source.indexOf(listenerStart);
  expect(start, isNot(-1), reason: 'Missing $listenerStart');

  final end = source.indexOf('});', start);
  expect(end, isNot(-1), reason: 'Missing end of $listenerStart block');

  return source.substring(start, end + 3);
}
