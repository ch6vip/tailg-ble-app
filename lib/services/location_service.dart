import 'package:geolocator/geolocator.dart';

import '../models/vehicle_profile.dart';
import 'log_service.dart';
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
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationCaptureException('定位服务未开启');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationCaptureException('未授予定位权限');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationCaptureException('定位权限已被永久拒绝，请到系统设置开启');
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
