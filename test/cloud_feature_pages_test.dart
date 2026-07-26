import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/official_ride_statistics.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/notification_prefs_page.dart';
import 'package:tailg_ble_app/pages/ride_stats_page.dart';
import 'package:tailg_ble_app/pages/vehicle_settings_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';
import 'package:tailg_ble_app/widgets/lucide_icon.dart';
import 'package:tailg_ble_app/widgets/vehicle_switch_sheet.dart';

import 'helpers/snack_finders.dart';
import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

void main() {
  setUp(() {
    resetMockStorage();
    app.officialCloudService.resetForTest();
  });

  tearDown(() {
    app.officialCloudService.resetForTest();
  });

  testWidgets('vehicle switch sheet selects another official vehicle', (
    tester,
  ) async {
    final first = OfficialVehicle.fromJson({
      'carId': 'cloud-first',
      'carNickName': '第一辆车',
      'electricQuantity': 72,
      'online': true,
    });
    final second = OfficialVehicle.fromJson({
      'carId': 'cloud-second',
      'carNickName': '第二辆车',
      'electricQuantity': 48,
      'online': false,
    });
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        vehicles: [first, second],
        selectedVehicleKey: first.key,
      ),
    );

    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showVehicleSwitchSheet(context),
                child: const Text('打开车辆切换'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开车辆切换'));
    await tester.pumpAndSettle();

    expect(find.text('切换车辆'), findsOneWidget);
    expect(find.text('第一辆车'), findsOneWidget);
    expect(find.text('第二辆车'), findsOneWidget);
    expect(find.byIcon(Lucide.checkCircle), findsOneWidget);

    await tester.tap(find.text('第二辆车'));
    await tester.pumpAndSettle();

    expect(app.officialCloudService.state.selectedVehicleKey, second.key);
    expect(find.text('切换车辆'), findsNothing);
  });

  testWidgets('vehicle switch sheet scrolls on a short screen', (tester) async {
    setTestViewSize(tester, const Size(390, 600));
    final vehicles = List.generate(
      12,
      (index) => OfficialVehicle.fromJson({
        'carId': 'scroll-car-$index',
        'carNickName': '车辆 ${index + 1}',
      }),
    );
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        vehicles: vehicles,
        selectedVehicleKey: vehicles.first.key,
      ),
    );

    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showVehicleSwitchSheet(context),
                child: const Text('打开车辆切换'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开车辆切换'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('车辆 12'),
      200,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('车辆 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vehicle switch failure keeps sheet open and restores actions', (
    tester,
  ) async {
    final first = OfficialVehicle.fromJson({
      'carId': 'failure-first',
      'carNickName': '第一辆车',
    });
    final second = OfficialVehicle.fromJson({
      'carId': 'failure-second',
      'carNickName': '第二辆车',
    });
    app.officialCloudService.selectVehicleOverride = (_) =>
        Future<void>.error(Exception('token=abcdef123456'));
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        vehicles: [first, second],
        selectedVehicleKey: first.key,
      ),
    );

    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showVehicleSwitchSheet(context),
                child: const Text('打开车辆切换'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开车辆切换'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('第二辆车'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('切换车辆'), findsOneWidget);
    expect(find.text('Exception: token=abc***456'), findsOneWidget);
    expect(snackIcon(Lucide.alertCircle), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(app.officialCloudService.state.selectedVehicleKey, first.key);
  });

  testWidgets('ride stats renders official day statistics structure', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(430, 1200));
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'stats-car',
      'frame': 'FRAME-STATS',
      'carNickName': '统计测试车',
    });
    final statistics = _rideStatistics(
      dayMileage: '12500',
      totalMileage: '456780',
      carbonSaving: '2.14',
      carbonAbsorption: '0.43',
      maxSpeed: '52.3',
      ridingTime: '90',
      ridingCount: '3',
      avgSpeed: '18.7',
    );
    app.officialCloudService.refreshRideStatisticsOverride = (_) async {};
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
        rideStatistics: statistics,
        ridePeriod: OfficialRidePeriod.day,
      ),
    );

    await tester.pumpWidget(const TestApp(home: RideStatsPage()));
    await tester.pumpAndSettle();

    expect(find.text('日节碳量'), findsOneWidget);
    expect(find.text('树木吸碳'), findsOneWidget);
    expect(find.text('今日里程'), findsOneWidget);
    expect(find.text('累计里程'), findsOneWidget);
    expect(find.text('最快时速'), findsOneWidget);
    expect(find.text('总时长'), findsOneWidget);
    expect(find.text('骑行次数'), findsOneWidget);
    expect(find.text('平均时速'), findsOneWidget);
    expect(find.textContaining('12.50', findRichText: true), findsOneWidget);
    expect(find.textContaining('456.78', findRichText: true), findsOneWidget);
    expect(find.textContaining('2.14', findRichText: true), findsOneWidget);
    expect(find.textContaining('0.43', findRichText: true), findsOneWidget);
    expect(find.byKey(const ValueKey('ride-period-day')), findsOneWidget);
    expect(find.byIcon(Lucide.chevronLeft), findsNothing);
    expect(find.byIcon(Lucide.chevronRight), findsNothing);
    expect(find.textContaining('0.26 kg CO₂'), findsNothing);

    await tester.tap(find.byTooltip('节碳量说明'));
    await tester.pumpAndSettle();
    expect(find.textContaining('减排二氧化碳0.171kg'), findsOneWidget);
    Navigator.of(tester.element(find.text('节碳量说明'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('树木吸碳说明'));
    await tester.pumpAndSettle();
    expect(find.textContaining('二氧化碳5.023kg'), findsOneWidget);
  });

  testWidgets(
    'notification preferences loads, toggles, and saves cloud config',
    (tester) async {
      setTestViewSize(tester, const Size(430, 1000));
      Map<String, bool>? savedConfig;
      app.officialCloudService.getMessageControlOverride = () async => {
        'carMsg': true,
        'sysMsg': false,
      };
      app.officialCloudService.setMessagePushConfigOverride = (config) async {
        savedConfig = Map.of(config);
      };
      app.officialCloudService.setStateForTest(
        OfficialCloudState.initial().copyWith(
          initialized: true,
          token: 'token',
        ),
      );

      await tester.pumpWidget(const TestApp(home: NotificationPrefsPage()));
      await tester.pumpAndSettle();

      expect(find.text('车辆消息通知'), findsOneWidget);
      expect(find.text('系统消息通知'), findsOneWidget);
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));
      expect((tester.widget<Switch>(switches.first)).value, isTrue);
      final firstPreference = find.ancestor(
        of: switches.first,
        matching: find.byType(SwitchListTile),
      );
      expect(firstPreference, findsOneWidget);
      expectMinTouchTargetHeight(tester, firstPreference);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        CyberHomeColors.pageBg,
      );

      applyTestViewSize(tester, const Size(390, 844));
      await tester.pump();
      expect(find.text('车辆消息通知'), findsOneWidget);
      expect(find.text('系统消息通知'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(switches.first);
      await tester.tap(
        find.byKey(const ValueKey('notification-preferences-save')),
      );
      await tester.pumpAndSettle();

      expect(savedConfig, {'carMsg': false, 'sysMsg': false});
      expect(find.text('通知偏好已保存'), findsOneWidget);
    },
  );

  testWidgets('ride stats ignores request completion after disposal', (
    tester,
  ) async {
    final completion = Completer<void>();
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'dispose-travel-car',
      'frame': 'FRAME-DISPOSE',
    });
    app.officialCloudService.refreshRideStatisticsOverride = (_) =>
        completion.future;
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
      ),
    );

    await tester.pumpWidget(const TestApp(home: RideStatsPage()));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    completion.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('ride stats uses Cyber home mobile layout', (tester) async {
    setTestViewSize(tester, const Size(390, 844));
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'mobile-stats-car',
      'frame': 'FRAME-MOBILE-STATS',
    });
    app.officialCloudService.refreshRideStatisticsOverride = (_) async {};
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
        rideStatistics: _rideStatistics(),
      ),
    );

    await tester.pumpWidget(const TestApp(home: RideStatsPage()));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      CyberHomeColors.pageBg,
    );
    final backAction = find.byKey(const ValueKey('ride-stats-back'));
    expect(backAction, findsOneWidget);
    expectMinTouchTargetHeight(tester, backAction);
    final helpAction = find.byKey(const ValueKey('ride-stats-help'));
    expectMinTouchTargetHeight(tester, helpAction);
    for (final period in OfficialRidePeriod.values) {
      final periodAction = find.byKey(ValueKey('ride-period-${period.name}'));
      expect(periodAction, findsOneWidget);
      expectMinTouchTargetHeight(tester, periodAction);
    }
    expect(find.byKey(const ValueKey('ride-mileage-notice')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ride stats ignores stale period completion', (tester) async {
    setTestViewSize(tester, const Size(430, 1200));
    final completions = <OfficialRidePeriod, Completer<void>>{};
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'race-travel-car',
      'frame': 'FRAME-RACE',
    });
    app.officialCloudService.refreshRideStatisticsOverride = (period) {
      final completion = Completer<void>();
      completions[period] = completion;
      return completion.future;
    };
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
      ),
    );

    await tester.pumpWidget(const TestApp(home: RideStatsPage()));
    await tester.pump();
    expect(completions, contains(OfficialRidePeriod.day));

    await tester.tap(find.byKey(const ValueKey('ride-period-week')));
    await tester.pump();
    expect(completions, contains(OfficialRidePeriod.week));

    final weekStatistics = _rideStatistics(
      weekMileage: '22000',
      totalMileage: '100000',
    );
    app.officialCloudService.setStateForTest(
      app.officialCloudService.state.copyWith(
        rideStatistics: weekStatistics,
        ridePeriod: OfficialRidePeriod.week,
      ),
    );
    completions[OfficialRidePeriod.week]!.complete();
    await tester.pump();
    expect(find.text('本周里程'), findsOneWidget);
    expect(find.textContaining('22.00', findRichText: true), findsOneWidget);

    final staleDayStatistics = _rideStatistics(dayMileage: '99000');
    app.officialCloudService.setStateForTest(
      app.officialCloudService.state.copyWith(
        rideStatistics: staleDayStatistics,
        ridePeriod: OfficialRidePeriod.day,
      ),
    );
    completions[OfficialRidePeriod.day]!.complete();
    await tester.pump();

    expect(find.text('本周里程'), findsOneWidget);
    expect(find.textContaining('22.00', findRichText: true), findsOneWidget);
    expect(find.textContaining('99.00', findRichText: true), findsNothing);
  });

  testWidgets(
    'vehicle settings renders selected vehicle and opens preferences',
    (tester) async {
      setTestViewSize(tester, const Size(430, 1200));
      app.officialCloudService.getMessageControlOverride = () async => {
        'carMsg': true,
      };
      final vehicle = OfficialVehicle.fromJson({
        'carId': 'settings-car',
        'carNickName': '设置测试车',
        'frame': 'FRAME-SETTINGS',
        'imei': 'IMEI-SETTINGS',
        'online': true,
        'defenceStatus': '1',
      });
      app.officialCloudService.setStateForTest(
        OfficialCloudState.initial().copyWith(
          initialized: true,
          token: 'token',
          vehicles: [vehicle],
          selectedVehicleKey: vehicle.key,
        ),
      );

      await tester.pumpWidget(const TestApp(home: VehicleSettingsPage()));
      await tester.pump();

      expect(find.text('设置测试车'), findsOneWidget);
      expect(find.text('FRAME-SETTINGS'), findsOneWidget);
      expect(find.text('IMEI-SETTINGS'), findsOneWidget);
      expect(find.text('车辆在线'), findsOneWidget);
      expect(find.text('通知偏好'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('vehicle-settings-summary')),
        findsOneWidget,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        CyberHomeColors.pageBg,
      );
      expect(find.textContaining('app/car/bikeUnbind'), findsNothing);

      applyTestViewSize(tester, const Size(390, 844));
      await tester.pump();
      expect(find.text('感应解锁'), findsOneWidget);
      expect(find.text('解绑车辆'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('通知偏好'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationPrefsPage), findsOneWidget);
      expect(find.text('车辆消息通知'), findsOneWidget);
    },
  );
}

OfficialRideStatistics _rideStatistics({
  String avgSpeed = '18',
  String carbonAbsorption = '0.2',
  String carbonSaving = '1.0',
  String dayMileage = '1000',
  String maxSpeed = '40',
  String monthsMileage = '30000',
  String ridingCount = '2',
  String ridingTime = '30',
  String totalMileage = '100000',
  String weekMileage = '7000',
  String yearMileage = '150000',
}) {
  return OfficialRideStatistics(
    avgSpeed: avgSpeed,
    carbonAbsorption: carbonAbsorption,
    carbonSaving: carbonSaving,
    dayMileage: dayMileage,
    maxSpeed: maxSpeed,
    monthsMileage: monthsMileage,
    ridingCount: ridingCount,
    ridingTime: ridingTime,
    totalMileage: totalMileage,
    weekMileage: weekMileage,
    yearMileage: yearMileage,
  );
}
