import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/garage_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';

import 'helpers/source_scan.dart';
import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

void main() {
  setUp(() async {
    resetMockStorage();
    app.vehicleStore.resetForTest();
    app.officialCloudService.resetForTest();
    app.homeTabIndex.value = 2;
    await app.vehicleStore.init();
  });

  tearDown(() {
    app.vehicleStore.resetForTest();
    app.officialCloudService.resetForTest();
    app.homeTabIndex.value = 1;
  });

  test('garage errors redact exception details before display', () {
    final source = readSource('lib/pages/garage_page.dart');

    expect(source, contains('OfficialCloudRedactor.errorMessage(e)'));
    expect(source, isNot(contains('e is OfficialCloudApiException')));
  });

  testWidgets('signed-out garage keeps official search and add structure', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(390, 844));

    await tester.pumpWidget(const TestApp(home: GaragePage()));
    await tester.pump();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      CyberHomeColors.pageBg,
    );
    expect(find.text('我的车库'), findsNothing);
    expect(find.byKey(const ValueKey('garage-search-field')), findsOneWidget);
    expect(find.text('点击卡片选择设备'), findsOneWidget);
    expect(find.text('登录并添加爱车'), findsOneWidget);
    expect(find.text('登录后查看我的车库'), findsOneWidget);
    expectMinTouchTargetHeight(
      tester,
      find.byKey(const ValueKey('garage-back')),
    );
    expectMinTouchTargetHeight(
      tester,
      find.byKey(const ValueKey('garage-add')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-in garage renders official GarageV2 vehicle card', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(390, 844));
    final vehicle = _vehicle(
      carId: 'garage-1',
      nickName: '追风',
      using: true,
      shareCount: 2,
    );
    _setSignedIn([vehicle]);
    _stubGaragePage([vehicle]);

    await tester.pumpWidget(const TestApp(home: GaragePage(embedded: true)));
    await tester.pumpAndSettle();

    expect(find.text('追风'), findsOneWidget);
    expect(find.text('使用中'), findsOneWidget);
    expect(find.text('在线'), findsOneWidget);
    expect(find.text('车主车辆'), findsOneWidget);
    expect(find.text('已分享 2 次'), findsOneWidget);
    expect(find.bySemanticsLabel('车辆码'), findsOneWidget);
    expect(find.bySemanticsLabel('修改'), findsOneWidget);
    expect(find.bySemanticsLabel('解绑'), findsOneWidget);
    expect(find.text('账号车辆'), findsNothing);
    expect(find.text('本地存档'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-in garage cross-fades skeleton into loaded content', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(390, 844));
    final completion = Completer<OfficialGaragePage>();
    _setSignedIn(const []);
    app.officialCloudService.fetchGaragePageOverride =
        ({required pageIndex, required frame, required shareUserPhone}) {
          return completion.future;
        };

    await tester.pumpWidget(const TestApp(home: GaragePage(embedded: true)));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('garage-loading-skeleton')),
      findsOneWidget,
    );

    completion.complete(
      const OfficialGaragePage(
        vehicles: [],
        pageIndex: 1,
        pageSize: 5,
        total: 0,
        hasNext: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('garage-loading-skeleton')), findsNothing);
  });

  testWidgets('frame search sends official GarageV2 search values', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(390, 844));
    final calls = <Map<String, Object>>[];
    _setSignedIn(const []);
    app.officialCloudService.fetchGaragePageOverride =
        ({required pageIndex, required frame, required shareUserPhone}) async {
          calls.add({
            'pageIndex': pageIndex,
            'frame': frame,
            'shareUserPhone': shareUserPhone,
          });
          return const OfficialGaragePage(
            vehicles: [],
            pageIndex: 1,
            pageSize: 5,
            total: 0,
            hasNext: false,
          );
        };

    await tester.pumpWidget(const TestApp(home: GaragePage(embedded: true)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('garage-search-field')),
      'VIN123456',
    );
    await tester.tap(find.byKey(const ValueKey('garage-search')));
    await tester.pumpAndSettle();

    expect(calls.last, {
      'pageIndex': 1,
      'frame': 'VIN123456',
      'shareUserPhone': '',
    });
  });

  testWidgets('shared vehicle hides owner-only operations', (tester) async {
    setTestViewSize(tester, const Size(390, 844));
    final vehicle = _vehicle(
      carId: 'shared-1',
      nickName: '好友的车',
      using: true,
      shared: true,
    );
    _setSignedIn([vehicle]);
    _stubGaragePage([vehicle]);

    await tester.pumpWidget(const TestApp(home: GaragePage(embedded: true)));
    await tester.pumpAndSettle();

    expect(find.text('好友车辆'), findsOneWidget);
    expect(find.bySemanticsLabel('车辆码'), findsNothing);
    expect(find.bySemanticsLabel('解绑'), findsNothing);
    expect(find.bySemanticsLabel('修改'), findsOneWidget);
  });

  testWidgets('vehicle code action opens frame QR sheet', (tester) async {
    setTestViewSize(tester, const Size(390, 844));
    final vehicle = _vehicle(
      carId: 'code-1',
      nickName: '车辆码测试车',
      using: true,
      frame: 'FRAME12345',
    );
    _setSignedIn([vehicle]);
    _stubGaragePage([vehicle]);

    await tester.pumpWidget(const TestApp(home: GaragePage(embedded: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('车辆码'));
    await tester.pumpAndSettle();

    expect(find.text('车架号：FRAME12345'), findsOneWidget);
    expect(find.text('车辆码'), findsWidgets);
  });

  testWidgets('switch confirmation dispatches official changeUsingCar flow', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(390, 844));
    final current = _vehicle(carId: 'current-1', nickName: '当前车辆', using: true);
    final target = _vehicle(carId: 'target-2', nickName: '目标车辆');
    _setSignedIn([current, target]);
    _stubGaragePage([current, target]);
    OfficialVehicle? changedTo;
    app.officialCloudService.changeUsingVehicleOverride = (vehicle) async {
      changedTo = vehicle;
    };

    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const GaragePage()),
              ),
              child: const Text('打开车库'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开车库'));
    await tester.pumpAndSettle();
    final targetCard = find.bySemanticsLabel('目标车辆，点击切换');
    await tester.ensureVisible(targetCard);
    await tester.pumpAndSettle();
    await tester.tap(targetCard);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认切换'));
    await tester.pumpAndSettle();

    expect(changedTo?.carId, 'target-2');
    expect(find.byType(GaragePage), findsNothing);
    expect(app.homeTabIndex.value, 1);
  });

  testWidgets('unbind requires matching middle four phone digits', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(390, 844));
    final vehicle = _vehicle(carId: 'unbind-1', nickName: '待解绑车辆', using: true);
    _setSignedIn([vehicle], phone: '13812345678');
    _stubGaragePage([vehicle]);
    String? unboundId;
    int? unbindType;
    app.officialCloudService.unbindVehicleOverride = (carId, type) async {
      unboundId = carId;
      unbindType = type;
    };

    await tester.pumpWidget(const TestApp(home: GaragePage(embedded: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('解绑'));
    await tester.pumpAndSettle();
    expect(find.textContaining('138****5678'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '1234');
    await tester.tap(find.text('确认解绑'));
    await tester.pumpAndSettle();

    expect(unboundId, 'unbind-1');
    expect(unbindType, 1);
  });
}

OfficialVehicle _vehicle({
  required String carId,
  required String nickName,
  bool using = false,
  bool shared = false,
  int shareCount = 0,
  String frame = 'FRAME0001',
}) {
  return OfficialVehicle.fromJson({
    'carId': carId,
    'carNickName': nickName,
    'carName': 'TL-智能款',
    'frame': frame,
    'online': true,
    'isUsing': using,
    'shareCarFlag': shared,
    'shareCount': shareCount,
  });
}

void _setSignedIn(
  List<OfficialVehicle> vehicles, {
  String phone = '13812345678',
}) {
  app.officialCloudService.setStateForTest(
    OfficialCloudState.initial().copyWith(
      initialized: true,
      token: 'test-token',
      phone: phone,
      vehicles: vehicles,
      selectedVehicleKey: vehicles.isEmpty ? null : vehicles.first.key,
    ),
  );
}

void _stubGaragePage(List<OfficialVehicle> vehicles) {
  app.officialCloudService.fetchGaragePageOverride =
      ({required pageIndex, required frame, required shareUserPhone}) async {
        return OfficialGaragePage(
          vehicles: vehicles,
          pageIndex: pageIndex,
          pageSize: 5,
          total: vehicles.length,
          hasNext: false,
        );
      };
}
