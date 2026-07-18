import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionCheckResult {
  final bool granted;
  final String? message;

  /// True when user must open system settings (permanent deny).
  final bool openSettingsRecommended;

  const PermissionCheckResult.granted()
    : granted = true,
      message = null,
      openSettingsRecommended = false;

  const PermissionCheckResult.denied(
    this.message, {
    this.openSettingsRecommended = false,
  }) : granted = false;
}

class AppPermissionService {
  static final AppPermissionService _instance = AppPermissionService._();
  factory AppPermissionService() => _instance;
  AppPermissionService._();

  /// BLE scan/connect permissions (Android 12+ Scan/Connect + location for older
  /// stacks / OEM scan requirements).
  ///
  /// When [request] is false, only checks current status and never prompts.
  Future<PermissionCheckResult> requestBleScanPermissions({
    bool request = true,
  }) async {
    const permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ];
    final Map<Permission, PermissionStatus> statuses;
    if (request) {
      statuses = await permissions.request();
    } else {
      statuses = {
        for (final permission in permissions)
          permission: await permission.status,
      };
    }
    final permanentlyBlocked = statuses.values.any(
      (status) => status.isPermanentlyDenied || status.isRestricted,
    );
    final blocked = statuses.values.any(
      (status) =>
          status.isDenied || status.isPermanentlyDenied || status.isRestricted,
    );
    if (blocked) {
      return PermissionCheckResult.denied(
        permanentlyBlocked ? '蓝牙/定位权限被永久拒绝，请到系统设置开启后重试' : '请授予蓝牙和定位权限后再扫描',
        openSettingsRecommended: permanentlyBlocked,
      );
    }
    return const PermissionCheckResult.granted();
  }

  Future<PermissionCheckResult> ensureLocationPermission({
    required bool request,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const PermissionCheckResult.denied(
        '定位服务未开启',
        openSettingsRecommended: true,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && request) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const PermissionCheckResult.denied('未授予定位权限');
    }
    if (permission == LocationPermission.deniedForever) {
      return const PermissionCheckResult.denied(
        '定位权限已被永久拒绝，请到系统设置开启',
        openSettingsRecommended: true,
      );
    }
    return const PermissionCheckResult.granted();
  }

  /// Opens system app settings so the user can re-grant BLE/location.
  Future<bool> openSystemSettings() => openAppSettings();
}
