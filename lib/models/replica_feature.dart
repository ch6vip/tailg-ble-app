import 'persistence_value.dart';

class NfcKeyRecord {
  final String id;
  final String name;
  final String type;
  final DateTime createdAt;

  const NfcKeyRecord({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'createdAt': createdAt.toIso8601String(),
  };

  factory NfcKeyRecord.fromJson(
    Map<String, dynamic> json, {
    DateTime? fallbackNow,
    DateTime Function()? clock,
  }) {
    return NfcKeyRecord(
      id: parsePersistedString(json['id']),
      name: parsePersistedStringOr(json['name'], '未命名钥匙'),
      type: parsePersistedStringOr(json['type'], '手机'),
      createdAt: parsePersistedDateOr(
        json['createdAt'],
        fallbackNow,
        clock: clock,
      ),
    );
  }

  NfcKeyRecord copyWith({String? name, String? type}) {
    return NfcKeyRecord(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      createdAt: createdAt,
    );
  }
}

class FenceConfig {
  final bool enabled;
  final double? latitude;
  final double? longitude;
  final int radiusMeters;
  final DateTime updatedAt;

  const FenceConfig({
    required this.enabled,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FenceConfig.fromJson(
    Map<String, dynamic> json, {
    DateTime? fallbackNow,
    DateTime Function()? clock,
  }) {
    return FenceConfig(
      enabled: parsePersistedBool(json['enabled']),
      latitude: parsePersistedDouble(json['latitude']),
      longitude: parsePersistedDouble(json['longitude']),
      radiusMeters: parsePersistedInt(json['radiusMeters']) ?? 500,
      updatedAt: parsePersistedDateOr(
        json['updatedAt'],
        fallbackNow,
        clock: clock,
      ),
    );
  }
}

class ShareMemberRecord {
  final String id;
  final String name;
  final String phone;
  final DateTime createdAt;

  const ShareMemberRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ShareMemberRecord.fromJson(
    Map<String, dynamic> json, {
    DateTime? fallbackNow,
    DateTime Function()? clock,
  }) {
    return ShareMemberRecord(
      id: parsePersistedString(json['id']),
      name: parsePersistedStringOr(json['name'], '未命名成员'),
      phone: parsePersistedString(json['phone']),
      createdAt: parsePersistedDateOr(
        json['createdAt'],
        fallbackNow,
        clock: clock,
      ),
    );
  }

  ShareMemberRecord copyWith({String? name, String? phone}) {
    return ShareMemberRecord(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      createdAt: createdAt,
    );
  }
}
