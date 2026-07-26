import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/pages/garage_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/source_scan.dart';
import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

void main() {
  setUp(() async {
    resetMockStorage();
    app.vehicleStore.resetForTest();
    app.officialCloudService.resetForTest();
    app.homeTabIndex.value = 2;
    await app.vehicleStore.init();
  });

  tearDown(() {
    app.vehicleStore.resetForTest();
    app.officialCloudService.resetForTest();
    app.homeTabIndex.value = 1;
  });

  test('garage sync errors redact exception details before display', () {
    final source = readSource('lib/pages/garage_page.dart');

    expect(source, contains('OfficialCloudRedactor.errorMessage(e)'));
    expect(source, isNot(contains('e is OfficialCloudApiException')));
  });

  testWidgets('mini vehicle actions keep 44dp touch targets', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      setTestViewSize(tester, const Size(390, 844));
      await app.vehicleStore.upsert(
        id: 'AA:BB:CC:DD:EE:FF',
        name: '测试车辆',
        protocol: VehicleProtocol.auto,
        makeDefault: true,
      );

      await tester.pumpWidget(const TestApp(home: GaragePage(embedded: true)));
      await tester.pump();

      final locateAction = find.ancestor(
        of: find.text('定位'),
        matching: find.byType(AppPressable),
      );
      expect(locateAction, findsOneWidget);
      expectMinTouchTargetHeight(tester, locateAction);

      const locateLabel = '定位';
      final locateSemantics = find.bySemanticsLabel(locateLabel);
      expect(
        tester.getSemantics(locateSemantics),
        matchesSemantics(
          label: locateLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(locateLabel));

      expect(app.homeTabIndex.value, 0);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('garage uses Cyber home mobile layout', (tester) async {
    setTestViewSize(tester, const Size(390, 844));

    await tester.pumpWidget(const TestApp(home: GaragePage()));
    await tester.pump();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      CyberHomeColors.pageBg,
    );
    final backAction = find.byKey(const ValueKey('garage-back'));
    final addAction = find.byKey(const ValueKey('garage-add'));
    expect(backAction, findsOneWidget);
    expect(addAction, findsOneWidget);
    expectMinTouchTargetHeight(tester, backAction);
    expectMinTouchTargetHeight(tester, addAction);
    expect(tester.takeException(), isNull);
  });

  testWidgets('garage edit dialog keeps Cyber light surface', (tester) async {
    await app.vehicleStore.upsert(
      id: 'AA:BB:CC:DD:EE:FF',
      name: '测试车辆',
      protocol: VehicleProtocol.auto,
      makeDefault: true,
    );

    await tester.pumpWidget(const TestApp(home: GaragePage(embedded: true)));
    await tester.pump();
    await tester.tap(find.byTooltip('车辆操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑名称'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<AlertDialog>(find.byType(AlertDialog)).backgroundColor,
      CyberHomeColors.card,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('signed-in garage lists official cloud vehicles', (tester) async {
    await app.vehicleStore.upsert(
      id: 'AA:BB:CC:DD:EE:FF',
      name: '测试车辆',
      protocol: VehicleProtocol.auto,
      makeDefault: true,
    );
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'official-garage-1',
      'carNickName': '云端车',
      'online': true,
      'electricQuantity': 88,
    });
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
      ),
    );

    await tester.pumpWidget(const TestApp(home: GaragePage(embedded: true)));
    await tester.pump();

    expect(find.text('账号车辆'), findsOneWidget);
    expect(find.text('云端车'), findsOneWidget);
    expect(find.text('使用中'), findsOneWidget);
    expect(find.text('本地存档'), findsOneWidget);
    expect(find.text('测试车辆'), findsOneWidget);
  });

  testWidgets('signed-in empty cloud garage shows empty copy', (tester) async {
    // No local vehicles after setUp reset; only signed-in empty cloud list.
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        vehicles: const [],
      ),
    );

    await tester.pumpWidget(const TestApp(home: GaragePage(embedded: true)));
    await tester.pump();

    expect(find.text('账号下暂无车辆'), findsOneWidget);
    expect(find.text('同步车辆'), findsOneWidget);
  });
}
