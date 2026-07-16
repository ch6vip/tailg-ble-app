import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/persistence_value.dart';
import '../models/replica_feature.dart';
import 'log_service.dart';

export '../models/replica_feature.dart';

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

  NfcKeyRecord createNfcKey({required String name, required String type}) {
    final now = _clock();
    return NfcKeyRecord(
      id: makeId(now: now),
      name: name,
      type: type,
      createdAt: now,
    );
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

  FenceConfig createFenceConfig({
    required bool enabled,
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) {
    return FenceConfig(
      enabled: enabled,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      updatedAt: _clock(),
    );
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

  ShareMemberRecord createShareMember({
    required String name,
    required String phone,
  }) {
    final now = _clock();
    return ShareMemberRecord(
      id: makeId(now: now),
      name: name,
      phone: phone,
      createdAt: now,
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
    await prefs.setString(key, jsonEncode(_materializeRecords(records)));
  }

  List<Map<String, dynamic>> _materializeRecords(
    Iterable<Map<String, dynamic>> records,
  ) {
    final materialized = <Map<String, dynamic>>[];
    for (final record in records) {
      materialized.add(record);
    }
    return materialized;
  }
}
