import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart' as ble;
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/services/app_preferences_service.dart';
import 'package:tailg_ble_app/services/auto_connect_service.dart';
import 'package:tailg_ble_app/services/location_service.dart';
import 'package:tailg_ble_app/services/log_service.dart';
import 'package:tailg_ble_app/services/manual_mode_service.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/proximity_service.dart';
import 'package:tailg_ble_app/services/service_locator.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

void main() {
  tearDown(() async {
    await AppServices.reset();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('top-level service getters delegate to AppServices.instance', () {
    expect(
      identical(app.connectionManager, AppServices.instance.connectionManager),
      isTrue,
    );
    expect(identical(app.logService, AppServices.instance.logService), isTrue);
  });

  test('override swaps the whole graph and reset restores it', () async {
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
        appPreferencesService: AppPreferencesService(), // P0-6
      ),
    );

    expect(identical(app.connectionManager, injected), isTrue);

    await AppServices.reset();
    // After reset the graph is rebuilt, so it is neither the injected fake nor
    // (necessarily) the pre-test instance.
    expect(identical(app.connectionManager, injected), isFalse);
    expect(app.connectionManager, isA<ble.ConnectionManager>());
    expect(original, isA<ble.ConnectionManager>());
  });

  test('reset reports cleanup failures and still restores graph', () async {
    final messages = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };

    try {
      final injected = _ThrowingConnectionManager();
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
          appPreferencesService: AppPreferencesService(),
        ),
      );

      await AppServices.reset();

      expect(identical(app.connectionManager, injected), isFalse);
      expect(
        messages.any(
          (message) =>
              message.contains('connectionManager.dispose') &&
              message.contains('dispose failed'),
        ),
        isTrue,
      );
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  test(
    'reset keeps OfficialCloudService reusable and emitting state',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'official_cloud_token': 'token-before-reset',
        'official_cloud_phone': '18800001111',
        'official_cloud_user_id': 'user-before-reset',
      });
      final beforeReset = AppServices.instance.officialCloudService;
      final firstEvent = beforeReset.stateStream.first;

      await beforeReset.init();
      final initialEmitted = await firstEvent;

      expect(beforeReset.state.initialized, isTrue);
      expect(beforeReset.state.token, 'token-before-reset');
      expect(initialEmitted.initialized, isTrue);
      expect(initialEmitted.token, 'token-before-reset');

      FlutterSecureStorage.setMockInitialValues({
        'official_cloud_token': 'token-after-reset',
        'official_cloud_phone': '18800002222',
        'official_cloud_user_id': 'user-after-reset',
      });

      await AppServices.reset();

      final afterReset = AppServices.instance.officialCloudService;
      final nextEvent = afterReset.stateStream.first;

      await afterReset.init();

      final emitted = await nextEvent;
      expect(afterReset.state.initialized, isTrue);
      expect(afterReset.state.token, 'token-after-reset');
      expect(afterReset.state.phone, '18800002222');
      expect(afterReset.state.userId, 'user-after-reset');
      expect(emitted.token, 'token-after-reset');
    },
  );
}

class _ThrowingConnectionManager extends ble.ConnectionManager {
  @override
  Future<void> dispose() async {
    throw StateError('dispose failed');
  }
}
