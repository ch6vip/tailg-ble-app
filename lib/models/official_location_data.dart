import '../services/display_number_formatter.dart';
import 'persistence_value.dart';

class OfficialVehicleLocation {
  final Map<String, dynamic> raw;
  final String extendId;
  final String bleConnectTime;
  final String bleConnectLat;
  final String bleConnectLng;
  final String carId;
  final String bleConnectAddress;

  const OfficialVehicleLocation({
    required this.raw,
    required this.extendId,
    required this.bleConnectTime,
    required this.bleConnectLat,
    required this.bleConnectLng,
    required this.carId,
    required this.bleConnectAddress,
  });

  factory OfficialVehicleLocation.fromJson(Map<String, dynamic> json) {
    return OfficialVehicleLocation(
      raw: _stringKeyedMap(json),
      extendId: _clean(json['extendId']) ?? '',
      bleConnectTime: _clean(json['bleConnectTime']) ?? '',
      bleConnectLat: _clean(json['bleConnectLat']) ?? '',
      bleConnectLng: _clean(json['bleConnectLng']) ?? '',
      carId: _clean(json['carId']) ?? '',
      bleConnectAddress: _clean(json['bleConnectAddress']) ?? '',
    );
  }

  bool get hasData =>
      bleConnectLat.isNotEmpty ||
      bleConnectLng.isNotEmpty ||
      bleConnectAddress.isNotEmpty ||
      bleConnectTime.isNotEmpty;

  double? get latitude => _double(bleConnectLat);
  double? get longitude => _double(bleConnectLng);

  static double? _double(String value) => parsePersistedDouble(value);
}

class OfficialFenceData {
  final Map<String, dynamic> raw;
  final String fenceRadius;
  final String fenceRadiusMax;
  final String fenceRadiusMin;
  final String fenceSwitch;
  final String fenceTimeFr;
  final String fenceTimeTo;

  const OfficialFenceData({
    required this.raw,
    required this.fenceRadius,
    required this.fenceRadiusMax,
    required this.fenceRadiusMin,
    required this.fenceSwitch,
    required this.fenceTimeFr,
    required this.fenceTimeTo,
  });

  factory OfficialFenceData.fromJson(Map<String, dynamic> json) {
    return OfficialFenceData(
      raw: _stringKeyedMap(json),
      fenceRadius: _clean(json['fenceRadius'] ?? json['range']) ?? '',
      fenceRadiusMax: _clean(json['fenceRadiusMax']) ?? '',
      fenceRadiusMin: _clean(json['fenceRadiusMin']) ?? '',
      fenceSwitch: _clean(json['fenceSwitch']) ?? '',
      fenceTimeFr: _clean(json['fenceTimeFr']) ?? '',
      fenceTimeTo: _clean(json['fenceTimeTo']) ?? '',
    );
  }

  bool get hasData =>
      fenceRadius.isNotEmpty ||
      fenceRadiusMax.isNotEmpty ||
      fenceRadiusMin.isNotEmpty ||
      fenceSwitch.isNotEmpty ||
      fenceTimeFr.isNotEmpty ||
      fenceTimeTo.isNotEmpty;

  bool get enabled => fenceSwitch == '1' || fenceSwitch.toLowerCase() == 'true';

  String get statusLabel {
    if (fenceSwitch.isEmpty) return '待读取';
    return enabled ? '已开启' : '已关闭';
  }

  String get radiusLabel {
    final meters = radiusMeters;
    if (meters == null) return fenceRadius.isEmpty ? '待读取' : fenceRadius;
    return formatDistanceMeters(meters);
  }

  double? get radiusMeters {
    if (fenceRadius.isEmpty) return null;
    final value = double.tryParse(fenceRadius);
    if (value == null) return null;
    return value * 100;
  }

  String get timeLabel {
    if (fenceTimeFr.isEmpty && fenceTimeTo.isEmpty) return '待读取';
    return '${fenceTimeFr.isEmpty ? '--' : fenceTimeFr} - ${fenceTimeTo.isEmpty ? '--' : fenceTimeTo}';
  }
}

String? _clean(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text == '--' || text.toLowerCase() == 'null') {
    return null;
  }
  return text;
}

Map<String, dynamic> _stringKeyedMap(Map<Object?, Object?> value) {
  return Map<String, dynamic>.unmodifiable(parsePersistedMap(value)!);
}
