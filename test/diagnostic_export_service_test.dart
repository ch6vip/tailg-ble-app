import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart' as ble;
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
}
