import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_preferences_service.dart';
import 'location_service.dart';
import 'log_service.dart';
import 'manual_mode_service.dart';
import 'official_cloud_service.dart';
import 'permission_service.dart';
import 'vehicle_store.dart';

class AppServices {
  final ManualModeService manualModeService;
  final LocationService locationService;
  final LogService logService;
  final VehicleStore vehicleStore;
  final OfficialCloudService officialCloudService;
  final AppPreferencesService appPreferencesService;
  final AppPermissionService permissionService;
  final ValueNotifier<int> homeTabIndex;

  AppServices({
    required this.manualModeService,
    required this.locationService,
    required this.logService,
    required this.vehicleStore,
    required this.officialCloudService,
    required this.appPreferencesService,
    required this.permissionService,
    required this.homeTabIndex,
  });

  factory AppServices.production() {
    return AppServices(
      manualModeService: ManualModeService(),
      locationService: LocationService(),
      logService: LogService(),
      vehicleStore: VehicleStore(),
      officialCloudService: OfficialCloudService(),
      appPreferencesService: AppPreferencesService(),
      permissionService: AppPermissionService(),
      homeTabIndex: ValueNotifier<int>(1),
    );
  }

  static AppServices _instance = AppServices.production();

  static AppServices get instance => _instance;

  @visibleForTesting
  static void override(AppServices services) => _instance = services;

  @visibleForTesting
  static Future<void> reset() async {
    final old = _instance;
    await _runCleanup(
      'manualModeService.resetForTest',
      old.manualModeService.resetForTest,
    );
    await _runCleanup(
      'locationService.resetForTest',
      old.locationService.resetForTest,
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
    await _runCleanup('homeTabIndex.dispose', old.homeTabIndex.dispose);
    _instance = AppServices.production();
  }

  Future<void> dispose() async {
    await _runCleanup(
      'officialCloudService.dispose',
      officialCloudService.dispose,
    );
    await _runCleanup('manualModeService.dispose', manualModeService.dispose);
    await _runCleanup('vehicleStore.dispose', vehicleStore.dispose);
    await _runCleanup(
      'appPreferencesService.dispose',
      appPreferencesService.dispose,
    );
    await _runCleanup('homeTabIndex.dispose', homeTabIndex.dispose);
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
