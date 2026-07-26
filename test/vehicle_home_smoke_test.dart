import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/battery_details_page.dart';
import 'package:tailg_ble_app/pages/cyber_vehicle_control_page_v2.dart';
import 'package:tailg_ble_app/pages/ride_stats_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/official_mqtt_service.dart';
import 'package:tailg_ble_app/services/permission_service.dart';
import 'package:tailg_ble_app/services/service_locator.dart';

import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/view_size.dart';

/// P4-4 light smoke: signed-in cloud state → 爱车 page renders without crash.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    resetMockStorage();
    // Keep MQTT sockets + retry timers out of widget smoke. CI fails on a
    // pending FakeTimer from preconnect backoff (600ms) otherwise.
    OfficialMqttService.liveConnectEnabled = false;
    await OfficialMqttService().resetForTest();
    OfficialMqttService.liveConnectEnabled = false;
    OfficialCloudService().resetForTest();
    // Avoid AppServices.reset(): ConnectionManager.dispose can hang on
    // platform BLE teardown under Windows. Prefer targeted service resets.
    AppServices.instance.autoConnectService.resetForTest();
    AppServices.instance.manualModeService.resetForTest();
    AppServices.instance.inductionModeService.resetForTest();
    OfficialMqttService.liveConnectEnabled = false;

    // Near-field path probes BLE permissions; short-circuit platform channels.
    AppPermissionService.requestBleScanPermissionsOverride =
        ({bool request = true}) async =>
            const PermissionCheckResult.denied('test denied');
  });

  tearDown(() async {
    AppPermissionService.requestBleScanPermissionsOverride = null;
    OfficialMqttService.liveConnectEnabled = false;
    await OfficialMqttService().resetForTest();
    OfficialMqttService.liveConnectEnabled = true;
    OfficialCloudService().resetForTest();
    AppServices.instance.autoConnectService.resetForTest();
    AppServices.instance.manualModeService.resetForTest();
    AppServices.instance.inductionModeService.resetForTest();
    resetMockStorage();
  });

  testWidgets('signed-in vehicle home renders vehicle name', (tester) async {
    setTestViewSize(tester, const Size(390, 844));
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'smoke-1',
      'carNickName': '冒烟测试车',
      'frame': 'FRAME-SMOKE',
      'modelType': 3,
      'isGps': 1,
      'acc': 0,
      'defenceStatus': 1,
      'btmac': 'AABBCCDDEEFF',
      'electricQuantity': 18,
      'frontTirePressure': 1.2,
      'frontTireTemperature': 23,
      'rearTirePressure': 1.7,
      'rearTireTemperature': 23,
    });
    AppServices.instance.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'smoke-token',
        userId: 'u-smoke',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
        vehicleMessages: [
          OfficialCloudMessage(
            id: 'vehicle:home-alert',
            title: '车辆提醒',
            content: '车辆电量过低，请及时充电',
            time: DateTime.now().subtract(const Duration(minutes: 3)),
            category: OfficialCloudMessageCategory.vehicle,
            carId: vehicle.carId,
          ),
        ],
      ),
    );
    AppServices.instance.officialCloudService.refreshRideStatisticsOverride =
        (_) async {};

    await tester.pumpWidget(const TestApp(home: CyberVehicleControlPageV2()));
    await tester.pump();
    // Drain microtasks from silent refresh / MQTT skip / permission deny.
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('冒烟测试车'), findsWidgets);
    // Official right-top BLE chip: permanent-deny maps to 无蓝牙; temporary
    // deny still shows 点击连接 so tap can request permission.
    expect(
      find.text('无蓝牙').evaluate().isNotEmpty ||
          find.text('点击连接').evaluate().isNotEmpty,
      isTrue,
    );
    // The large vehicle stage remains; the former alert/tire rows stay absent.
    expect(find.byKey(const ValueKey('cyber-hero-vehicle')), findsOneWidget);
    expect(find.textContaining('1.2 bar'), findsNothing);
    expect(find.textContaining('1.7 bar'), findsNothing);
    expect(find.text('车辆电量过低，请及时充电'), findsNothing);
    expect(find.byKey(const ValueKey('cyber-home-alert')), findsNothing);
    expect(find.text('车辆在附近时可连接蓝牙本地控车'), findsNothing);
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.byKey(const ValueKey('cyber-hero-battery-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(BatteryDetailsPage), findsOneWidget);
    expect(find.text('电池信息'), findsOneWidget);
    Navigator.of(tester.element(find.byType(BatteryDetailsPage))).pop();
    await tester.pumpAndSettle();

    // Channel controls stay available from the compact status line without
    // adding a full-width card that is absent from the new design.
    expect(find.text('控车渠道'), findsNothing);
    expect(find.text('控车与解锁'), findsNothing);
    expect(find.text('解锁模式'), findsNothing);
    // Cyber shell shortcuts (no VOID section title 「控车」).
    expect(find.text('寻车'), findsWidgets);
    expect(find.text('右滑启动'), findsWidgets);
    expect(find.text('解防'), findsWidgets);
    expect(find.text('密码解锁'), findsNothing);
    expect(find.textContaining('点击通电'), findsNothing);
    expect(find.textContaining('点击断电'), findsNothing);
    final controlGrid = find.byKey(const ValueKey('cyber-control-grid'));
    final mapStats = find.byKey(const ValueKey('cyber-map-stats-row'));
    double controlsToMapGap() =>
        tester.getTopLeft(mapStats).dy - tester.getBottomRight(controlGrid).dy;
    expect(find.byKey(const ValueKey('cyber-nav-card')), findsNothing);
    expect(find.text('仪表投屏导航'), findsNothing);
    expect(controlsToMapGap(), closeTo(32, 0.1));
    expect(tester.takeException(), isNull);

    // The inter-section rhythm stays stable on the narrower logical width
    // used by the visual reference.
    applyTestViewSize(tester, const Size(360, 800));
    await tester.pump();
    expect(controlsToMapGap(), closeTo(32, 0.1));
    expect(tester.takeException(), isNull);
    applyTestViewSize(tester, const Size(390, 844));
    await tester.pump();

    // Layout order under Cyber shell: keys/slide, then map/stats.
    expect(
      tester.getTopLeft(find.text('车辆位置')).dy,
      greaterThan(tester.getTopLeft(find.text('寻车')).dy),
    );

    final header = find.byKey(const ValueKey('cyber-collapsing-header'));
    expect(tester.getSize(header).height, closeTo(424, 0.1));
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('cyber-expanded-header-opacity')),
          )
          .opacity,
      1,
    );
    applyTestViewSize(tester, const Size(390, 700));
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('cyber-compact-header-opacity')),
          )
          .opacity,
      greaterThan(0.9),
    );
    await tester.tap(find.byKey(const ValueKey('cyber-compact-battery-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(BatteryDetailsPage), findsOneWidget);
    Navigator.of(tester.element(find.byType(BatteryDetailsPage))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cyber-compact-status')));
    await tester.pumpAndSettle();
    expect(find.text('控车渠道'), findsWidgets);
    expect(find.text('智能'), findsOneWidget);
    expect(find.text('仅蓝牙'), findsOneWidget);
    expect(find.text('仅云端'), findsOneWidget);
    await tester.tap(find.text('仅云端'));
    await tester.pump();
    Navigator.of(tester.element(find.text('控车渠道').first)).pop();
    await tester.pumpAndSettle();

    final rideStatsEntry = find.byKey(const ValueKey('cyber-ride-stats-entry'));
    await tester.ensureVisible(rideStatsEntry);
    await tester.tap(rideStatsEntry);
    await tester.pumpAndSettle();
    expect(find.byType(RideStatsPage), findsOneWidget);
    expect(find.text('骑行统计'), findsOneWidget);
    Navigator.of(tester.element(find.byType(RideStatsPage))).pop();
    await tester.pumpAndSettle();

    // Empty recent commands stay out of the design until a command is sent.
    expect(find.text('最近命令'), findsNothing);

    // Drop the page before the binding checks for pending timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
