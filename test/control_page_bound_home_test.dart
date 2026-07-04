import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

void main() {
  Future<void> pumpBoundHome(
    WidgetTester tester, {
    Size? size,
    String name = '测试车辆',
    OfficialVehicle? officialVehicle,
  }) async {
    resetMockPreferences();
    app.proximityService.resetForTest();
    app.manualModeService.resetForTest();
    app.officialCloudService.resetForTest();
    VehicleStore().resetForTest();
    await VehicleStore().init();
    await VehicleStore().upsert(
      id: 'AA:BB:CC:DD:EE:FF',
      name: name,
      protocol: VehicleProtocol.auto,
      makeDefault: true,
    );
    if (officialVehicle != null) {
      app.officialCloudService.setStateForTest(
        OfficialCloudState.initial().copyWith(
          initialized: true,
          token: 'token',
          vehicles: [officialVehicle],
          selectedVehicleKey: officialVehicle.key,
        ),
      );
    }

    if (size != null) {
      applyTestViewSize(tester, size);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    await tester.pumpWidget(const TestApp(home: ControlPage()));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('bound control home builds without throwing', (tester) async {
    await pumpBoundHome(tester);

    expect(tester.takeException(), isNull);
    // Official replica: lower area follows fragment_control.xml entries.
    expect(find.text('车辆定位'), findsOneWidget);
    expect(find.text('导航投屏'), findsNothing);
    expect(find.text('历史轨迹'), findsOneWidget);
    expect(find.text('功能设置'), findsOneWidget);
    expect(find.text('NFC钥匙'), findsOneWidget);
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
    expect(find.text('车辆定位'), findsOneWidget);
    expect(find.bySemanticsLabel('可添加GPS'), findsOneWidget);
  });

  testWidgets('gps official vehicle hides add gps banner', (tester) async {
    final vehicle = OfficialVehicle.fromJson({
      'imei': 'IMEI_MAIN',
      'imeiGps': 'IMEI_GPS',
      'carId': 'official-gps-bike',
      'modelType': 1501,
      'btmac': 'AA:BB:CC:DD:EE:FF',
    });

    await pumpBoundHome(
      tester,
      size: const Size(430, 2200),
      officialVehicle: vehicle,
    );

    expect(find.text('历史轨迹'), findsOneWidget);
    expect(find.bySemanticsLabel('可添加GPS'), findsNothing);
    expect(find.text('功能设置'), findsOneWidget);
  });

  testWidgets('official feature flags reveal conditional control modules', (
    tester,
  ) async {
    final vehicle = OfficialVehicle.fromJson({
      'imei': 'IMEI_MAIN',
      'carId': 'feature-bike',
      'btmac': 'AA:BB:CC:DD:EE:FF',
      'navigationProjection': '1',
      'cameraService': true,
      'smartMeter': {'enabled': true},
      'bleRenewal': 1,
      'chargingStation': 'true',
    });

    await pumpBoundHome(
      tester,
      size: const Size(430, 3200),
      officialVehicle: vehicle,
    );

    expect(find.text('导航投屏'), findsOneWidget);
    expect(find.text('摄像头'), findsOneWidget);
    expect(find.text('智能仪表'), findsOneWidget);
    expect(find.text('蓝牙续费'), findsOneWidget);
    expect(find.text('台铃充电站'), findsOneWidget);
  });

  testWidgets('official control card exposes default quick placeholders', (
    tester,
  ) async {
    await pumpBoundHome(tester, size: const Size(430, 2200));

    for (final label in ['更多功能', '用车人', '超级仪表']) {
      expect(find.text(label), findsNothing);
    }
    expect(find.text('打开座桶'), findsNothing);
    expect(find.text('感应解锁'), findsNothing);
    expect(find.bySemanticsLabel('添加快捷功能'), findsNWidgets(2));
    final edit = find.bySemanticsLabel('编辑快捷功能');
    expect(edit, findsOneWidget);
    expectMinTouchTargetHeight(tester, edit);
  });

  testWidgets('official manual mode control keeps a 44dp touch target', (
    tester,
  ) async {
    await pumpBoundHome(tester, size: const Size(430, 2200));

    final manualModePill = find.byTooltip('感应模式已开启');
    expect(manualModePill, findsOneWidget);
    expectMinTouchTargetHeight(tester, manualModePill);
    expect(
      find.descendant(of: manualModePill, matching: find.byType(AppPressable)),
      findsOneWidget,
    );

    final enabledEvent = app.manualModeService.enabledStream.firstWhere(
      (value) => value,
    );

    await tester.tap(manualModePill);
    await tester.pump();
    await enabledEvent;
    await tester.pump();

    expect(app.manualModeService.enabled, isTrue);
  });

  testWidgets('mode toggle exposes semantics action', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpBoundHome(tester, size: const Size(430, 2200));

      final modeToggle = find.bySemanticsLabel('感应模式');
      expect(modeToggle, findsOneWidget);
      expect(
        tester.getSemantics(modeToggle),
        matchesSemantics(
          label: '感应模式',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasToggledState: true,
          isToggled: true,
        ),
      );

      final enabledEvent = app.manualModeService.enabledStream.firstWhere(
        (value) => value,
      );

      tester.semantics.tap(find.semantics.byLabel('感应模式'));
      await tester.pump();
      await enabledEvent;
      await tester.pump();

      expect(app.manualModeService.enabled, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('official settings entries use AppPressable feedback', (
    tester,
  ) async {
    await pumpBoundHome(tester, size: const Size(430, 2200));

    for (final label in ['车辆设置', '电子围栏', '分享用车']) {
      final option = find.ancestor(
        of: find.text(label),
        matching: find.byType(AppPressable),
      );
      expect(option, findsOneWidget);
      expectMinTouchTargetHeight(tester, option);
    }
  });

  testWidgets('official lower entries expose semantics actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpBoundHome(tester, size: const Size(430, 2200));

      for (final label in ['历史轨迹', '可添加GPS', 'NFC钥匙']) {
        final action = find.bySemanticsLabel(label);
        expect(action, findsOneWidget);
        expect(
          tester.getSemantics(action),
          matchesSemantics(
            label: label,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
      }

      final vehicleSetting = find.bySemanticsLabel('车辆设置');
      expect(vehicleSetting, findsOneWidget);
      expect(
        tester.getSemantics(vehicleSetting),
        matchesSemantics(
          label: '车辆设置',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('official control tip has no extra channel row', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpBoundHome(tester, size: const Size(430, 2200));

      expect(find.textContaining('控车通道'), findsNothing);
      expect(find.text('手动模式'), findsNothing);
      expect(find.text('未启动'), findsNothing);
      expect(find.text('已启动'), findsNothing);
      expect(find.text('已设防'), findsNothing);
      expect(find.text('未设防'), findsNothing);
      expect(find.text('等待连接'), findsOneWidget);
      expect(find.bySemanticsLabel('点击连接'), findsOneWidget);

      final modeAction = find.bySemanticsLabel('感应模式');
      expect(modeAction, findsOneWidget);
      expectMinTouchTargetHeight(tester, modeAction);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('bound home does not expose legacy all-functions sheet', (
    tester,
  ) async {
    await pumpBoundHome(tester, size: const Size(430, 2200));

    expect(find.text('全部功能'), findsNothing);
    expect(find.bySemanticsLabel('关闭全部功能'), findsNothing);
  });
}
