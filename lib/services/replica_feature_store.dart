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

  factory NfcKeyRecord.fromJson(
    Map<String, dynamic> json, {
    DateTime? fallbackNow,
  }) {
    return NfcKeyRecord(
      id: parsePersistedString(json['id']),
      name: parsePersistedStringOr(json['name'], '未命名钥匙'),
      type: parsePersistedStringOr(json['type'], '手机'),
      createdAt: _replicaTimestamp(json['createdAt'], fallbackNow),
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
  }) {
    return FenceConfig(
      enabled: parsePersistedBool(json['enabled']),
      latitude: parsePersistedDouble(json['latitude']),
      longitude: parsePersistedDouble(json['longitude']),
      radiusMeters: parsePersistedInt(json['radiusMeters']) ?? 500,
      updatedAt: _replicaTimestamp(json['updatedAt'], fallbackNow),
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
  }) {
    return ShareMemberRecord(
      id: parsePersistedString(json['id']),
      name: parsePersistedStringOr(json['name'], '未命名成员'),
      phone: parsePersistedString(json['phone']),
      createdAt: _replicaTimestamp(json['createdAt'], fallbackNow),
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

DateTime _replicaTimestamp(Object? value, DateTime? fallbackNow) {
  return parsePersistedDate(value) ?? fallbackNow ?? DateTime.now();
}

class ReplicaFeatureStore {
  static final ReplicaFeatureStore _instance = ReplicaFeatureStore._();
  factory ReplicaFeatureStore() => _instance;
  ReplicaFeatureStore._();

  static const _prefNfcKeys = 'replica_nfc_keys';
  static const _prefFenceConfig = 'replica_fence_config';
  static const _prefShareMembers = 'replica_share_members';
  static int _idCounter = 0;
  DateTime Function() _clock = DateTime.now;

  void resetForTest({DateTime Function()? clock}) {
    _clock = clock ?? DateTime.now;
    _idCounter = 0;
  }

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
    return FenceConfig.fromJson(decoded, fallbackNow: _clock());
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

  String makeId({DateTime? now}) {
    _idCounter++;
    return '${(now ?? _clock()).microsecondsSinceEpoch}_$_idCounter';
  }

  List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic>, {DateTime? fallbackNow}) decode,
  ) {
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
    final fallbackNow = _clock();
    for (final item in decoded) {
      final record = _decodeListItem(item, decode, fallbackNow);
      if (record != null) records.add(record);
    }
    return records;
  }

  T? _decodeListItem<T>(
    Object? item,
    T Function(Map<String, dynamic>, {DateTime? fallbackNow}) decode,
    DateTime fallbackNow,
  ) {
    if (item is! Map) {
      _logWarning(
        'ReplicaFeatureStore: skipped list item with type',
        item.runtimeType,
      );
      return null;
    }
    try {
      final payload = parsePersistedMap(item);
      return payload == null ? null : decode(payload, fallbackNow: fallbackNow);
    } catch (e) {
      _logWarning('ReplicaFeatureStore: decode list item failed', e);
      return null;
    }
  }

  Map<String, dynamic>? _decodeMap(String? raw) {
    final decoded = _decodeJson(raw, 'ReplicaFeatureStore: decode map failed');
    return _decodeMapPayload(decoded);
  }

  Map<String, dynamic>? _decodeMapPayload(Object? decoded) {
    if (decoded == null) return null;
    final payload = parsePersistedMap(decoded);
    if (payload != null) return payload;
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
