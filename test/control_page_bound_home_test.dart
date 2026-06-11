import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

import 'helpers/test_app.dart';

void main() {
  Future<void> pumpBoundHome(
    WidgetTester tester, {
    Size? size,
    String name = '测试车辆',
  }) async {
    SharedPreferences.setMockInitialValues({});
    VehicleStore().resetForTest();
    await VehicleStore().init();
    await VehicleStore().upsert(
      id: 'AA:BB:CC:DD:EE:FF',
      name: name,
      protocol: VehicleProtocol.auto,
      makeDefault: true,
    );

    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
    }

    await tester.pumpWidget(const TestApp(home: ControlPage()));
    await tester.pump(const Duration(milliseconds: 50));
  }

  // Regression: the bound (vehicle-present) control home used to throw
  // "Null check operator used on a null value" on first build, because the
  // quick-function card's scroll-progress indicator read maxScrollExtent before
  // the horizontal list had laid out. In release that surfaced as a large grey
  // ErrorWidget filling the screen below the SHORTCUTS section.
  testWidgets('bound control home builds without throwing', (tester) async {
    await pumpBoundHome(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('SHORTCUTS'), findsOneWidget);
  });

  testWidgets('bound control home stays stable on a narrow surface', (
    tester,
  ) async {
    await pumpBoundHome(
      tester,
      size: const Size(320, 2600),
      name: '这是一辆名称特别长的测试车辆用于验证首页不会溢出',
    );

    expect(tester.takeException(), isNull);
    expect(find.text('请连接车辆'), findsOneWidget);
    expect(find.text('骑行模式'), findsOneWidget);
  });
}
