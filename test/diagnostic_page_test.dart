import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart' as ble;
import 'package:tailg_ble_app/pages/diagnostic_page.dart';
import 'package:tailg_ble_app/services/app_preferences_service.dart';
import 'package:tailg_ble_app/services/auto_connect_service.dart';
import 'package:tailg_ble_app/services/location_service.dart';
import 'package:tailg_ble_app/services/log_service.dart';
import 'package:tailg_ble_app/services/manual_mode_service.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/permission_service.dart';
import 'package:tailg_ble_app/services/proximity_service.dart';
import 'package:tailg_ble_app/services/service_locator.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

import 'helpers/snack_finders.dart';
import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';

void main() {
  tearDown(() async {
    await AppServices.reset();
    LogService().clear();
    resetMockPreferences();
  });

  testWidgets(
    'diagnostic action shows info snack when vehicle is disconnected',
    (tester) async {
      resetMockPreferences();

      await tester.pumpWidget(const TestApp(home: DiagnosticPage()));
      await tester.pump();

      await tester.tap(find.text('一键诊断'));
      await tester.pump();

      expect(find.text('请先连接车辆'), findsOneWidget);
      expect(snackIcon(Icons.info_outline), findsOneWidget);
    },
  );

  testWidgets('diagnostic result renders raw fault code', (tester) async {
    resetMockPreferences();
    _overrideConnectionManager(
      _DiagnosticConnectionManager([0, 0, 0, 0, 0, 0x21]),
    );

    await tester.pumpWidget(
      TestApp(home: DiagnosticPage(clock: () => DateTime(2026, 6, 9, 10, 30))),
    );
    await tester.pump();

    await tester.tap(find.text('一键诊断'));
    await tester.pump();
    await tester.pump();

    expect(find.text('检测到 2 个故障'), findsOneWidget);
    expect(find.text('原始码: 0x21'), findsOneWidget);
    expect(find.text('电机故障'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('diagnostic_history');
    expect(history, hasLength(1));
    expect(
      jsonDecode(history!.single),
      containsPair('time', '2026-06-09T10:30:00.000'),
    );
  });
}

void _overrideConnectionManager(ble.ConnectionManager connectionManager) {
  AppServices.override(
    AppServices(
      connectionManager: connectionManager,
      proximityService: ProximityService(),
      autoConnectService: AutoConnectService(),
      manualModeService: ManualModeService(),
      locationService: LocationService(),
      logService: LogService(),
      vehicleStore: VehicleStore(),
      officialCloudService: OfficialCloudService(),
      appPreferencesService: AppPreferencesService(),
      permissionService: AppPermissionService(),
      homeTabIndex: ValueNotifier<int>(1),
    ),
  );
}

class _DiagnosticConnectionManager extends ble.ConnectionManager {
  _DiagnosticConnectionManager(this._feb3Data);

  final List<int> _feb3Data;

  @override
  ble.ConnectionState get state => ble.ConnectionState.ready;

  @override
  Stream<ble.ConnectionState> get stateStream =>
      Stream<ble.ConnectionState>.empty();

  @override
  Future<List<int>?> readFeb3() async => _feb3Data;
}
