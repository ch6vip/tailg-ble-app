import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/control_page_hero.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('vehicle switch keeps a 44dp touch target', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: ControlPageHero(
            batteryLevel: 72,
            vehicleName: '测试车辆',
            onVehicleSwitch: () => tapped = true,
          ),
        ),
      ),
    );

    final vehicleSwitch = find.byKey(
      const ValueKey('control-hero-vehicle-switch'),
    );
    expect(vehicleSwitch, findsOneWidget);
    expect(tester.getSize(vehicleSwitch).height, greaterThanOrEqualTo(44));

    await tester.tap(vehicleSwitch);
    expect(tapped, isTrue);
  });
}
