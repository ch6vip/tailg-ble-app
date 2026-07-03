import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/control_page_hero.dart';

import 'helpers/test_app.dart';

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
              healthLabel: '健康良好',
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
      expect(tester.getSize(vehicleSwitch).height, greaterThanOrEqualTo(44));

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

      const batteryLabel = '电量 72%，续航 48 km，健康良好';
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
}
