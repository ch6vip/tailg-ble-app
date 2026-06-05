import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart' as ble;
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/services/auto_connect_service.dart';
import 'package:tailg_ble_app/services/location_service.dart';
import 'package:tailg_ble_app/services/log_service.dart';
import 'package:tailg_ble_app/services/manual_mode_service.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/proximity_service.dart';
import 'package:tailg_ble_app/services/service_locator.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

void main() {
  tearDown(AppServices.reset);

  test('top-level service getters delegate to AppServices.instance', () {
    expect(
      identical(app.connectionManager, AppServices.instance.connectionManager),
      isTrue,
    );
    expect(identical(app.logService, AppServices.instance.logService), isTrue);
  });

  test('override swaps the whole graph and reset restores it', () {
    final original = AppServices.instance.connectionManager;

    final injected = ble.ConnectionManager();
    AppServices.override(
      AppServices(
        connectionManager: injected,
        proximityService: ProximityService(),
        autoConnectService: AutoConnectService(),
        manualModeService: ManualModeService(),
        locationService: LocationService(),
        logService: LogService(),
        vehicleStore: VehicleStore(),
        officialCloudService: OfficialCloudService(),
      ),
    );

    expect(identical(app.connectionManager, injected), isTrue);

    AppServices.reset();
    // After reset the graph is rebuilt, so it is neither the injected fake nor
    // (necessarily) the pre-test instance.
    expect(identical(app.connectionManager, injected), isFalse);
    expect(app.connectionManager, isA<ble.ConnectionManager>());
    expect(original, isA<ble.ConnectionManager>());
  });
}
