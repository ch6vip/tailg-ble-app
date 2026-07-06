part of 'official_cloud_service.dart';

class OfficialCloudDataParser {
  const OfficialCloudDataParser._();

  static List<OfficialVehicle> vehicles(Object? data) {
    return _maps(data, wrapSingle: true)
        .map(OfficialVehicle.fromJson)
        .where(_hasVehicleIdentity)
        .toList(growable: false);
  }

  static OfficialBatteryInfo batteryInfo(Object? data) {
    return OfficialBatteryInfo.fromJson(_map(data));
  }

  static OfficialVehicleLocation vehicleLocation(Object? data) {
    return OfficialVehicleLocation.fromJson(_map(data));
  }

  static OfficialFenceData fenceData(Object? data) {
    return OfficialFenceData.fromJson(_map(data));
  }

  static List<OfficialTravelDay> travelDays(Object? data) {
    return _maps(data)
        .map(OfficialTravelDay.fromJson)
        .where((day) => day.hasData)
        .toList(growable: false);
  }

  static List<OfficialTravelPoint> travelPoints(Object? data) {
    return _maps(data)
        .map(OfficialTravelPoint.fromJson)
        .where((point) => point.hasCoordinate)
        .toList(growable: false);
  }

  static Map<String, dynamic> _map(Object? data) {
    return data is Map<Object?, Object?>
        ? _officialCloudPayloadMap(data)
        : const {};
  }

  static Iterable<Map<String, dynamic>> _maps(
    Object? data, {
    bool wrapSingle = false,
  }) {
    return parsePersistedMapList(_payloadItems(data, wrapSingle: wrapSingle));
  }

  static List<Object?> _payloadItems(Object? data, {required bool wrapSingle}) {
    if (data is List) return data.cast<Object?>();
    if (wrapSingle && data != null) return <Object?>[data];
    return const <Object?>[];
  }

  static bool _hasVehicleIdentity(OfficialVehicle vehicle) {
    return vehicle.carId.isNotEmpty ||
        vehicle.imei.isNotEmpty ||
        vehicle.imeiGps.isNotEmpty ||
        vehicle.btmac.isNotEmpty ||
        vehicle.btname.isNotEmpty ||
        vehicle.carName.isNotEmpty ||
        vehicle.frame.isNotEmpty;
  }
}

Map<String, dynamic> _officialCloudPayloadMap(Map<Object?, Object?> data) {
  return parsePersistedMap(data)!;
}
