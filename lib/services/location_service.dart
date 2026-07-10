import 'package:geolocator/geolocator.dart';

import '../models/vehicle_profile.dart';
import 'log_service.dart';
import 'permission_service.dart';
import 'vehicle_store.dart';

class LocationCaptureException implements Exception {
  final String message;
  const LocationCaptureException(this.message);

  @override
  String toString() => message;
}

class LocationService {
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  LocationService._();

  static const silentCaptureThrottle = Duration(seconds: 60);

  final _log = LogService();
  final _lastSilentCaptures = <String, DateTime>{};
  DateTime Function() _clock = DateTime.now;

  void resetForTest({DateTime Function()? clock}) {
    _lastSilentCaptures.clear();
    _clock = clock ?? DateTime.now;
  }

  Future<VehicleLocation> captureCurrentLocation({
    bool requestPermission = false,
  }) async {
    final permission = await AppPermissionService().ensureLocationPermission(
      request: requestPermission,
    );
    if (!permission.granted) {
      throw LocationCaptureException(permission.message ?? '定位权限不可用');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );

    return VehicleLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      recordedAt: _clock(),
    );
  }

  Future<VehicleLocation?> recordVehicleLocation(
    String vehicleId, {
    bool requestPermission = false,
  }) async {
    final normalizedId = vehicleId.trim();
    if (normalizedId.isEmpty) return null;
    final store = VehicleStore();
    try {
      await store.init();
      final throttledLocation = _throttledLocation(
        store,
        normalizedId,
        requestPermission: requestPermission,
      );
      if (throttledLocation != null) return throttledLocation;

      final location = await captureCurrentLocation(
        requestPermission: requestPermission,
      );
      await store.updateLastLocation(normalizedId, location);
      if (!requestPermission) {
        _lastSilentCaptures[normalizedId] = location.recordedAt;
      }
      _log.operation(
        '记录车辆位置',
        detail: '$normalizedId ${location.coordinateText}',
        level: LogLevel.info,
      );
      return location;
    } catch (e) {
      _log.operation('记录车辆位置失败', detail: e.toString(), level: LogLevel.debug);
      if (requestPermission) rethrow;
      return null;
    }
  }

  VehicleLocation? _throttledLocation(
    VehicleStore store,
    String vehicleId, {
    required bool requestPermission,
  }) {
    if (requestPermission) return null;

    final now = _clock();
    final lastCapture = _lastSilentCaptures[vehicleId];
    if (lastCapture != null &&
        now.difference(lastCapture) < silentCaptureThrottle) {
      return _cachedLocation(store, vehicleId);
    }

    final cached = _cachedLocation(store, vehicleId);
    if (cached != null &&
        now.difference(cached.recordedAt) < silentCaptureThrottle) {
      _lastSilentCaptures[vehicleId] = cached.recordedAt;
      _log.operation('记录车辆位置已节流', detail: vehicleId, level: LogLevel.debug);
      return cached;
    }

    return null;
  }

  VehicleLocation? _cachedLocation(VehicleStore store, String vehicleId) {
    for (final vehicle in store.vehicles) {
      if (vehicle.id == vehicleId) return vehicle.lastLocation;
    }
    return null;
  }

  Future<VehicleLocation?> recordDefaultVehicleLocation({
    bool requestPermission = false,
  }) async {
    final store = VehicleStore();
    await store.init();
    final vehicle = store.defaultVehicle;
    if (vehicle == null) return null;
    return recordVehicleLocation(
      vehicle.id,
      requestPermission: requestPermission,
    );
  }
}
