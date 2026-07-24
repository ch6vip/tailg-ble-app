import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart';
import 'package:tailg_ble_app/pages/cyber_vehicle_control_page_v2.dart';
import 'package:tailg_ble_app/widgets/void_particles.dart';
import 'package:tailg_ble_app/widgets/void_typography.dart';

import 'helpers/view_size.dart';

void main() {
  setUp(() {
    homeTabIndex.value = 1;
    VoidParticleField.enableAnimation = false;
    KineticType.enableAnimation = false;
  });

  testWidgets('App renders home page', (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const TailgBleApp());
      await tester.pump(); // Allow combined stream initial emission
      // No token + no local vehicle → Aurora home with sign-in gate banner.
      // Gate title + status line both use OfficialCloudMessages.signInRequired.
      expect(find.byType(CyberVehicleControlPageV2), findsOneWidget);
      expect(find.text('请先登录官方账号'), findsAtLeastNWidgets(1));
      expect(find.text('去登录'), findsOneWidget);
      // Nav vehicle item + home shortcuts section both expose 控车.
      expect(
        find.byKey(const ValueKey('official-bottom-nav-item-vehicle')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('official-bottom-nav-item-vehicle')),
          matching: find.text('控车'),
        ),
        findsOneWidget,
      );
      expect(find.text('控车'), findsAtLeastNWidgets(1));
      expect(find.text('服务'), findsAtLeastNWidgets(1));
      expect(find.text('我的'), findsAtLeastNWidgets(1));
      expect(find.text('消息'), findsNothing);
      expect(find.text('车库'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Bottom nav keeps vehicle in the center', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TailgBleApp());
    await tester.pump();

    final navBar = find.byType(BottomNavigationBar);
    expect(navBar, findsNothing);

    final serviceCenter = tester.getCenter(find.text('服务'));
    // Prefer the bottom-nav item key: home also shows a 控车 card title.
    final vehicleCenter = tester.getCenter(
      find.byKey(const ValueKey('official-bottom-nav-item-vehicle')),
    );
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

    // VOID orbital bar is 72; system inset is 0 in tests so bar height is 72.
    // All three tabs share the same slot height (no raised center icon).
    expect(tester.getSize(barFinder).height, 72);
    expect(tester.getSize(serviceItemFinder).height, 72);
    expect(tester.getSize(vehicleItemFinder).height, 72);
    expect(tester.getSize(mineItemFinder).height, 72);

    final barTop = tester.getTopLeft(barFinder).dy;
    final serviceTop = tester.getTopLeft(serviceItemFinder).dy;
    final vehicleTop = tester.getTopLeft(vehicleItemFinder).dy;
    final mineTop = tester.getTopLeft(mineItemFinder).dy;
    expect(serviceTop, closeTo(barTop, 0.5));
    expect(vehicleTop, closeTo(barTop, 0.5));
    expect(mineTop, closeTo(barTop, 0.5));

    // Labels share the same baseline (use nav item keys to avoid the card title).
    final serviceBottom = tester
        .getBottomLeft(
          find.descendant(of: serviceItemFinder, matching: find.text('服务')),
        )
        .dy;
    final vehicleBottom = tester
        .getBottomLeft(
          find.descendant(of: vehicleItemFinder, matching: find.text('控车')),
        )
        .dy;
    final mineBottom = tester
        .getBottomLeft(
          find.descendant(of: mineItemFinder, matching: find.text('我的')),
        )
        .dy;
    expect(serviceBottom, closeTo(vehicleBottom, 8.0));
    expect(mineBottom, closeTo(vehicleBottom, 8.0));
  });

  testWidgets('Service tab opens aggregate service hub', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TailgBleApp());
    await tester.pump();

    await tester.tap(find.text('服务'));
    await tester.pumpAndSettle();

    expect(find.text('服务中心'), findsOneWidget);
    for (final label in ['车辆定位', '历史轨迹', '电子围栏', '车辆设置', '电池服务']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('needLogin mode stays stable on a narrow surface', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      setTestViewSize(tester, const Size(360, 1800));

      await tester.pumpWidget(const TailgBleApp());
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.byType(CyberVehicleControlPageV2), findsOneWidget);
      expect(find.text('请先登录官方账号'), findsAtLeastNWidgets(1));
      expect(find.text('去登录'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
