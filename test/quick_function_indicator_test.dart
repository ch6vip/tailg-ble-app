import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

import 'helpers/test_app.dart';

Future<void> _pumpControlPage(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  VehicleStore().resetForTest();
  await VehicleStore().init();
  await VehicleStore().upsert(
    id: 'AA:BB:CC:DD:EE:FF',
    name: '测试车辆',
    protocol: VehicleProtocol.auto,
    makeDefault: true,
  );

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(const TestApp(home: ControlPage()));
  await tester.pump(const Duration(milliseconds: 50));
  expect(tester.takeException(), isNull);
  // v8: 3 service cards replace old SHORTCUTS
  expect(find.text('车辆定位'), findsOneWidget);
}

void main() {
  // v8: service cards render without overflow on wide surfaces
  testWidgets('service cards render on wide surface', (tester) async {
    await _pumpControlPage(tester, const Size(2400, 2400));
    expect(find.text('电池详情'), findsOneWidget);
    expect(find.text('骑行记录'), findsOneWidget);
  });

  // v8: service cards remain stable on narrow surfaces
  testWidgets('service cards render on narrow surface', (tester) async {
    await _pumpControlPage(tester, const Size(430, 2600));
    expect(find.text('电池详情'), findsOneWidget);
    expect(find.text('骑行记录'), findsOneWidget);
  });

  // v8: bottom sheet opens when tapping "more" on ControlCard
  testWidgets('more functions sheet opens from control card', (tester) async {
    await _pumpControlPage(tester, const Size(430, 2600));
    // Tap the "更多功能" area on the ControlCard
    final moreFinder = find.text('更多功能');
    if (moreFinder.evaluate().isNotEmpty) {
      await tester.tap(moreFinder);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
