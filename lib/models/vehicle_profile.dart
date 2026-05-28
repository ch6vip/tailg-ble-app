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
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      recordedAt:
          DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
          DateTime.now(),
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

  VehicleProfile copyWith({
    String? name,
    VehicleProtocol? protocol,
    DateTime? updatedAt,
    DateTime? lastConnectedAt,
    VehicleLocation? lastLocation,
    int? qgjLoginPassword,
    int? qgjUserId,
    bool clearQgjCredentials = false,
  }) {
    return VehicleProfile(
      id: id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      lastLocation: lastLocation ?? this.lastLocation,
      qgjLoginPassword: clearQgjCredentials
          ? null
          : qgjLoginPassword ?? this.qgjLoginPassword,
      qgjUserId: clearQgjCredentials ? null : qgjUserId ?? this.qgjUserId,
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
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      protocol: VehicleProtocol.fromValue(json['protocol'] as String?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
      lastConnectedAt: DateTime.tryParse(
        json['lastConnectedAt'] as String? ?? '',
      ),
      lastLocation: locationJson is Map
          ? VehicleLocation.fromJson(Map<String, dynamic>.from(locationJson))
          : null,
      qgjLoginPassword: (json['qgjLoginPassword'] as num?)?.toInt(),
      qgjUserId: (json['qgjUserId'] as num?)?.toInt(),
    );
  }
}
