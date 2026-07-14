import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/vehicle_location_resolver.dart';

void main() {
  OfficialCloudState state({
    OfficialVehicle? vehicle,
    OfficialVehicleLocation? location,
  }) {
    return OfficialCloudState.initial().copyWith(
      initialized: true,
      token: 'token',
      phone: '18812345678',
      userId: 'u1',
      vehicles: vehicle == null ? const [] : [vehicle],
      selectedVehicleKey: vehicle?.key,
      vehicleLocation: location,
    );
  }

  VehicleProfile localVehicle({
    double latitude = 30.0,
    double longitude = 120.0,
    double accuracy = 8,
  }) {
    final now = DateTime(2026, 7, 1, 12);
    return VehicleProfile(
      id: 'local-1',
      name: 'local',
      protocol: VehicleProtocol.qgj,
      createdAt: now,
      updatedAt: now,
      lastLocation: VehicleLocation(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        recordedAt: now,
      ),
    );
  }

  test('prefers official parking coordinates over vehicle and local', () {
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'c1',
      'latitude': '31.0',
      'longitude': '121.0',
    });
    final location = OfficialVehicleLocation.fromJson({
      'bleConnectLat': '31.2304',
      'bleConnectLng': '121.4737',
      'bleConnectTime': ' 10:00 ',
      'bleConnectAddress': ' 上海 ',
    });

    final resolved = resolveVehicleLocation(
      cloudState: state(vehicle: vehicle, location: location),
      localVehicle: localVehicle(),
    );

    expect(resolved?.source, '官方停车位置');
    expect(resolved?.latitude, 31.2304);
    expect(resolved?.longitude, 121.4737);
    expect(resolved?.timeLabel, '10:00');
    expect(resolved?.address, '上海');
    expect(resolved?.hasCoordinate, isTrue);
  });

  test('falls back to official vehicle coordinates then local', () {
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'c1',
      'latitude': '31.230400',
      'longitude': '121.473700',
    });

    final fromVehicle = resolveVehicleLocation(
      cloudState: state(vehicle: vehicle),
      localVehicle: localVehicle(),
    );
    expect(fromVehicle?.source, '官方车辆状态');
    expect(fromVehicle?.latitude, 31.2304);
    expect(fromVehicle?.longitude, 121.4737);

    final fromLocal = resolveVehicleLocation(
      cloudState: state(),
      localVehicle: localVehicle(accuracy: 5),
    );
    expect(fromLocal?.source, '本地记录');
    expect(fromLocal?.latitude, 30.0);
    expect(fromLocal?.accuracy, 5);
  });

  test('rejects near-zero pins and optionally keeps cloud metadata', () {
    final zeroLocation = OfficialVehicleLocation.fromJson({
      'bleConnectLat': '0.0000004',
      'bleConnectLng': '0.0000004',
      'bleConnectTime': '09:00',
      'bleConnectAddress': '无坐标',
    });

    expect(
      resolveVehicleLocation(cloudState: state(location: zeroLocation)),
      isNull,
    );

    final metadataOnly = resolveVehicleLocation(
      cloudState: state(location: zeroLocation),
      allowCloudMetadataWithoutCoordinate: true,
    );
    expect(metadataOnly?.hasCoordinate, isFalse);
    expect(metadataOnly?.source, '官方停车位置');
    expect(metadataOnly?.address, '无坐标');
    expect(metadataOnly?.timeLabel, '09:00');
  });
}
