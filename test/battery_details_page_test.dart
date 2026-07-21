import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/battery_details_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

import 'helpers/snack_finders.dart';
import 'helpers/source_scan.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

void main() {
  setUp(() {
    app.officialCloudService.resetForTest();
  });

  test('BatteryDetailsPage redacts refresh failure snack messages', () {
    final source = readSource('lib/pages/battery_details_page.dart');
    final refreshStart = source.indexOf('Future<void> _refreshAllBatteryData');
    final refreshEnd = source.indexOf(
      'void _showCorrectBatterySheet',
      refreshStart,
    );

    expect(refreshStart, greaterThanOrEqualTo(0));
    expect(refreshEnd, greaterThan(refreshStart));

    final refreshSource = source.substring(refreshStart, refreshEnd);

    // Assert on the AppSnack.error(...) call span so multi-line formatting
    // cannot hide a raw e.toString() snack (logs may still use e.toString()).
    final snackStart = refreshSource.indexOf('AppSnack.error(');
    expect(snackStart, greaterThanOrEqualTo(0));
    final snackEnd = refreshSource.indexOf(');', snackStart);
    expect(snackEnd, greaterThan(snackStart));
    final snackCall = refreshSource.substring(snackStart, snackEnd + 2);

    expect(snackCall, contains('OfficialCloudRedactor.errorMessage(e)'));
    expect(snackCall, isNot(contains('e.toString()')));
    expect(snackCall, isNot(contains(r'$e')));
  });

  testWidgets('refreshing battery details while signed out shows info snack', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(430, 1200));

    await tester.pumpWidget(const TestApp(home: BatteryDetailsPage()));
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('请先登录官方账号'), findsOneWidget);
    expect(snackIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('battery refresh and correct actions keep 44dp touch targets', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(430, 1200));
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        vehicles: [
          OfficialVehicle.fromJson({
            'carId': 'car-1',
            'carNickName': '测试车',
            'modelType': 8,
          }),
        ],
        selectedVehicleKey: 'car-1',
      ),
    );

    await tester.pumpWidget(const TestApp(home: BatteryDetailsPage()));
    await tester.pump();

    final refreshAction = find.ancestor(
      of: find.text('刷新'),
      matching: find.byType(TextButton),
    );
    final correctionAction = find.ancestor(
      of: find.text('更正电池'),
      matching: find.byType(TextButton),
    );
    expect(refreshAction, findsOneWidget);
    expect(correctionAction, findsWidgets);
    expectMinTouchTargetHeight(tester, refreshAction);
    expectMinTouchTargetHeight(tester, correctionAction.first);
  });

  testWidgets('official battery metrics render voltage and temperature', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(430, 1200));
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        batteryInfo: OfficialBatteryInfo.fromJson({
          'voltage': 52.4,
          'temperature': 31.2,
          'consumePowerPercent': 0,
          'loopCount': 0,
        }),
      ),
    );

    await tester.pumpWidget(const TestApp(home: BatteryDetailsPage()));
    await tester.pump();

    expect(find.text('52.4V'), findsWidgets);
    expect(find.text('31.2°C'), findsWidgets);
    // Real zeros from API must render, not collapse to 待读取.
    expect(find.text('0%'), findsWidgets);
    expect(find.text('0'), findsWidgets);
    expect(find.text('今日耗电'), findsWidgets);
    expect(find.text('循环次数'), findsWidgets);
    expect(find.text('当前温度'), findsWidgets);
  });

  testWidgets('cycle help sheet opens from metric help icon', (tester) async {
    setTestViewSize(tester, const Size(430, 1400));
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        batteryInfo: OfficialBatteryInfo.fromJson({
          'loopCount': 3,
          'batteryScore': 90,
        }),
      ),
    );

    await tester.pumpWidget(const TestApp(home: BatteryDetailsPage()));
    await tester.pump();

    final helpIcons = find.byIcon(Icons.help_outline);
    expect(helpIcons, findsWidgets);
    await tester.ensureVisible(helpIcons.first);
    await tester.tap(helpIcons.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('关于循环次数'), findsOneWidget);
    expect(find.text('知道了'), findsOneWidget);
  });

  testWidgets('signed-in battery page shows last sync age', (tester) async {
    setTestViewSize(tester, const Size(430, 1200));
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        batteryInfo: OfficialBatteryInfo.fromJson({'voltage': 52.4}),
      ),
    );

    await tester.pumpWidget(const TestApp(home: BatteryDetailsPage()));
    await tester.pump();

    expect(find.text('最后同步'), findsOneWidget);
    expect(find.textContaining('同步'), findsWidgets);
  });
}
