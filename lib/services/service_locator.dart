import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ble/connection_manager.dart' as ble;
import 'app_preferences_service.dart';
import 'auto_connect_service.dart';
import 'location_service.dart';
import 'log_service.dart';
import 'manual_mode_service.dart';
import 'message_read_store.dart';
import 'official_cloud_service.dart';
import 'official_mqtt_service.dart';
import 'permission_service.dart';
import 'vehicle_store.dart';

/// Central registry for the app's long-lived services.
///
/// Production code reads services through [AppServices.instance]; tests can
/// swap the whole graph via [AppServices.override] and restore with
/// [AppServices.reset].
class AppServices {
  final ble.ConnectionManager connectionManager;
  final AutoConnectService autoConnectService;
  final ManualModeService manualModeService;
  final LocationService locationService;
  final LogService logService;
  final VehicleStore vehicleStore;
  final MessageReadStore messageReadStore;
  final OfficialCloudService officialCloudService;
  final OfficialMqttService officialMqttService;
  final AppPreferencesService appPreferencesService;
  final AppPermissionService permissionService;
  final ValueNotifier<int> homeTabIndex;

  AppServices({
    required this.connectionManager,
    required this.autoConnectService,
    required this.manualModeService,
    required this.locationService,
    required this.logService,
    required this.vehicleStore,
    required this.messageReadStore,
    required this.officialCloudService,
    OfficialMqttService? officialMqttService,
    required this.appPreferencesService,
    required this.permissionService,
    required this.homeTabIndex,
  }) : officialMqttService = officialMqttService ?? OfficialMqttService();

  factory AppServices.production() {
    return AppServices(
      connectionManager: ble.ConnectionManager(),
      autoConnectService: AutoConnectService(),
      manualModeService: ManualModeService(),
      locationService: LocationService(),
      logService: LogService(),
      vehicleStore: VehicleStore(),
      messageReadStore: MessageReadStore(),
      officialCloudService: OfficialCloudService(),
      officialMqttService: OfficialMqttService(),
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
      'autoConnectService.resetForTest',
      old.autoConnectService.resetForTest,
    );
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
      'messageReadStore.resetForTest',
      old.messageReadStore.resetForTest,
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
      'officialMqttService.resetForTest',
      old.officialMqttService.resetForTest,
    );
    await _runCleanup(
      'connectionManager.dispose',
      old.connectionManager.dispose,
    );
    await _runCleanup('homeTabIndex.dispose', old.homeTabIndex.dispose);
    _instance = AppServices.production();
  }

  Future<void> dispose() async {
    await _runCleanup(
      'officialMqttService.dispose',
      officialMqttService.dispose,
    );
    await _runCleanup('connectionManager.dispose', connectionManager.dispose);
    await _runCleanup(
      'officialCloudService.dispose',
      officialCloudService.dispose,
    );
    await _runCleanup('autoConnectService.dispose', autoConnectService.dispose);
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
