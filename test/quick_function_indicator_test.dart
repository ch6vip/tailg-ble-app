import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

import 'helpers/test_app.dart';

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
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(const TestApp(home: ControlPage()));
  await tester.pump(const Duration(milliseconds: 50));
  expect(tester.takeException(), isNull);
  expect(find.text('SHORTCUTS'), findsOneWidget);
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

  // The SHORTCUTS section exposes an inline edit entry that opens the
  // customization page where shortcuts can be reordered / shown / hidden.
  testWidgets('edit entry opens the shortcuts customization page', (
    tester,
  ) async {
    await _pumpControlPage(tester, const Size(430, 2600));
    expect(find.text('编辑'), findsOneWidget);

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    expect(find.text('快捷功能设置'), findsOneWidget);
    expect(find.byType(Switch), findsWidgets);
  });
}
