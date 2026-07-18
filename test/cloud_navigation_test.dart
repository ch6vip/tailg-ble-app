import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/add_vehicle_page.dart';
import 'package:tailg_ble_app/pages/login_page.dart';
import 'package:tailg_ble_app/services/app_navigation.dart';
import 'package:tailg_ble_app/services/app_preferences_service.dart';
import 'package:tailg_ble_app/services/auto_connect_service.dart';
import 'package:tailg_ble_app/services/location_service.dart';
import 'package:tailg_ble_app/services/log_service.dart';
import 'package:tailg_ble_app/services/manual_mode_service.dart';
import 'package:tailg_ble_app/services/message_read_store.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/official_mqtt_service.dart';
import 'package:tailg_ble_app/services/permission_service.dart';
import 'package:tailg_ble_app/services/service_locator.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';
import 'package:tailg_ble_app/widgets/cloud_vehicle_gate.dart';

import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';

void main() {
  late OfficialCloudService cloud;
  late ValueNotifier<int> homeTabIndex;

  setUp(() {
    resetMockStorage();
    LogService().resetForTest();
    cloud = OfficialCloudService()..resetForTest();
    homeTabIndex = ValueNotifier<int>(0);
    AppServices.override(
      AppServices(
        connectionManager: ConnectionManager(),
        autoConnectService: AutoConnectService(),
        manualModeService: ManualModeService(),
        locationService: LocationService(),
        logService: LogService(),
        vehicleStore: VehicleStore(),
        messageReadStore: MessageReadStore(),
        officialCloudService: cloud,
        officialMqttService: OfficialMqttService(),
        appPreferencesService: AppPreferencesService(),
        permissionService: AppPermissionService(),
        homeTabIndex: homeTabIndex,
      ),
    );
  });

  tearDown(() async {
    await AppServices.reset();
    LogService().resetForTest();
    resetMockStorage();
  });

  testWidgets('returnToVehicleHome pops to root and focuses the vehicle tab', (
    tester,
  ) async {
    cloud.setStateForTest(
      OfficialCloudState.initial().copyWith(initialized: true),
    );
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () =>
                          AppNavigation.returnToVehicleHome(context),
                      child: const Text('返回爱车'),
                    ),
                  ),
                ),
              ),
              child: const Text('打开详情'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开详情'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回爱车'));
    await tester.pumpAndSettle();

    expect(find.text('打开详情'), findsOneWidget);
    expect(find.text('返回爱车'), findsNothing);
    expect(homeTabIndex.value, AppNavigation.vehicleTabIndex);
    expect(cloud.lastRequest, isNull);
  });

  testWidgets('returnToVehicleHome can skip refresh', (tester) async {
    cloud.setStateForTest(
      OfficialCloudState.initial().copyWith(initialized: true, token: 'token'),
    );
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  AppNavigation.returnToVehicleHome(context, refresh: false),
              child: const Text('返回爱车'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('返回爱车'));
    await tester.pump();

    expect(homeTabIndex.value, AppNavigation.vehicleTabIndex);
    expect(cloud.lastRequest, isNull);
  });

  test('focusVehicleTabAfterSignOut selects the vehicle tab', () {
    homeTabIndex.value = 3;

    AppNavigation.focusVehicleTabAfterSignOut();

    expect(homeTabIndex.value, AppNavigation.vehicleTabIndex);
  });

  testWidgets('cloud vehicle gate passes a selected official vehicle', (
    tester,
  ) async {
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'selected-car',
      'carNickName': '当前车辆',
    });
    cloud.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
      ),
    );
    bool? allowed;
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => allowed = requireCloudVehicle(context),
              child: const Text('打开功能'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开功能'));
    await tester.pump();

    expect(allowed, isTrue);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(AddVehiclePage), findsNothing);
  });

  testWidgets('cloud vehicle gate routes signed-out users to login', (
    tester,
  ) async {
    cloud.setStateForTest(
      OfficialCloudState.initial().copyWith(initialized: true),
    );
    bool? allowed;
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => allowed = requireCloudVehicle(context),
              child: const Text('打开功能'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开功能'));
    await tester.pumpAndSettle();

    expect(allowed, isFalse);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('cloud vehicle gate routes signed-in users without a car', (
    tester,
  ) async {
    cloud.setStateForTest(
      OfficialCloudState.initial().copyWith(initialized: true, token: 'token'),
    );
    bool? allowed;
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => allowed = requireCloudVehicle(context),
              child: const Text('打开功能'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开功能'));
    await tester.pumpAndSettle();

    expect(allowed, isFalse);
    expect(find.byType(AddVehiclePage), findsOneWidget);
  });

  testWidgets('cloud vehicle gate respects disabled navigation offers', (
    tester,
  ) async {
    cloud.setStateForTest(
      OfficialCloudState.initial().copyWith(initialized: true),
    );
    bool? allowed;
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => allowed = requireCloudVehicle(
                context,
                offerLogin: false,
                message: '需要云端账号',
              ),
              child: const Text('打开功能'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开功能'));
    await tester.pump();

    expect(allowed, isFalse);
    expect(find.text('需要云端账号'), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });
}
