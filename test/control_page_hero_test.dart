import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/control_page_hero.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';

void main() {
  testWidgets('hero actions expose semantics and keep 44dp targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var vehicleTapped = false;
    var batteryTapped = false;
    var notificationTapped = false;

    try {
      await tester.pumpWidget(
        TestApp(
          home: Scaffold(
            body: ControlPageHero(
              batteryLevel: 72,
              rangeKm: 48,
              vehicleName: '测试车辆',
              onVehicleSwitch: () => vehicleTapped = true,
              onBatteryTap: () => batteryTapped = true,
              onNotification: () => notificationTapped = true,
            ),
          ),
        ),
      );

      final vehicleSwitch = find.byKey(
        const ValueKey('control-hero-vehicle-switch'),
      );
      expect(vehicleSwitch, findsOneWidget);
      expectMinTouchTargetHeight(tester, vehicleSwitch);

      const vehicleLabel = '测试车辆，切换车辆';
      final vehicleAction = find.bySemanticsLabel(vehicleLabel);
      expect(vehicleAction, findsOneWidget);
      expect(
        tester.getSemantics(vehicleAction),
        matchesSemantics(
          label: vehicleLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      const batteryLabel = '电量 72%，续航 48 km';
      final batteryAction = find.bySemanticsLabel(batteryLabel);
      expect(batteryAction, findsOneWidget);
      expect(
        tester.getSemantics(batteryAction),
        matchesSemantics(
          label: batteryLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      const notificationLabel = '车辆消息';
      final notificationAction = find.bySemanticsLabel(notificationLabel);
      expect(notificationAction, findsOneWidget);
      expect(
        find.ancestor(
          of: find.byIcon(Icons.notifications_outlined),
          matching: find.byType(AppPressable),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(notificationAction),
        matchesSemantics(
          label: notificationLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(vehicleLabel));
      tester.semantics.tap(find.semantics.byLabel(batteryLabel));
      tester.semantics.tap(find.semantics.byLabel(notificationLabel));

      expect(vehicleTapped, isTrue);
      expect(batteryTapped, isTrue);
      expect(notificationTapped, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('hero title and battery metrics avoid negative letter spacing', (
    tester,
  ) async {
    Future<void> pumpHero(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        const TestApp(
          home: Scaffold(
            body: ControlPageHero(
              batteryLevel: 72,
              rangeKm: 48,
              vehicleName: '测试车辆',
            ),
          ),
        ),
      );
      await tester.pump();
    }

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final size in [const Size(430, 900), const Size(320, 900)]) {
      await pumpHero(size);

      final titleSpacing = tester
          .widget<Text>(find.text('测试车辆'))
          .style
          ?.letterSpacing;
      final rangeSpacing = tester
          .widget<Text>(find.text('48'))
          .style
          ?.letterSpacing;

      expect(titleSpacing, anyOf(isNull, greaterThanOrEqualTo(0)));
      expect(rangeSpacing, anyOf(isNull, greaterThanOrEqualTo(0)));
    }
  });
}
