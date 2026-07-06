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
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  static Iterable<Map<String, dynamic>> _maps(
    Object? data, {
    bool wrapSingle = false,
  }) {
    return _payloadItems(
      data,
      wrapSingle: wrapSingle,
    ).whereType<Map<Object?, Object?>>().map(Map<String, dynamic>.from);
  }

  static Iterable<Object?> _payloadItems(
    Object? data, {
    required bool wrapSingle,
  }) {
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
