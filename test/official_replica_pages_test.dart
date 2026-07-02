import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/pages/official_replica_pages.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

import 'helpers/snack_finders.dart';
import 'helpers/test_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VehicleStore().resetForTest();
  });

  testWidgets('electric fence save validates coordinates with info snack', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(home: ElectricFencePage()));
    await tester.pump();

    await tester.tap(find.text('保存围栏'));
    await tester.pump();

    expect(find.text('请输入有效坐标'), findsOneWidget);
    expect(snackIcon(Icons.info_outline), findsOneWidget);
  });
}
