import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  factory NfcKeyRecord.fromJson(Map<String, dynamic> json) {
    return NfcKeyRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未命名钥匙',
      type: json['type'] as String? ?? '手机',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
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

  factory FenceConfig.fromJson(Map<String, dynamic> json) {
    return FenceConfig(
      enabled: json['enabled'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      radiusMeters: (json['radiusMeters'] as num?)?.toInt() ?? 500,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
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

  factory ShareMemberRecord.fromJson(Map<String, dynamic> json) {
    return ShareMemberRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未命名成员',
      phone: json['phone'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
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

class ReplicaFeatureStore {
  static final ReplicaFeatureStore _instance = ReplicaFeatureStore._();
  factory ReplicaFeatureStore() => _instance;
  ReplicaFeatureStore._();

  static const _prefNfcKeys = 'replica_nfc_keys';
  static const _prefFenceConfig = 'replica_fence_config';
  static const _prefShareMembers = 'replica_share_members';

  Future<List<NfcKeyRecord>> loadNfcKeys() async {
    final raw = (await SharedPreferences.getInstance()).getString(_prefNfcKeys);
    return _decodeList(raw, NfcKeyRecord.fromJson);
  }

  Future<void> saveNfcKeys(List<NfcKeyRecord> records) async {
    await _saveList(_prefNfcKeys, records.map((record) => record.toJson()));
  }

  Future<FenceConfig?> loadFenceConfig() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _prefFenceConfig,
    );
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return FenceConfig.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> saveFenceConfig(FenceConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefFenceConfig, jsonEncode(config.toJson()));
  }

  Future<List<ShareMemberRecord>> loadShareMembers() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _prefShareMembers,
    );
    return _decodeList(raw, ShareMemberRecord.fromJson);
  }

  Future<void> saveShareMembers(List<ShareMemberRecord> records) async {
    await _saveList(
      _prefShareMembers,
      records.map((record) => record.toJson()),
    );
  }

  String makeId() => DateTime.now().microsecondsSinceEpoch.toString();

  List<T> _decodeList<T>(String? raw, T Function(Map<String, dynamic>) decode) {
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => decode(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<void> _saveList(
    String key,
    Iterable<Map<String, dynamic>> records,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(records.toList()));
  }
}
