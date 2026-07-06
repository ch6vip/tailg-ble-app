import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart' as ble;
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/services/diagnostic_export_service.dart';
import 'package:tailg_ble_app/services/log_service.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

void main() {
  test('DiagnosticExportService uses injected report time', () async {
    final connectionManager = ble.ConnectionManager();
    addTearDown(connectionManager.dispose);
    LogService().clear();
    VehicleStore().resetForTest();
    OfficialCloudService().resetForTest();
    addTearDown(LogService().clear);
    addTearDown(VehicleStore().resetForTest);
    addTearDown(OfficialCloudService().resetForTest);

    final generatedAt = DateTime(2026, 6, 1, 8, 30);
    final service = DiagnosticExportService(
      connectionManager: connectionManager,
      logService: LogService(),
      vehicleStore: VehicleStore(),
      officialCloudService: OfficialCloudService(),
      clock: () => generatedAt,
    );

    final lines = service.buildReport(const []).split('\n');

    expect(lines[0], '# Tailg BLE Diagnostic Report');
    expect(lines[1], 'Generated: ${generatedAt.toIso8601String()}');
  });

  test('DiagnosticExportService includes evicted log count in heading', () {
    final connectionManager = ble.ConnectionManager();
    addTearDown(connectionManager.dispose);
    LogService().clear();
    VehicleStore().resetForTest();
    OfficialCloudService().resetForTest();
    addTearDown(LogService().clear);
    addTearDown(VehicleStore().resetForTest);
    addTearDown(OfficialCloudService().resetForTest);

    final logService = LogService();
    for (var index = 0; index < 2001; index++) {
      logService.operation('entry $index');
    }
    final service = DiagnosticExportService(
      connectionManager: connectionManager,
      logService: logService,
      vehicleStore: VehicleStore(),
      officialCloudService: OfficialCloudService(),
      clock: () => DateTime(2026, 6, 1, 8, 30),
    );

    final lines = service.buildReport(logService.all).split('\n');

    expect(lines, contains('## Logs (2000) [1 older entries evicted]'));
  });

  test(
    'DiagnosticExportService includes selected official vehicle details',
    () {
      final connectionManager = ble.ConnectionManager();
      addTearDown(connectionManager.dispose);
      LogService().clear();
      VehicleStore().resetForTest();
      OfficialCloudService().resetForTest();
      addTearDown(LogService().clear);
      addTearDown(VehicleStore().resetForTest);
      addTearDown(OfficialCloudService().resetForTest);

      final vehicle = OfficialVehicle.fromJson({
        'carId': 'official-car-123456',
        'carNickName': '通勤车',
        'defenceStatus': 1,
        'acc': 1,
        'electricQuantity': 87,
        'voltage': 52.4,
        'modelType': 3,
        'imei': '123456789012345',
        'imeiGps': '987654321098765',
        'btname': 'TAILG-BLE',
        'btmac': 'AA:BB:CC:DD:EE:FF',
        'latitude': '31.2304',
        'longitude': '121.4737',
      });
      OfficialCloudService().setStateForTest(
        OfficialCloudState.initial().copyWith(
          initialized: true,
          token: 'token',
          phone: '18800001111',
          vehicles: [vehicle],
          selectedVehicleKey: vehicle.key,
          localVehicleLinks: {vehicle.key: 'AA:BB:CC:DD:EE:FF'},
          batteryInfo: OfficialBatteryInfo.fromJson({
            'dumpEnergyPercentLabel': '86%',
            'voltage': '52.3',
            'temperature': '31.2',
          }),
        ),
      );
      final service = DiagnosticExportService(
        connectionManager: connectionManager,
        logService: LogService(),
        vehicleStore: VehicleStore(),
        officialCloudService: OfficialCloudService(),
        clock: () => DateTime(2026, 6, 1, 8, 30),
      );

      final lines = service.buildReport(const []).split('\n');

      expect(lines, contains('Selected vehicle: 通勤车'));
      expect(lines, contains('Selected key: off***456'));
      expect(lines, contains('Linked local vehicle: AA:***:FF'));
      expect(lines, contains('Online: false'));
      expect(lines, contains('Defence: 已设防'));
      expect(lines, contains('ACC: 车辆已启动'));
      expect(lines, contains('Official vehicle battery: 87%'));
      expect(lines, contains('Official vehicle voltage: 52.4V'));
      expect(lines, contains('ModelType: 3'));
      expect(lines, contains('Command IMEI: 987***765'));
      expect(lines, contains('BT name: TAILG-BLE'));
      expect(lines, contains('BT MAC: AA:***:FF'));
      expect(lines, contains('Location: present (hidden)'));
      expect(lines, contains('Official battery detail: 86%'));
      expect(lines, contains('Official battery detail voltage: 52.3V'));
      expect(lines, contains('Official battery detail temperature: 31.2C'));
    },
  );

  test('DiagnosticExportService redacts official cloud error details', () {
    final connectionManager = ble.ConnectionManager();
    addTearDown(connectionManager.dispose);
    LogService().clear();
    VehicleStore().resetForTest();
    OfficialCloudService().resetForTest();
    addTearDown(LogService().clear);
    addTearDown(VehicleStore().resetForTest);
    addTearDown(OfficialCloudService().resetForTest);

    OfficialCloudService().setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        error:
            'sync failed token=abcdef123456 userId=user-secret password=qgj-secret',
      ),
    );
    final service = DiagnosticExportService(
      connectionManager: connectionManager,
      logService: LogService(),
      vehicleStore: VehicleStore(),
      officialCloudService: OfficialCloudService(),
      clock: () => DateTime(2026, 6, 1, 8, 30),
    );

    final report = service.buildReport(const []);

    expect(
      report,
      contains(
        'Error: sync failed token=abc***456 userId=use***ret '
        'password=qgj***ret',
      ),
    );
    expect(report, isNot(contains('abcdef123456')));
    expect(report, isNot(contains('user-secret')));
    expect(report, isNot(contains('qgj-secret')));
  });
}
