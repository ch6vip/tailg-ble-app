import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tailg_ble_app/services/permission_service.dart';

import 'helpers/platform_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(clearPlatformChannelMock);

  test('returns a clear denial when location services are disabled', () async {
    mockGeolocator(serviceEnabled: false);

    final result = await AppPermissionService().ensureLocationPermission(
      request: true,
    );

    expect(result.granted, isFalse);
    expect(result.message, '定位服务未开启');
    expect(geolocatorMethodCalls, ['isLocationServiceEnabled']);
  });

  test('does not request permission when prompting is disabled', () async {
    mockGeolocator(
      serviceEnabled: true,
      checkedPermission: LocationPermission.denied,
    );

    final result = await AppPermissionService().ensureLocationPermission(
      request: false,
    );

    expect(result.granted, isFalse);
    expect(result.message, '未授予定位权限');
    expect(geolocatorMethodCalls, [
      'isLocationServiceEnabled',
      'checkPermission',
    ]);
  });

  test('requests a denied permission when prompting is enabled', () async {
    mockGeolocator(
      serviceEnabled: true,
      checkedPermission: LocationPermission.denied,
      requestedPermission: LocationPermission.whileInUse,
    );

    final result = await AppPermissionService().ensureLocationPermission(
      request: true,
    );

    expect(result.granted, isTrue);
    expect(result.message, isNull);
    expect(geolocatorMethodCalls, [
      'isLocationServiceEnabled',
      'checkPermission',
      'requestPermission',
    ]);
  });

  test(
    'reports permanently denied permission without prompting again',
    () async {
      mockGeolocator(
        serviceEnabled: true,
        checkedPermission: LocationPermission.deniedForever,
      );

      final result = await AppPermissionService().ensureLocationPermission(
        request: true,
      );

      expect(result.granted, isFalse);
      expect(result.message, '定位权限已被永久拒绝，请到系统设置开启');
      expect(geolocatorMethodCalls, [
        'isLocationServiceEnabled',
        'checkPermission',
      ]);
    },
  );

  test('accepts an already granted location permission', () async {
    mockGeolocator(
      serviceEnabled: true,
      checkedPermission: LocationPermission.always,
    );

    final result = await AppPermissionService().ensureLocationPermission(
      request: true,
    );

    expect(result.granted, isTrue);
    expect(result.message, isNull);
    expect(geolocatorMethodCalls, [
      'isLocationServiceEnabled',
      'checkPermission',
    ]);
  });
}
