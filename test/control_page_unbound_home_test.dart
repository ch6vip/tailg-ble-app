import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('virtual experience action shows info snack', (tester) async {
    SharedPreferences.setMockInitialValues({});
    VehicleStore().resetForTest();
    await VehicleStore().init();

    tester.view.physicalSize = const Size(430, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const TestApp(home: ControlPage()));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('虚拟体验（演示）'));
    await tester.pump();

    expect(find.text('虚拟体验功能开发中，可先「绑定设备」或登录官方账号查看车辆'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });
}
