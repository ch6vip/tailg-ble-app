import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/official_cloud_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

import 'helpers/test_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    app.vehicleStore.resetForTest();
    app.officialCloudService.resetForTest();
  });

  tearDown(() {
    app.vehicleStore.resetForTest();
    app.officialCloudService.resetForTest();
  });

  testWidgets('stale local link notice keeps a 44dp touch target', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final vehicle = OfficialVehicle.fromJson({
      'carId': 'official-1',
      'carName': '测试车辆',
      'btmac': 'AABBCCDDEEFF',
    });
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        phone: '18812345678',
        userId: 'user-1',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
        localVehicleLinks: {vehicle.key: 'missing-local-id'},
      ),
    );

    await tester.pumpWidget(const TestApp(home: OfficialCloudPage()));

    final staleNotice = find.ancestor(
      of: find.text('关联的本地车辆已不存在，点击清理'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is InkWell &&
            widget.borderRadius == BorderRadius.circular(12),
      ),
    );
    expect(staleNotice, findsOneWidget);
    expect(tester.getSize(staleNotice).height, greaterThanOrEqualTo(44));
  });

  testWidgets('missing BLE identity scan action keeps a 44dp touch target', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final vehicle = OfficialVehicle.fromJson({
      'carId': 'official-without-ble',
      'carName': '未返回蓝牙车辆',
    });
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        phone: '18812345678',
        userId: 'user-1',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
      ),
    );

    await tester.pumpWidget(const TestApp(home: OfficialCloudPage()));

    final scanAction = find.ancestor(
      of: find.text('去扫描'),
      matching: find.byType(TextButton),
    );
    expect(scanAction, findsOneWidget);
    expect(tester.getSize(scanAction).height, greaterThanOrEqualTo(44));
  });
}
