import 'persistence_value.dart';
import 'vehicle_location.dart';

export 'vehicle_location.dart';

enum VehicleProtocol {
  auto('auto', '自动识别'),
  standard('standard', 'Standard'),
  qgj('qgj', 'QGJ');

  final String value;
  final String label;
  const VehicleProtocol(this.value, this.label);

  static VehicleProtocol fromValue(String? value) {
    return VehicleProtocol.values.firstWhere(
      (protocol) => protocol.value == value,
      orElse: () => VehicleProtocol.auto,
    );
  }
}

class VehicleProfile {
  final String id;
  final String name;
  final VehicleProtocol protocol;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastConnectedAt;
  final VehicleLocation? lastLocation;

  const VehicleProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.createdAt,
    required this.updatedAt,
    this.lastConnectedAt,
    this.lastLocation,
  });

  String get displayName => parsePersistedStringOr(name, '未命名车辆');

  VehicleProfile copyWith({
    String? name,
    VehicleProtocol? protocol,
    DateTime? updatedAt,
    DateTime? lastConnectedAt,
    VehicleLocation? lastLocation,
  }) {
    return VehicleProfile(
      id: id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      lastLocation: lastLocation ?? this.lastLocation,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'protocol': protocol.value,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastConnectedAt': lastConnectedAt?.toIso8601String(),
    'lastLocation': lastLocation?.toJson(),
  };

  factory VehicleProfile.fromJson(
    Map<String, dynamic> json, {
    DateTime? fallbackNow,
    DateTime Function()? clock,
  }) {
    final now = fallbackNow ?? (clock ?? DateTime.now)();
    return VehicleProfile(
      id: parsePersistedString(json['id']),
      name: parsePersistedString(json['name']),
      protocol: VehicleProtocol.fromValue(
        parsePersistedString(json['protocol']),
      ),
      createdAt: parsePersistedDateOr(json['createdAt'], now),
      updatedAt: parsePersistedDateOr(json['updatedAt'], now),
      lastConnectedAt: parsePersistedDate(json['lastConnectedAt']),
      lastLocation: _vehicleLocation(json['lastLocation'], fallbackNow: now),
    );
  }
}

VehicleLocation? _vehicleLocation(Object? value, {DateTime? fallbackNow}) {
  final json = parsePersistedMap(value);
  return json == null
      ? null
      : VehicleLocation.fromJson(json, fallbackRecordedAt: fallbackNow);
}
