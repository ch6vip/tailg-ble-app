import 'package:geolocator/geolocator.dart';

class PermissionCheckResult {
  final bool granted;
  final String? message;

  const PermissionCheckResult.granted() : granted = true, message = null;

  const PermissionCheckResult.denied(this.message) : granted = false;
}

class AppPermissionService {
  static final AppPermissionService _instance = AppPermissionService._();
  factory AppPermissionService() => _instance;
  AppPermissionService._();

  Future<PermissionCheckResult> ensureLocationPermission({
    required bool request,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const PermissionCheckResult.denied('定位服务未开启');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && request) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const PermissionCheckResult.denied('未授予定位权限');
    }
    if (permission == LocationPermission.deniedForever) {
      return const PermissionCheckResult.denied('定位权限已被永久拒绝，请到系统设置开启');
    }
    return const PermissionCheckResult.granted();
  }
}
