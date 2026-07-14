import '../models/geo_coordinate.dart';
import '../models/vehicle_profile.dart';
import 'display_time_formatter.dart';
import 'official_cloud_service.dart';

/// Shared near-zero filter for official/local vehicle coordinates.
const vehicleCoordinateTolerance = 0.000001;

/// Resolved vehicle location shared by map/home surfaces.
///
/// Latitude/longitude may be null when [allowCloudMetadataWithoutCoordinate]
/// is enabled and official parking payload has address/time but no usable pin.
class ResolvedVehicleLocation {
  const ResolvedVehicleLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timeLabel,
    required this.address,
    required this.source,
  });

  final double? latitude;
  final double? longitude;
  final double accuracy;
  final String timeLabel;
  final String address;
  final String source;

  bool get hasCoordinate {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return false;
    return !isZeroCoordinate(lat, lng, tolerance: vehicleCoordinateTolerance);
  }

  String get coordinateText {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return '';
    return formatCoordinateText(lat, lng);
  }
}

/// Resolve display location with fixed priority:
/// official parking pin → official vehicle lat/lng → local last location.
///
/// When [allowCloudMetadataWithoutCoordinate] is true, an official parking
/// payload that has time/address but no usable pin is still returned so home
/// cards can show "has data" placeholders.
ResolvedVehicleLocation? resolveVehicleLocation({
  required OfficialCloudState cloudState,
  VehicleProfile? localVehicle,
  bool allowCloudMetadataWithoutCoordinate = false,
}) {
  final cloudLocation = cloudState.vehicleLocation;
  if (cloudLocation != null) {
    final cloudLat = cloudLocation.latitude;
    final cloudLng = cloudLocation.longitude;
    if (cloudLat != null &&
        cloudLng != null &&
        !isZeroCoordinate(
          cloudLat,
          cloudLng,
          tolerance: vehicleCoordinateTolerance,
        )) {
      return ResolvedVehicleLocation(
        latitude: cloudLat,
        longitude: cloudLng,
        accuracy: 0,
        timeLabel: cloudLocation.bleConnectTime.trim(),
        address: cloudLocation.bleConnectAddress.trim(),
        source: '官方停车位置',
      );
    }
    if (allowCloudMetadataWithoutCoordinate && cloudLocation.hasData) {
      return ResolvedVehicleLocation(
        latitude: null,
        longitude: null,
        accuracy: 0,
        timeLabel: cloudLocation.bleConnectTime.trim(),
        address: cloudLocation.bleConnectAddress.trim(),
        source: '官方停车位置',
      );
    }
  }

  final officialVehicle = cloudState.selectedVehicle;
  final vehicleLat = double.tryParse(officialVehicle?.latitude ?? '');
  final vehicleLng = double.tryParse(officialVehicle?.longitude ?? '');
  if (vehicleLat != null &&
      vehicleLng != null &&
      !isZeroCoordinate(
        vehicleLat,
        vehicleLng,
        tolerance: vehicleCoordinateTolerance,
      )) {
    return ResolvedVehicleLocation(
      latitude: vehicleLat,
      longitude: vehicleLng,
      accuracy: 0,
      timeLabel: '',
      address: '',
      source: '官方车辆状态',
    );
  }

  final local = localVehicle?.lastLocation;
  if (local != null &&
      !isZeroCoordinate(
        local.latitude,
        local.longitude,
        tolerance: vehicleCoordinateTolerance,
      )) {
    return ResolvedVehicleLocation(
      latitude: local.latitude,
      longitude: local.longitude,
      accuracy: local.accuracy,
      timeLabel: formatDateMinuteText(local.recordedAt),
      address: '',
      source: '本地记录',
    );
  }

  return null;
}
