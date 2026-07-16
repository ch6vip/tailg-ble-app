import 'geo_coordinate.dart';
import 'persistence_value.dart';

class VehicleLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime recordedAt;

  const VehicleLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.recordedAt,
  });

  String get coordinateText => formatCoordinateText(latitude, longitude);

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'recordedAt': recordedAt.toIso8601String(),
  };

  factory VehicleLocation.fromJson(
    Map<String, dynamic> json, {
    DateTime? fallbackRecordedAt,
  }) {
    return VehicleLocation(
      latitude: parsePersistedDouble(json['latitude']) ?? 0,
      longitude: parsePersistedDouble(json['longitude']) ?? 0,
      accuracy: parsePersistedDouble(json['accuracy']) ?? 0,
      recordedAt: parsePersistedDateOr(json['recordedAt'], fallbackRecordedAt),
    );
  }
}
