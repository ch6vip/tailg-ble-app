import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/cyber_vehicle_control_page_v2.dart';
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
    setTestViewSize(tester, const Size(390, 1800));
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'smoke-1',
      'carNickName': '冒烟测试车',
      'modelType': 3,
      'isGps': 1,
      'btmac': 'AABBCCDDEEFF',
    });
    AppServices.instance.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'smoke-token',
        userId: 'u-smoke',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
      ),
    );

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
    // Channel-only card on home; unlock/induction lives in settings.
    expect(find.text('控车渠道'), findsOneWidget);
    expect(find.text('智能'), findsOneWidget);
    expect(find.text('仅蓝牙'), findsOneWidget);
    expect(find.text('仅云端'), findsOneWidget);
    expect(find.text('控车与解锁'), findsNothing);
    expect(find.text('解锁模式'), findsNothing);
    // Cyber shell shortcuts (no VOID section title 「控车」).
    expect(find.text('寻车'), findsWidgets);
    expect(find.text('滑动开锁'), findsWidgets);
    // Layout order under Cyber shell: keys/slide first, channel next, map/stats.
    expect(
      tester.getTopLeft(find.text('控车渠道')).dy,
      greaterThan(tester.getTopLeft(find.text('寻车')).dy),
    );
    expect(
      tester.getTopLeft(find.text('车辆位置')).dy,
      greaterThan(tester.getTopLeft(find.text('控车渠道')).dy),
    );

    await tester.tap(find.text('仅云端'));
    await tester.pump();
    // Compact channel strip no longer shows the long description copy.

    // Avoid scrollUntilVisible (can hang if target is off-list); just assert
    // the recent-commands section exists in the tree.
    expect(find.text('最近命令'), findsOneWidget);

    // Drop the page before the binding checks for pending timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
