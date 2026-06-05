import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

const _indicator = Key('quickFunctionScrollIndicator');

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
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(const MaterialApp(home: ControlPage()));
  await tester.pump(const Duration(milliseconds: 50));
  expect(tester.takeException(), isNull);
  expect(find.text('快捷功能'), findsOneWidget);
}

void main() {
  // The quick-function row's scroll-position indicator must only appear when the
  // row actually overflows; otherwise it leaves a meaningless dark pill.
  testWidgets('indicator hidden when the row fits (wide surface)', (
    tester,
  ) async {
    await _pumpControlPage(tester, const Size(2400, 2400));
    expect(find.byKey(_indicator), findsNothing);
  });

  testWidgets('indicator shown when the row overflows (narrow surface)', (
    tester,
  ) async {
    await _pumpControlPage(tester, const Size(430, 2600));
    expect(find.byKey(_indicator), findsOneWidget);
  });
}
