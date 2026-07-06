import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/official_replica_pages.dart';
import 'package:tailg_ble_app/services/log_service.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

import 'helpers/snack_finders.dart';
import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';

void main() {
  setUp(() {
    resetMockPreferences();
    LogService().clear();
    VehicleStore().resetForTest();
  });

  tearDown(() {
    LogService().clear();
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

  testWidgets('ride record page renders log details', (tester) async {
    LogService().operation('测试操作', detail: '耗时 12ms');

    await tester.pumpWidget(const TestApp(home: RideRecordPage()));
    await tester.pump();

    expect(find.text('测试操作'), findsOneWidget);
    expect(find.textContaining('耗时 12ms'), findsOneWidget);
  });
}
