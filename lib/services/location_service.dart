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

  final _log = LogService();

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
      recordedAt: DateTime.now(),
    );
  }

  Future<VehicleLocation?> recordVehicleLocation(
    String vehicleId, {
    bool requestPermission = false,
  }) async {
    try {
      final location = await captureCurrentLocation(
        requestPermission: requestPermission,
      );
      await VehicleStore().updateLastLocation(vehicleId, location);
      _log.operation(
        '记录车辆位置',
        detail: '$vehicleId ${location.coordinateText}',
        level: LogLevel.info,
      );
      return location;
    } catch (e) {
      _log.operation('记录车辆位置失败', detail: e.toString(), level: LogLevel.debug);
      if (requestPermission) rethrow;
      return null;
    }
  }

  Future<VehicleLocation?> recordDefaultVehicleLocation({
    bool requestPermission = false,
  }) async {
    final vehicle = VehicleStore().defaultVehicle;
    if (vehicle == null) return null;
    return recordVehicleLocation(
      vehicle.id,
      requestPermission: requestPermission,
    );
  }
}
