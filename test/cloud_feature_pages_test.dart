import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/notification_prefs_page.dart';
import 'package:tailg_ble_app/pages/ride_stats_page.dart';
import 'package:tailg_ble_app/pages/vehicle_settings_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/widgets/vehicle_switch_sheet.dart';

import 'helpers/snack_finders.dart';
import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
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
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

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
    expect(snackIcon(Icons.error_outline), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(app.officialCloudService.state.selectedVehicleKey, first.key);
  });

  testWidgets(
    'ride stats renders cloud travel summary and blocks future month',
    (tester) async {
      setTestViewSize(tester, const Size(430, 1200));
      final now = DateTime.now();
      final currentMonth =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final day = OfficialTravelDay.fromJson({
        'travelDate': '$currentMonth-01',
        // Official deviceTravel totalMileage / mileage are meters.
        'totalMileage': '12500',
        'deviceTravelDtoList': [
          {
            'deviceTravelId': 'trip-1',
            'mileage': '12500',
            'hours': '1',
            'min': '30',
            'sec': '0',
          },
        ],
      });
      final vehicle = OfficialVehicle.fromJson({
        'carId': 'stats-car',
        'frame': 'FRAME-STATS',
        'carNickName': '统计测试车',
      });
      // Gate requires signed-in user + vehicle; override skips network and
      // leaves the seeded travelDays in place for rendering.
      app.officialCloudService.refreshTravelHistoryOverride = (_) async {};
      app.officialCloudService.setStateForTest(
        OfficialCloudState.initial().copyWith(
          initialized: true,
          token: 'token',
          userId: 'uid-1',
          vehicles: [vehicle],
          selectedVehicleKey: vehicle.key,
          travelDays: [day],
        ),
      );

      await tester.pumpWidget(const TestApp(home: RideStatsPage()));
      await tester.pumpAndSettle();

      expect(find.textContaining('12.5', findRichText: true), findsWidgets);
      expect(find.textContaining('1h30m', findRichText: true), findsWidgets);
      expect(find.textContaining('1 次', findRichText: true), findsWidgets);
      // 12.5 km * 0.021 kg/km ≈ 0.26
      expect(find.textContaining('0.26 kg CO₂'), findsOneWidget);
      expect(find.text(currentMonth), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      expect(find.text(currentMonth), findsOneWidget);
    },
  );

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

      await tester.tap(switches.first);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(savedConfig, {'carMsg': false, 'sysMsg': false});
      expect(find.text('通知偏好已保存'), findsOneWidget);
    },
  );

  testWidgets('ride stats ignores travel completion after disposal', (
    tester,
  ) async {
    final completion = Completer<void>();
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'dispose-travel-car',
      'frame': 'FRAME-DISPOSE',
    });
    app.officialCloudService.refreshTravelHistoryOverride = (_) =>
        completion.future;
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        userId: 'uid-1',
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

  testWidgets('ride stats ignores stale month completion', (tester) async {
    setTestViewSize(tester, const Size(430, 1200));
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final previousMonth = DateTime(now.year, now.month - 1);
    final currentLabel = _monthLabel(currentMonth);
    final previousLabel = _monthLabel(previousMonth);
    final completions = <String, Completer<void>>{};
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'race-travel-car',
      'frame': 'FRAME-RACE',
    });
    app.officialCloudService.refreshTravelHistoryOverride = (month) {
      final completion = Completer<void>();
      completions[month] = completion;
      return completion.future;
    };
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        userId: 'uid-1',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
      ),
    );

    await tester.pumpWidget(const TestApp(home: RideStatsPage()));
    await tester.pump();
    expect(completions, contains(currentLabel));

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    expect(completions, contains(previousLabel));

    final previousDay = _travelDay('$previousLabel-01');
    app.officialCloudService.setStateForTest(
      app.officialCloudService.state.copyWith(
        travelDays: [previousDay],
        travelMonth: previousLabel,
      ),
    );
    completions[previousLabel]!.complete();
    await tester.pump();
    expect(find.text(previousDay.travelDate), findsOneWidget);

    final currentDay = _travelDay('$currentLabel-01');
    app.officialCloudService.setStateForTest(
      app.officialCloudService.state.copyWith(
        travelDays: [currentDay],
        travelMonth: currentLabel,
      ),
    );
    completions[currentLabel]!.complete();
    await tester.pump();

    expect(find.text(previousDay.travelDate), findsOneWidget);
    expect(find.text(currentDay.travelDate), findsNothing);
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

      await tester.tap(find.text('通知偏好'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationPrefsPage), findsOneWidget);
      expect(find.text('车辆消息通知'), findsOneWidget);
    },
  );
}

String _monthLabel(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}';
}

OfficialTravelDay _travelDay(String date) {
  return OfficialTravelDay.fromJson({
    'travelDate': date,
    // meters (1 km)
    'totalMileage': '1000',
    'deviceTravelDtoList': [
      {'deviceTravelId': 'trip-$date', 'mileage': '1000'},
    ],
  });
}
