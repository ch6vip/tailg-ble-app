import 'package:flutter/foundation.dart';

import '../ble/connection_manager.dart' as ble;
import 'auto_connect_service.dart';
import 'location_service.dart';
import 'log_service.dart';
import 'manual_mode_service.dart';
import 'official_cloud_service.dart';
import 'proximity_service.dart';
import 'vehicle_store.dart';

/// Central registry for the app's long-lived services.
///
/// Previously these lived as scattered top-level mutable singletons in
/// `main.dart`, which made the dependency graph implicit and hard to swap out in
/// tests. [AppServices] gathers them into a single injectable container:
///
/// * production code reads them through [AppServices.instance] (the top-level
///   getters in `main.dart` now delegate here, so existing call sites are
///   unchanged);
/// * tests can swap the whole graph for fakes via [AppServices.override] and
///   restore it with [AppServices.reset].
///
/// Construction stays side-effect free — async wiring (`init()`, credential
/// application, target-device selection) remains the caller's responsibility in
/// `main()`, exactly as before.
class AppServices {
  final ble.ConnectionManager connectionManager;
  final ProximityService proximityService;
  final AutoConnectService autoConnectService;
  final ManualModeService manualModeService;
  final LocationService locationService;
  final LogService logService;
  final VehicleStore vehicleStore;
  final OfficialCloudService officialCloudService;

  AppServices({
    required this.connectionManager,
    required this.proximityService,
    required this.autoConnectService,
    required this.manualModeService,
    required this.locationService,
    required this.logService,
    required this.vehicleStore,
    required this.officialCloudService,
  });

  /// Builds the default production graph. Most of these types are themselves
  /// internal singletons; [ble.ConnectionManager] is a plain instance and this
  /// is its single owner.
  factory AppServices.production() {
    return AppServices(
      connectionManager: ble.ConnectionManager(),
      proximityService: ProximityService(),
      autoConnectService: AutoConnectService(),
      manualModeService: ManualModeService(),
      locationService: LocationService(),
      logService: LogService(),
      vehicleStore: VehicleStore(),
      officialCloudService: OfficialCloudService(),
    );
  }

  static AppServices _instance = AppServices.production();

  /// The active service graph.
  static AppServices get instance => _instance;

  /// Replaces the active service graph. Intended for tests.
  @visibleForTesting
  static void override(AppServices services) => _instance = services;

  /// Restores the default production service graph. Intended for tests.
  @visibleForTesting
  static void reset() => _instance = AppServices.production();
}
