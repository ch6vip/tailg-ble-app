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

class QuickControlConfig {
  final String firstActionId;
  final String secondActionId;

  const QuickControlConfig({
    this.firstActionId = 'soundEffects',
    this.secondActionId = 'seat',
  });

  Map<String, dynamic> toJson() => {
    'firstActionId': firstActionId,
    'secondActionId': secondActionId,
  };

  factory QuickControlConfig.fromJson(Map<String, dynamic> json) {
    return QuickControlConfig(
      firstActionId: json['firstActionId'] as String? ?? 'soundEffects',
      secondActionId: json['secondActionId'] as String? ?? 'seat',
    );
  }

  QuickControlConfig copyWith({String? firstActionId, String? secondActionId}) {
    return QuickControlConfig(
      firstActionId: firstActionId ?? this.firstActionId,
      secondActionId: secondActionId ?? this.secondActionId,
    );
  }
}

/// Home-screen "SHORTCUTS" customization: which quick shortcuts show on the
/// home grid and in what order. Only the [order]/[hidden] of known shortcut ids
/// is persisted; the catalog (icon/label/target) lives in the UI layer so new
/// shortcuts can be added without a migration.
class QuickShortcutsConfig {
  /// Display order of shortcut ids. Ids not present here are appended in
  /// catalog order so newly added shortcuts still surface.
  final List<String> order;

  /// Ids hidden from the home grid (still reachable via the edit page).
  final Set<String> hidden;

  const QuickShortcutsConfig({this.order = const [], this.hidden = const {}});

  Map<String, dynamic> toJson() => {'order': order, 'hidden': hidden.toList()};

  factory QuickShortcutsConfig.fromJson(Map<String, dynamic> json) {
    final order = (json['order'] as List?)?.whereType<String>().toList() ?? [];
    final hidden =
        (json['hidden'] as List?)?.whereType<String>().toSet() ?? <String>{};
    return QuickShortcutsConfig(order: order, hidden: hidden);
  }
}

/// Home-screen main-control buttons customization (寻车 / 设防·解锁 / 座桶):
/// which control buttons show in the main control card and in what order.
/// Only the [order]/[hidden] of known control ids is persisted; the catalog
/// (icon/label/accent/command) lives in the UI layer. No control command is
/// stored here — selection only reorders/shows existing, already-verified
/// control actions.
class MainControlConfig {
  /// Display order of control ids. Ids not present here are appended in catalog
  /// order so newly added controls still surface.
  final List<String> order;

  /// Ids hidden from the main control card (still reachable via the edit page).
  final Set<String> hidden;

  const MainControlConfig({this.order = const [], this.hidden = const {}});

  Map<String, dynamic> toJson() => {'order': order, 'hidden': hidden.toList()};

  factory MainControlConfig.fromJson(Map<String, dynamic> json) {
    final order = (json['order'] as List?)?.whereType<String>().toList() ?? [];
    final hidden =
        (json['hidden'] as List?)?.whereType<String>().toSet() ?? <String>{};
    return MainControlConfig(order: order, hidden: hidden);
  }
}

class ReplicaFeatureStore {
  static final ReplicaFeatureStore _instance = ReplicaFeatureStore._();
  factory ReplicaFeatureStore() => _instance;
  ReplicaFeatureStore._();

  static const _prefNfcKeys = 'replica_nfc_keys';
  static const _prefFenceConfig = 'replica_fence_config';
  static const _prefShareMembers = 'replica_share_members';
  static const _prefQuickControlConfig = 'replica_quick_control_config';
  static const _prefQuickShortcutsConfig = 'replica_quick_shortcuts_config';
  static const _prefMainControlConfig = 'replica_main_control_config';

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

  Future<QuickControlConfig> loadQuickControlConfig() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _prefQuickControlConfig,
    );
    if (raw == null || raw.isEmpty) return const QuickControlConfig();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const QuickControlConfig();
    return QuickControlConfig.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> saveQuickControlConfig(QuickControlConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefQuickControlConfig, jsonEncode(config.toJson()));
  }

  Future<QuickShortcutsConfig> loadQuickShortcutsConfig() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _prefQuickShortcutsConfig,
    );
    if (raw == null || raw.isEmpty) return const QuickShortcutsConfig();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const QuickShortcutsConfig();
    return QuickShortcutsConfig.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> saveQuickShortcutsConfig(QuickShortcutsConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefQuickShortcutsConfig,
      jsonEncode(config.toJson()),
    );
  }

  Future<MainControlConfig> loadMainControlConfig() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _prefMainControlConfig,
    );
    if (raw == null || raw.isEmpty) return const MainControlConfig();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const MainControlConfig();
    return MainControlConfig.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> saveMainControlConfig(MainControlConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefMainControlConfig, jsonEncode(config.toJson()));
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
