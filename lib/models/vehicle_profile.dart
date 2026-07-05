import 'persistence_value.dart';

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

  String get coordinateText =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'recordedAt': recordedAt.toIso8601String(),
  };

  factory VehicleLocation.fromJson(Map<String, dynamic> json) {
    return VehicleLocation(
      latitude: _doubleValue(json['latitude']) ?? 0,
      longitude: _doubleValue(json['longitude']) ?? 0,
      accuracy: _doubleValue(json['accuracy']) ?? 0,
      recordedAt: parsePersistedDate(json['recordedAt']) ?? DateTime.now(),
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
  final int? qgjLoginPassword;
  final int? qgjUserId;

  const VehicleProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.createdAt,
    required this.updatedAt,
    this.lastConnectedAt,
    this.lastLocation,
    this.qgjLoginPassword,
    this.qgjUserId,
  });

  String get displayName => name.trim().isEmpty ? '未命名车辆' : name.trim();
  bool get hasQgjCredentials => qgjLoginPassword != null || qgjUserId != null;

  static const _sentinel = Object();

  VehicleProfile copyWith({
    String? name,
    VehicleProtocol? protocol,
    DateTime? updatedAt,
    DateTime? lastConnectedAt,
    VehicleLocation? lastLocation,
    Object? qgjLoginPassword = _sentinel,
    Object? qgjUserId = _sentinel,
    bool clearQgjCredentials = false,
  }) {
    final resolvedQgjPassword = identical(qgjLoginPassword, _sentinel)
        ? (clearQgjCredentials ? null : this.qgjLoginPassword)
        : qgjLoginPassword as int?;
    final resolvedQgjUserId = identical(qgjUserId, _sentinel)
        ? (clearQgjCredentials ? null : this.qgjUserId)
        : qgjUserId as int?;
    return VehicleProfile(
      id: id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      lastLocation: lastLocation ?? this.lastLocation,
      qgjLoginPassword: resolvedQgjPassword,
      qgjUserId: resolvedQgjUserId,
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
    'qgjLoginPassword': qgjLoginPassword,
    'qgjUserId': qgjUserId,
  };

  factory VehicleProfile.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final locationJson = json['lastLocation'];
    return VehicleProfile(
      id: _stringValue(json['id']),
      name: _stringValue(json['name']),
      protocol: VehicleProtocol.fromValue(_stringValue(json['protocol'])),
      createdAt: parsePersistedDate(json['createdAt']) ?? now,
      updatedAt: parsePersistedDate(json['updatedAt']) ?? now,
      lastConnectedAt: parsePersistedDate(json['lastConnectedAt']),
      lastLocation: locationJson is Map
          ? VehicleLocation.fromJson(Map<String, dynamic>.from(locationJson))
          : null,
      qgjLoginPassword: _intValue(json['qgjLoginPassword']),
      qgjUserId: _intValue(json['qgjUserId']),
    );
  }
}

String _stringValue(Object? value) {
  return value?.toString().trim() ?? '';
}

double? _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int? _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
