part of 'official_cloud_service.dart';

class OfficialCloudVehicleProfileData {
  final String id;
  final String name;
  final VehicleProtocol protocol;

  const OfficialCloudVehicleProfileData({
    required this.id,
    required this.name,
    required this.protocol,
  });
}

class OfficialCloudVehicleMapper {
  const OfficialCloudVehicleMapper._();

  static OfficialCloudVehicleProfileData? profileFromOfficialVehicle(
    OfficialVehicle vehicle,
  ) {
    final id = vehicle.normalizedBtmac;
    if (id.isEmpty) return null;
    return OfficialCloudVehicleProfileData(
      id: id,
      name: vehicle.displayName,
      protocol: _protocolForOfficialVehicle(vehicle),
    );
  }

  static VehicleProtocol _protocolForOfficialVehicle(OfficialVehicle vehicle) {
    final name = vehicle.btname.toUpperCase();
    if (name.startsWith('Q_BASH') ||
        name.startsWith('QGJ') ||
        name.startsWith('Q_')) {
      return VehicleProtocol.qgj;
    }
    return VehicleProtocol.auto;
  }
}
