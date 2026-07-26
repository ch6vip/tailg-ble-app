import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/induction_settings_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/permission_service.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

void main() {
  setUp(() {
    resetMockStorage();
    app.officialCloudService.resetForTest();
    app.manualModeService.resetForTest();
    app.inductionModeService.resetForTest();
    AppPermissionService.requestNotificationPermissionOverride = null;
  });

  tearDown(() {
    app.officialCloudService.resetForTest();
    app.manualModeService.resetForTest();
    app.inductionModeService.resetForTest();
    AppPermissionService.requestNotificationPermissionOverride = null;
  });

  testWidgets(
    'induction settings uses Cyber home layout and keeps BLE gate behavior',
    (tester) async {
      setTestViewSize(tester, const Size(390, 844));
      final vehicle = OfficialVehicle.fromJson({
        'carId': 'qgj-induction-car',
        'carNickName': '感应测试车',
        'modelType': 8,
      });
      app.officialCloudService.setStateForTest(
        OfficialCloudState.initial().copyWith(
          initialized: true,
          token: 'token',
          vehicles: [vehicle],
          selectedVehicleKey: vehicle.key,
        ),
      );

      await tester.pumpWidget(const TestApp(home: InductionSettingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('感应解锁'), findsOneWidget);
      expect(find.text('车辆感应'), findsOneWidget);
      expect(find.text('解锁模式'), findsOneWidget);
      expect(find.text('感应'), findsOneWidget);
      expect(find.text('手动'), findsOneWidget);
      expect(find.textContaining('未完成蓝牙协议登录'), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        CyberHomeColors.pageBg,
      );

      final backButton = find.byKey(const ValueKey('induction-settings-back'));
      final refreshButton = find.byKey(
        const ValueKey('induction-settings-refresh'),
      );
      final modeSelector = find.byWidgetPredicate(
        (widget) => widget is SegmentedButton<bool>,
      );
      expect(backButton, findsOneWidget);
      expect(refreshButton, findsOneWidget);
      expect(modeSelector, findsOneWidget);
      expect(tester.widget<AppPressable>(refreshButton).enabled, isTrue);
      expectMinTouchTargetHeight(tester, backButton);
      expectMinTouchTargetHeight(tester, refreshButton);
      expectMinTouchTargetHeight(tester, modeSelector);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('感应'));
      await tester.pump();
      expect(find.text('请先连接车辆蓝牙后再开启感应'), findsOneWidget);
    },
  );
}
