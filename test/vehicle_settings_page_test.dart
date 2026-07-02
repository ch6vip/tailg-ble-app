import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/vehicle_settings_page.dart';

import 'helpers/snack_finders.dart';
import 'helpers/test_app.dart';

void main() {
  testWidgets('disabled pending vehicle setting shows info snack', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const TestApp(home: VehicleSettingsPage()));
    await tester.pump();

    await tester.tap(find.text('自动下电'));
    await tester.pump();

    expect(find.text('命令待真机验证，暂不开放写入'), findsOneWidget);
    expect(snackIcon(Icons.info_outline), findsOneWidget);
  });
}
