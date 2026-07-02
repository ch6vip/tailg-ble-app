import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ble/connection_manager.dart' as ble;
import 'app_preferences_service.dart';
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
  final AppPreferencesService appPreferencesService; // P0-6: 注册到容器

  AppServices({
    required this.connectionManager,
    required this.proximityService,
    required this.autoConnectService,
    required this.manualModeService,
    required this.locationService,
    required this.logService,
    required this.vehicleStore,
    required this.officialCloudService,
    required this.appPreferencesService,
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
      appPreferencesService: AppPreferencesService(),
    );
  }

  static AppServices _instance = AppServices.production();

  /// The active service graph.
  static AppServices get instance => _instance;

  /// Replaces the active service graph. Intended for tests.
  @visibleForTesting
  static void override(AppServices services) => _instance = services;

  /// Restores the default production service graph. Intended for tests.
  ///
  /// P2-7: previously this called `dispose()` on each service, but most
  /// services are factory singletons (`ProximityService._instance` etc.) —
  /// `dispose()` closes their StreamControllers permanently, so the next
  /// `AppServices.production()` returned the same disposed "zombie"
  /// instances whose streams could no longer emit. We now call
  /// `resetForTest()` (which resets state without closing streams) on
  /// services that expose it, and only dispose non-singleton helpers such as
  /// the old [connectionManager].
  @visibleForTesting
  static Future<void> reset() async {
    final old = _instance;
    // Reset stateful singletons without killing their stream controllers.
    await _runCleanup(
      'proximityService.resetForTest',
      old.proximityService.resetForTest,
    );
    await _runCleanup(
      'autoConnectService.resetForTest',
      old.autoConnectService.resetForTest,
    );
    await _runCleanup(
      'manualModeService.resetForTest',
      old.manualModeService.resetForTest,
    );
    await _runCleanup(
      'vehicleStore.resetForTest',
      old.vehicleStore.resetForTest,
    );
    await _runCleanup(
      'appPreferencesService.resetForTest',
      old.appPreferencesService.resetForTest,
    );
    await _runCleanup(
      'officialCloudService.resetForTest',
      old.officialCloudService.resetForTest,
    );
    await _runCleanup(
      'connectionManager.dispose',
      old.connectionManager.dispose,
    );
    _instance = AppServices.production();
  }

  Future<void> dispose() async {
    await _runCleanup('connectionManager.dispose', connectionManager.dispose);
    await _runCleanup(
      'officialCloudService.dispose',
      officialCloudService.dispose,
    );
    await _runCleanup('proximityService.dispose', proximityService.dispose);
    await _runCleanup('autoConnectService.dispose', autoConnectService.dispose);
    await _runCleanup('manualModeService.dispose', manualModeService.dispose);
    await _runCleanup('vehicleStore.dispose', vehicleStore.dispose);
    await _runCleanup(
      'appPreferencesService.dispose',
      appPreferencesService.dispose,
    );
  }

  static Future<void> _runCleanup(
    String operation,
    FutureOr<void> Function() cleanup,
  ) async {
    try {
      await cleanup();
    } catch (error, stackTrace) {
      debugPrint('AppServices cleanup failed during $operation: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }
}
