import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/command_types.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/pages/battery_details_page.dart';
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/pages/official_cloud_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';
import 'package:tailg_ble_app/widgets/vehicle_stage.dart';

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
    OfficialVehicleLocation? officialLocation,
  }) async {
    resetMockPreferences();
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
          vehicleLocation: officialLocation,
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

  testWidgets(
    'cached official carControlInfo opens bound home before refresh',
    (tester) async {
      resetMockStorage();
      app.officialCloudService.resetForTest();
      VehicleStore().resetForTest();
      SharedPreferences.setMockInitialValues({
        'official_cloud_token': 'cached-token',
        'official_cloud_phone': '18800001111',
        'official_cloud_user_id': 'user-1',
        'official_cloud_selected_vehicle': 'car-cached',
        'carControlInfo': jsonEncode({
          'carId': 'car-cached',
          'carNickName': '官方缓存车',
          'carPhoto': 'https://example.com/cached-bike.png',
        }),
      });
      await VehicleStore().init();
      await app.officialCloudService.initForTest();

      applyTestViewSize(tester, const Size(430, 2200));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        app.officialCloudService.resetForTest();
        VehicleStore().resetForTest();
        resetMockStorage();
      });

      await tester.pumpWidget(const TestApp(home: ControlPage()));
      await tester.pump();

      expect(find.byKey(const ValueKey('bound-home')), findsOneWidget);
      expect(find.text('官方缓存车'), findsOneWidget);
      expect(find.text('登录官方账号后同步车辆状态'), findsNothing);
      expect(find.text('绑定设备'), findsNothing);
    },
  );

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

  testWidgets('location card falls back to official vehicle coordinates', (
    tester,
  ) async {
    final vehicle = OfficialVehicle.fromJson({
      'imei': 'IMEI_MAIN',
      'carId': 'official-location-bike',
      'btmac': 'AA:BB:CC:DD:EE:FF',
      'latitude': '31.230400',
      'longitude': '121.473700',
    });

    await pumpBoundHome(
      tester,
      size: const Size(430, 2200),
      officialVehicle: vehicle,
    );

    expect(find.text('31.230400, 121.473700'), findsOneWidget);
    expect(find.text('暂无车辆定位'), findsNothing);
  });

  testWidgets('location card renders official parking location', (
    tester,
  ) async {
    final vehicle = OfficialVehicle.fromJson({
      'imei': 'IMEI_MAIN',
      'carId': 'official-parking-bike',
      'btmac': 'AA:BB:CC:DD:EE:FF',
    });
    final location = OfficialVehicleLocation.fromJson({
      'bleConnectTime': '2026-05-29 10:00:00',
      'bleConnectLat': '31.230400',
      'bleConnectLng': '121.473700',
      'carId': 'official-parking-bike',
      'bleConnectAddress': '停车点',
    });

    await pumpBoundHome(
      tester,
      size: const Size(430, 2200),
      officialVehicle: vehicle,
      officialLocation: location,
    );

    expect(find.text('2026-05-29 10:00:00'), findsOneWidget);
    expect(find.text('停车点'), findsOneWidget);
  });

  testWidgets('location card updates from local last location stream', (
    tester,
  ) async {
    await pumpBoundHome(tester, size: const Size(430, 2200));

    expect(find.text('暂无定位时间'), findsOneWidget);
    expect(find.text('暂无车辆定位'), findsOneWidget);

    await VehicleStore().updateLastLocation(
      'AA:BB:CC:DD:EE:FF',
      VehicleLocation(
        latitude: 31.2304,
        longitude: 121.4737,
        accuracy: 12,
        recordedAt: DateTime(2026, 5, 29, 10, 30),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('2026-05-29 10:30'), findsOneWidget);
    expect(find.text('31.230400, 121.473700'), findsOneWidget);
    expect(find.text('暂无定位时间'), findsNothing);
    expect(find.text('暂无车辆定位'), findsNothing);
  });

  testWidgets('official vehicle photo is used on control stage', (
    tester,
  ) async {
    final vehicle = OfficialVehicle.fromJson({
      'imei': 'IMEI_MAIN',
      'carId': 'official-photo-bike',
      'carNickName': '官方图片车',
      'btmac': 'AA:BB:CC:DD:EE:FF',
      'carPhoto': 'https://example.com/official-bike.png',
    });

    await pumpBoundHome(
      tester,
      size: const Size(430, 2200),
      officialVehicle: vehicle,
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byKey(const ValueKey('vehicle-stage-network-image')),
    );

    expect(image.imageUrl, vehicle.carPhoto);
    expect(image.fadeInDuration, Duration.zero);
    expect(image.fadeOutDuration, Duration.zero);
    expect(image.placeholderFadeInDuration, Duration.zero);
  });

  testWidgets('official vehicle stage uses apk fallback image and layout', (
    tester,
  ) async {
    await pumpBoundHome(tester, size: const Size(430, 2200));

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('vehicle-stage-asset-image')),
    );
    final padding = tester.widget<Padding>(
      find.byKey(const ValueKey('vehicle-stage-padding')),
    );

    expect((image.image as AssetImage).assetName, VehicleStage.fallbackAsset);
    expect(
      padding.padding,
      const EdgeInsets.symmetric(
        horizontal: VehicleStage.officialHorizontalPadding,
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('vehicle-stage-root'))).height,
      200,
    );
  });

  testWidgets('official carPhoto value is passed without url filtering', (
    tester,
  ) async {
    final vehicle = OfficialVehicle.fromJson({
      'imei': 'IMEI_MAIN',
      'carId': 'official-raw-photo-bike',
      'carNickName': '官方原始图片车',
      'btmac': 'AA:BB:CC:DD:EE:FF',
      'carPhoto': '  //cdn.example.com/official-bike.png  ',
    });

    await pumpBoundHome(
      tester,
      size: const Size(430, 2200),
      officialVehicle: vehicle,
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byKey(const ValueKey('vehicle-stage-network-image')),
    );

    expect(image.imageUrl, vehicle.carPhoto);
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
    expect(find.text('蓝牙续费'), findsNothing);
    expect(find.text('台铃充电站'), findsOneWidget);
  });

  testWidgets('conditional official feature cards show unavailable feedback', (
    tester,
  ) async {
    final vehicle = OfficialVehicle.fromJson({
      'imei': 'IMEI_MAIN',
      'carId': 'feature-feedback-bike',
      'btmac': 'AA:BB:CC:DD:EE:FF',
      'navigationProjection': '1',
      'cameraService': true,
      'smartMeter': {'enabled': true},
      'chargingStation': 'true',
    });

    await pumpBoundHome(
      tester,
      size: const Size(430, 3200),
      officialVehicle: vehicle,
    );

    for (final label in ['导航投屏', '摄像头', '智能仪表', '台铃充电站']) {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump();
      expect(find.text('$label暂未开放，可先使用官方云端控车'), findsOneWidget);
    }
  });

  testWidgets('official control card exposes default quick actions', (
    tester,
  ) async {
    await pumpBoundHome(tester, size: const Size(430, 2200));

    for (final label in ['更多功能', '用车人', '超级仪表']) {
      expect(find.text(label), findsNothing);
    }
    expect(find.text('打开座桶'), findsOneWidget);
    expect(find.bySemanticsLabel('添加快捷功能'), findsOneWidget);
    final edit = find.bySemanticsLabel('编辑快捷功能');
    expect(edit, findsOneWidget);
    expectMinTouchTargetHeight(tester, edit);
  });

  testWidgets('official hero vehicle switch opens vehicle center', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpBoundHome(tester, size: const Size(430, 2200));

      const vehicleSwitchLabel = '测试车辆，切换车辆';
      final vehicleSwitch = find.bySemanticsLabel(vehicleSwitchLabel);
      expect(vehicleSwitch, findsOneWidget);
      expect(
        tester.getSemantics(vehicleSwitch),
        matchesSemantics(
          label: vehicleSwitchLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(vehicleSwitchLabel));
      await tester.pumpAndSettle();

      expect(find.byType(OfficialCloudPage), findsOneWidget);
      expect(find.text('我的车辆'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('battery metric opens battery details page', (tester) async {
    await pumpBoundHome(tester, size: const Size(430, 2200));

    final batteryAction = find.byKey(
      const ValueKey('control-hero-battery-action'),
    );
    expect(batteryAction, findsOneWidget);
    expectMinTouchTargetHeight(tester, batteryAction);

    await tester.tap(batteryAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(BatteryDetailsPage), findsOneWidget);
    expect(find.text('电池信息'), findsOneWidget);
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
      // Cloud-only tip shows online/offline + last sync age when possible.
      expect(
        find.textContaining('同步').evaluate().isNotEmpty ||
            find.text('等待连接').evaluate().isNotEmpty,
        isTrue,
      );
      expect(find.bySemanticsLabel('点击连接'), findsOneWidget);
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

  // Regression: right-slide power gesture must actually dispatch powerOn.
  // _sendCommand previously set _busy=true *before* checking channel
  // availability, and the resolver reads busy (enabled = !busy && canUseCloud),
  // so every control command self-blocked with "正在执行控车指令" and never fired.
  testWidgets('right-slide power dispatches powerOn command', (tester) async {
    final vehicle = OfficialVehicle.fromJson({
      'imei': 'IMEI_MAIN',
      'carId': 'official-power-bike',
      'carNickName': '控车测试车',
      'btmac': 'AA:BB:CC:DD:EE:FF',
      // acc absent → isPowerOn false → knob maps the gesture to powerOn.
    });

    await pumpBoundHome(
      tester,
      size: const Size(430, 2200),
      officialVehicle: vehicle,
    );

    // Wire the stub AFTER pumpBoundHome (resetForTest clears it). When the
    // command lands, reflect the new power state so the confirmation poll
    // resolves instantly instead of hitting the network for 8s.
    app.officialCloudService.sendCommandOverride = (command) async {
      final powered = OfficialVehicle.fromJson({
        'imei': 'IMEI_MAIN',
        'carId': 'official-power-bike',
        'carNickName': '控车测试车',
        'btmac': 'AA:BB:CC:DD:EE:FF',
        'acc': 1,
      });
      app.officialCloudService.setStateForTest(
        app.officialCloudService.state.copyWith(
          vehicles: [powered],
          selectedVehicleKey: powered.key,
        ),
      );
      return 'success';
    };

    expect(app.officialCloudService.sentCommands, isEmpty);

    await tester.drag(
      find.byKey(const ValueKey('control-power-slide-handle')),
      const Offset(640, 0),
    );
    // busy Lottie uses a repeating AnimationController — avoid pumpAndSettle.
    await tester.pump(); // start _sendCommand (busy=true, pre-send delay)
    await tester.pump(const Duration(milliseconds: 550)); // past send delay
    await tester.pump(); // executor + confirmation
    await tester.pump(const Duration(milliseconds: 50));

    expect(app.officialCloudService.sentCommands, [CommandCode.powerOn]);
  });
}
