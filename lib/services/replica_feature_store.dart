import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/persistence_value.dart';
import 'log_service.dart';

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
      id: parsePersistedString(json['id']),
      name: parsePersistedString(json['name']).ifEmpty('未命名钥匙'),
      type: parsePersistedString(json['type']).ifEmpty('手机'),
      createdAt: parsePersistedDate(json['createdAt']) ?? DateTime.now(),
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
      enabled: _boolValue(json['enabled']),
      latitude: parsePersistedDouble(json['latitude']),
      longitude: parsePersistedDouble(json['longitude']),
      radiusMeters: parsePersistedInt(json['radiusMeters']) ?? 500,
      updatedAt: parsePersistedDate(json['updatedAt']) ?? DateTime.now(),
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
      id: parsePersistedString(json['id']),
      name: parsePersistedString(json['name']).ifEmpty('未命名成员'),
      phone: parsePersistedString(json['phone']),
      createdAt: parsePersistedDate(json['createdAt']) ?? DateTime.now(),
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
  static int _idCounter = 0;

  void _logWarning(String message, Object error) {
    LogService().operation(
      message,
      detail: error.toString(),
      level: LogLevel.warning,
    );
  }

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
    final decoded = _decodeMap(raw);
    if (decoded == null) return null;
    return FenceConfig.fromJson(decoded);
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

  String makeId() {
    _idCounter++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  List<T> _decodeList<T>(String? raw, T Function(Map<String, dynamic>) decode) {
    final decoded = _decodeJson(raw, 'ReplicaFeatureStore: JSON decode failed');
    if (decoded == null) return [];
    if (decoded is! List) {
      _logWarning(
        'ReplicaFeatureStore: expected list payload',
        decoded.runtimeType,
      );
      return [];
    }
    final records = <T>[];
    for (final item in decoded) {
      if (item is! Map) {
        _logWarning(
          'ReplicaFeatureStore: skipped list item with type',
          item.runtimeType,
        );
        continue;
      }
      try {
        records.add(decode(Map<String, dynamic>.from(item)));
      } catch (e) {
        _logWarning('ReplicaFeatureStore: decode list item failed', e);
        continue;
      }
    }
    return records;
  }

  Map<String, dynamic>? _decodeMap(String? raw) {
    final decoded = _decodeJson(raw, 'ReplicaFeatureStore: decode map failed');
    if (decoded == null) return null;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    _logWarning(
      'ReplicaFeatureStore: expected map payload',
      decoded.runtimeType,
    );
    return null;
  }

  Object? _decodeJson(String? raw, String errorMessage) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (e) {
      _logWarning(errorMessage, e);
      return null;
    }
  }

  Future<void> _saveList(
    String key,
    Iterable<Map<String, dynamic>> records,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(records.toList()));
  }
}

bool _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

extension _EmptyStringFallback on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
