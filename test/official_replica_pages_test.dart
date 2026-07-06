import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/pages/official_replica_pages.dart';
import 'package:tailg_ble_app/services/log_service.dart';
import 'package:tailg_ble_app/services/replica_feature_store.dart';
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

  testWidgets('electric fence use last location fills coordinate fields', (
    tester,
  ) async {
    final store = VehicleStore();
    await store.init();
    final vehicle = await store.upsert(
      id: 'AA:BB:CC:DD:EE:FF',
      name: '测试车辆',
      protocol: VehicleProtocol.auto,
      makeDefault: true,
    );
    await store.updateLastLocation(
      vehicle.id,
      VehicleLocation(
        latitude: 31.2304,
        longitude: 121.4737,
        accuracy: 8,
        recordedAt: DateTime(2026, 7, 3, 12, 30),
      ),
    );
    await ReplicaFeatureStore().saveFenceConfig(
      FenceConfig(
        enabled: true,
        latitude: 22.543096,
        longitude: 114.057865,
        radiusMeters: 600,
        updatedAt: DateTime(2026, 7, 3, 12, 35),
      ),
    );

    await tester.pumpWidget(const TestApp(home: ElectricFencePage()));
    await tester.pump();
    await tester.pump();

    expect(find.widgetWithText(TextField, '22.543096'), findsOneWidget);
    expect(find.widgetWithText(TextField, '114.057865'), findsOneWidget);

    await tester.tap(find.text('使用最后位置'));
    await tester.pump();

    expect(find.widgetWithText(TextField, '31.230400'), findsOneWidget);
    expect(find.widgetWithText(TextField, '121.473700'), findsOneWidget);
  });

  testWidgets('ride record page renders log details', (tester) async {
    LogService().operation('测试操作', detail: '耗时 12ms');

    await tester.pumpWidget(const TestApp(home: RideRecordPage()));
    await tester.pump();

    expect(find.text('测试操作'), findsOneWidget);
    expect(find.textContaining('耗时 12ms'), findsOneWidget);
  });
}
