import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/official_cloud_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

import 'helpers/source_scan.dart';
import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

void main() {
  test('OfficialCloudPage does not use empty setState refreshes', () {
    final source = readSource('lib/pages/official_cloud_page.dart');

    expect(source, isNot(contains('setState(() {})')));
    expect(source, contains('_syncInputState'));
  });

  test('self-check result branch uses a promoted local result', () {
    final source = readSource('lib/pages/official_cloud_page.dart');

    expect(source, contains('final result = _result;'));
    expect(source, contains('_SelfCheckResultCard(result: result)'));
    expect(source, isNot(contains('_SelfCheckResultCard(result: _result!)')));
  });

  test('page error helpers redact generic exception text', () {
    final source = readSource('lib/pages/official_cloud_page.dart');
    final helperStarts = RegExp(
      r'String _errorMessage\(Object e\)',
    ).allMatches(source).map((match) => match.start).toList();

    expect(helperStarts, hasLength(2));
    for (final start in helperStarts) {
      final end = source.indexOf('\n  @override', start);
      expect(end, greaterThan(start));
      final helperSource = source.substring(start, end);

      expect(helperSource, contains('OfficialCloudRedactor.errorMessage(e)'));
      expect(helperSource, isNot(contains('return e.toString();')));
    }
  });

  setUp(() {
    resetMockPreferences();
    app.vehicleStore.resetForTest();
    app.officialCloudService.resetForTest();
  });

  tearDown(() {
    app.vehicleStore.resetForTest();
    app.officialCloudService.resetForTest();
  });

  testWidgets('vehicle detail action keeps a 44dp touch target', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(430, 1200));

    final vehicle = OfficialVehicle.fromJson({
      'carId': 'official-1',
      'carName': '测试车辆',
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
    await tester.pump();

    expect(find.text('测试车辆'), findsOneWidget);
    final detailAction = find.ancestor(
      of: find.text('详情'),
      matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
    );
    expect(detailAction, findsOneWidget);
    expectMinTouchTargetHeight(tester, detailAction);
  });

  testWidgets('page renders official cloud error details', (tester) async {
    setTestViewSize(tester, const Size(430, 1200));
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(initialized: true, error: '官方服务异常'),
    );

    await tester.pumpWidget(const TestApp(home: OfficialCloudPage()));
    await tester.pump();

    expect(find.text('官方服务异常'), findsOneWidget);
  });

  testWidgets('self-check page renders local validation errors', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(430, 1200));
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'official-without-imei',
      'carName': '缺少 IMEI 车辆',
    });
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        userId: 'user-1',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
      ),
    );

    await tester.pumpWidget(
      TestApp(home: OfficialVehicleSelfCheckPage(vehicle: vehicle)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('当前车辆缺少官方 IMEI，无法云端自检'), findsOneWidget);
  });

  testWidgets('signed in page presents vehicle center first', (tester) async {
    setTestViewSize(tester, const Size(430, 1200));

    final vehicle = OfficialVehicle.fromJson({
      'carId': 'official-1',
      'carName': '测试车辆',
      'electricQuantity': 88,
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
    await tester.pump();

    expect(find.text('我的车辆'), findsOneWidget);
    expect(find.text('测试车辆'), findsOneWidget);
    expect(find.text('账号已登录'), findsOneWidget);
    expect(find.textContaining('登录后会同步账号下已绑定车辆'), findsOneWidget);
    expect(find.text('官方账号已登录'), findsNothing);
    expect(find.text('官方账号模式只使用'), findsNothing);
  });
}
