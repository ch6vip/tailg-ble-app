import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/pages/location_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/source_scan.dart';
import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/typography.dart';
import 'helpers/view_size.dart';

void main() {
  test('LocationPage routes vehicle and cloud streams through notifiers', () {
    final source = readSource('lib/pages/location_page.dart');
    final vehiclesListener = _listenerBlock(
      source,
      'vehicleStore.vehiclesStream.listen',
    );
    final cloudListener = _listenerBlock(
      source,
      'officialCloudService.stateStream.listen',
    );

    expect(source, contains('ValueNotifier<OfficialCloudState>'));
    expect(source, contains('ValueNotifier<List<VehicleProfile>>'));
    expect(source, isNot(contains('setState(() {})')));

    expect(vehiclesListener, contains('_vehiclesNotifier.value = v'));
    expect(vehiclesListener, isNot(contains('setState')));
    expect(cloudListener, contains('_cloudStateNotifier.value = c'));
    expect(cloudListener, isNot(contains('setState')));
  });

  test('LocationPage keeps map tab isolated behind RepaintBoundary', () {
    final source = readSource('lib/pages/location_page.dart');

    expect(
      RegExp(r'RepaintBoundary\(\s*child:\s*_MapTab\(').hasMatch(source),
      isTrue,
      reason:
          'The map tab should stay behind RepaintBoundary so parent '
          'rebuilds do not repaint FlutterMap.',
    );
  });

  testWidgets('LocationPage segmented tabs keep 44dp touch targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    resetMockPreferences();
    setTestViewSize(tester, const Size(430, 1200));

    try {
      await tester.pumpWidget(
        const TestApp(home: LocationPage(embedded: true)),
      );
      await tester.pump();

      final locationTab = find.ancestor(
        of: find.text('位置'),
        matching: find.byType(AppPressable),
      );
      expect(locationTab, findsOneWidget);
      expectMinTouchTargetHeight(tester, locationTab);
      expect(
        tester.getSemantics(find.bySemanticsLabel('位置')),
        matchesSemantics(
          label: '位置',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('轨迹')),
        matchesSemantics(
          label: '轨迹',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasSelectedState: true,
          isSelected: false,
        ),
      );

      const refreshLabel = '刷新';
      final refreshAction = find.bySemanticsLabel(refreshLabel);
      expect(refreshAction, findsOneWidget);
      expectMinTouchTargetHeight(tester, refreshAction);
      expect(
        tester.getSemantics(refreshAction),
        matchesSemantics(
          label: refreshLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel('轨迹'));
      await tester.pump();

      expect(find.text('历史轨迹'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('轨迹')),
        matchesSemantics(
          label: '轨迹',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('LocationPage travel month controls keep 44dp touch targets', (
    tester,
  ) async {
    resetMockPreferences();
    setTestViewSize(tester, const Size(430, 1200));

    await tester.pumpWidget(
      const TestApp(
        home: LocationPage(
          initialTab: LocationInitialTab.travel,
          embedded: true,
        ),
      ),
    );
    await tester.pump();

    final previousMonth = find.byTooltip('上个月');
    expect(previousMonth, findsOneWidget);
    expectMinTouchTargetHeight(tester, previousMonth);
  });

  testWidgets('LocationPage travel month fallback uses injected clock', (
    tester,
  ) async {
    resetMockPreferences();
    app.officialCloudService.resetForTest();
    addTearDown(app.officialCloudService.resetForTest);
    setTestViewSize(tester, const Size(430, 1200));

    final vehicle = OfficialVehicle.fromJson({
      'carId': 'official-travel-bike',
      'carName': '测试车辆',
    });

    await tester.pumpWidget(
      TestApp(
        home: LocationPage(
          initialTab: LocationInitialTab.travel,
          embedded: true,
          clock: () => DateTime(2026, 7, 15),
        ),
      ),
    );
    await tester.pump();
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        userId: '',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('上个月'));
    await tester.pump();

    expect(app.officialCloudService.state.travelMonth, '2026-06');
    expect(find.text('2026-06'), findsOneWidget);
  });

  testWidgets('LocationPage travel tab renders cloud error details', (
    tester,
  ) async {
    resetMockPreferences();
    app.officialCloudService.resetForTest();
    addTearDown(app.officialCloudService.resetForTest);
    setTestViewSize(tester, const Size(430, 1200));

    await tester.pumpWidget(
      const TestApp(
        home: LocationPage(
          initialTab: LocationInitialTab.travel,
          embedded: true,
        ),
      ),
    );
    await tester.pump();
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        userId: 'uid',
        travelError: '官方服务异常',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('历史轨迹暂不可用'), findsOneWidget);
    expect(find.text('官方服务异常'), findsOneWidget);
  });

  testWidgets('LocationPage map tab renders official parking location', (
    tester,
  ) async {
    resetMockPreferences();
    app.officialCloudService.resetForTest();
    addTearDown(app.officialCloudService.resetForTest);
    setTestViewSize(tester, const Size(430, 1400));

    final vehicle = OfficialVehicle.fromJson({
      'carId': 'official-map-bike',
      'carName': '测试车辆',
    });
    final location = OfficialVehicleLocation.fromJson({
      'bleConnectTime': '2026-05-29 10:00:00',
      'bleConnectLat': '31.230400',
      'bleConnectLng': '121.473700',
      'carId': 'official-map-bike',
      'bleConnectAddress': '停车点',
    });
    final fence = OfficialFenceData.fromJson({
      'fenceRadius': '5',
      'fenceSwitch': '1',
    });

    await tester.pumpWidget(const TestApp(home: LocationPage(embedded: true)));
    await tester.pump();
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        userId: 'uid',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
        vehicleLocation: location,
        fenceData: fence,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('停车点'), findsWidgets);
    expect(find.text('官方停车位置'), findsWidgets);
    expect(find.text('2026-05-29 10:00:00'), findsOneWidget);
    expect(find.text('已开启'), findsOneWidget);
    expect(find.byType(CircleLayer), findsOneWidget);
  });

  testWidgets('LocationPage map tab renders cloud location error', (
    tester,
  ) async {
    resetMockPreferences();
    app.officialCloudService.resetForTest();
    addTearDown(app.officialCloudService.resetForTest);
    setTestViewSize(tester, const Size(430, 1200));

    await tester.pumpWidget(const TestApp(home: LocationPage(embedded: true)));
    await tester.pump();
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        userId: 'uid',
        vehicleLocationError: '定位服务异常',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('官方车辆暂无坐标'), findsOneWidget);
    expect(find.text('定位服务异常'), findsOneWidget);
  });

  testWidgets('LocationPage fence sheet renders local fallback and error', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'replica_fence_config':
          '{"enabled":true,"latitude":31.2304,"longitude":121.4737,"radiusMeters":800,"updatedAt":"2026-07-03T12:30:00.000"}',
    });
    app.officialCloudService.resetForTest();
    addTearDown(app.officialCloudService.resetForTest);
    setTestViewSize(tester, const Size(430, 1200));

    await tester.pumpWidget(
      const TestApp(
        home: LocationPage(
          initialTab: LocationInitialTab.fence,
          embedded: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        userId: 'uid',
        fenceError: '围栏服务异常',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('本地围栏：已开启 · 800m'), findsOneWidget);
    expect(find.text('围栏服务异常'), findsOneWidget);
  });

  testWidgets('LocationPage meta values avoid negative letter spacing', (
    tester,
  ) async {
    resetMockPreferences();
    app.vehicleStore.resetForTest();
    addTearDown(app.vehicleStore.resetForTest);

    await app.vehicleStore.upsert(
      id: 'vehicle-1',
      name: '测试车辆',
      protocol: VehicleProtocol.qgj,
      makeDefault: true,
    );
    await app.vehicleStore.updateLastLocation(
      'vehicle-1',
      VehicleLocation(
        latitude: 31.2304,
        longitude: 121.4737,
        accuracy: 8.5,
        recordedAt: DateTime(2026, 7, 3, 12, 30),
      ),
    );

    await tester.pumpWidget(const TestApp(home: LocationPage(embedded: true)));
    await tester.pump();

    final accuracySpacing = tester
        .widget<Text>(find.text('±9m'))
        .style
        ?.letterSpacing;

    expect(accuracySpacing, nonNegativeLetterSpacing);
  });

  testWidgets('LocationPage travel records expose semantics action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    resetMockPreferences();
    app.officialCloudService.resetForTest();
    addTearDown(app.officialCloudService.resetForTest);
    setTestViewSize(tester, const Size(430, 1400));

    const travelRecord = OfficialTravelRecord(
      raw: {},
      hours: '0',
      carName: '测试车辆',
      averageSpeed: '25',
      deviceTravelId: 'travel-1',
      sec: '0',
      min: '15',
      travelDate: '2026-07-01',
      imei: '',
      days: '',
      startTime: '08:00',
      endTime: '08:15',
      mileage: '12.5',
      frame: '',
      maxSpeed: '',
    );
    const travelDay = OfficialTravelDay(
      raw: {},
      sec: '',
      hours: '',
      min: '',
      travelDate: '2026-07-01',
      totalTime: '15m',
      records: [travelRecord],
      days: '',
      totalMileage: '12.5',
    );
    final travelState = OfficialCloudState.initial().copyWith(
      initialized: true,
      token: 'token',
      userId: 'uid',
      travelMonth: '2026-07',
      travelDays: [travelDay],
      travelDetails: {'travel-1': const []},
    );

    try {
      await tester.pumpWidget(
        const TestApp(
          home: LocationPage(
            initialTab: LocationInitialTab.travel,
            embedded: true,
          ),
        ),
      );
      await tester.pump();
      app.officialCloudService.setStateForTest(travelState);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('12.5km'), findsOneWidget);
      await tester.ensureVisible(find.text('12.5km'));
      await tester.pump();
      const recordLabel = '轨迹记录，08:00 至 08:15，12.5km，25km/h，15m，0 点';
      final recordAction = find.bySemanticsLabel(recordLabel);
      expect(recordAction, findsOneWidget);
      expectMinTouchTargetHeight(tester, recordAction);
      expect(
        tester.getSemantics(recordAction),
        matchesSemantics(
          label: recordLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(recordLabel));
      await tester.pumpAndSettle();

      expect(find.text('未返回轨迹点'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('LocationPage travel detail previews first 12 track points', (
    tester,
  ) async {
    resetMockPreferences();
    app.officialCloudService.resetForTest();
    addTearDown(app.officialCloudService.resetForTest);
    setTestViewSize(tester, const Size(430, 3000));

    const travelRecord = OfficialTravelRecord(
      raw: {},
      hours: '0',
      carName: '测试车辆',
      averageSpeed: '25',
      deviceTravelId: 'travel-1',
      sec: '0',
      min: '15',
      travelDate: '2026-07-01',
      imei: '',
      days: '',
      startTime: '08:00',
      endTime: '08:15',
      mileage: '12.5',
      frame: '',
      maxSpeed: '',
    );
    const travelDay = OfficialTravelDay(
      raw: {},
      sec: '',
      hours: '',
      min: '',
      travelDate: '2026-07-01',
      totalTime: '15m',
      records: [travelRecord],
      days: '',
      totalMileage: '12.5',
    );
    final points = List.generate(13, (index) => _travelPoint(index + 1));
    final travelState = OfficialCloudState.initial().copyWith(
      initialized: true,
      token: 'token',
      userId: 'uid',
      travelMonth: '2026-07',
      travelDays: [travelDay],
      travelDetails: {'travel-1': points},
    );

    await tester.pumpWidget(
      const TestApp(
        home: LocationPage(
          initialTab: LocationInitialTab.travel,
          embedded: true,
        ),
      ),
    );
    await tester.pump();
    app.officialCloudService.setStateForTest(travelState);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    await tester.ensureVisible(find.text('12.5km'));
    await tester.pump();
    await tester.tap(find.text('12.5km'));
    await tester.pumpAndSettle();

    expect(find.text('13'), findsOneWidget);
    expect(find.text('31.001, 121.001'), findsOneWidget);
    expect(find.text('31.012, 121.012'), findsOneWidget);
    expect(find.text('31.013, 121.013'), findsNothing);
  });
}

OfficialTravelPoint _travelPoint(int index) {
  final suffix = index.toString().padLeft(3, '0');
  final minute = index.toString().padLeft(2, '0');
  return OfficialTravelPoint(
    raw: const <String, dynamic>{},
    lng: '121.$suffix',
    heading: '',
    starsNum: '',
    lat: '31.$suffix',
    reportTime: '08:$minute',
    speed: '',
  );
}

String _listenerBlock(String source, String listenerStart) {
  final start = source.indexOf(listenerStart);
  expect(start, isNot(-1), reason: 'Missing $listenerStart');

  final end = source.indexOf('});', start);
  expect(end, isNot(-1), reason: 'Missing end of $listenerStart block');

  return source.substring(start, end + 3);
}
