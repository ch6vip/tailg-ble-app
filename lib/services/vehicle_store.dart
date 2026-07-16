import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/persistence_value.dart';
import '../models/vehicle_profile.dart';
import 'log_service.dart';

class VehicleStore {
  static final VehicleStore _instance = VehicleStore._internal();
  factory VehicleStore() => _instance;

  static const _prefVehicles = 'vehicle_profiles';
  static const _prefDefaultVehicleId = 'vehicle_default_id';
  static final Object _decodeFailed = Object();

  StreamController<List<VehicleProfile>> _vehiclesController =
      StreamController<List<VehicleProfile>>.broadcast();
  final List<VehicleProfile> _vehicles = [];
  String? _defaultVehicleId;
  bool _initialized = false;
  Future<void>? _initializing;
  Future<void>? _saveQueue;
  DateTime Function() _clock = DateTime.now;

  VehicleStore._internal();

  Stream<List<VehicleProfile>> get vehiclesStream => _vehiclesController.stream;
  List<VehicleProfile> get vehicles => List.unmodifiable(_vehicles);
  String? get defaultVehicleId => _defaultVehicleId;
  VehicleProfile? get defaultVehicle {
    if (_vehicles.isEmpty) return null;
    if (_defaultVehicleId == null) return _vehicles.first;
    return _vehicles.firstWhere(
      (vehicle) => vehicle.id == _defaultVehicleId,
      orElse: () => _vehicles.first,
    );
  }

  Future<void> init() async {
    if (_initialized) return;
    final initializing = _initializing;
    if (initializing != null) return initializing;
    final loading = _load();
    _initializing = loading;
    return loading;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      _defaultVehicleId = _normalizeId(prefs.getString(_prefDefaultVehicleId));
      final rawProfiles = prefs.getString(_prefVehicles);
      final decodedVehicles = _decodeVehicles(rawProfiles);
      _vehicles
        ..clear()
        ..addAll(decodedVehicles);
      _normalizeDefaultVehicleId();
      // Scrub legacy BLE-era QGJ credential fields from prefs if present.
      if (_rawContainsLegacyQgjCredentials(rawProfiles)) {
        await _persistVehicleProfiles(prefs);
      }
      _initialized = true;
      _emit();
    } finally {
      _initializing = null;
    }
  }

  void resetForTest({DateTime Function()? clock}) {
    if (_vehiclesController.isClosed) {
      _vehiclesController = StreamController<List<VehicleProfile>>.broadcast();
    }
    _vehicles.clear();
    _defaultVehicleId = null;
    _initialized = false;
    _initializing = null;
    _saveQueue = null;
    _clock = clock ?? DateTime.now;
  }

  List<VehicleProfile> _decodeVehicles(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = _decodeVehiclePayload(raw);
    if (identical(decoded, _decodeFailed)) return const [];
    if (decoded is! List) {
      _logDecodeWarning(
        'Expected persisted vehicle profiles to be a list, '
        'got ${decoded.runtimeType}',
      );
      return const [];
    }
    return _decodeVehicleList(decoded);
  }

  Object? _decodeVehiclePayload(String raw) {
    try {
      return jsonDecode(raw);
    } catch (e) {
      _logDecodeWarning('Failed to decode persisted vehicle profiles: $e');
      return _decodeFailed;
    }
  }

  List<VehicleProfile> _decodeVehicleList(Iterable<Object?> decoded) {
    final vehicles = <VehicleProfile>[];
    for (final item in decoded) {
      final vehicle = _decodeVehicle(item);
      if (vehicle != null) vehicles.add(vehicle);
    }
    return vehicles;
  }

  VehicleProfile? _decodeVehicle(Object? item) {
    if (item is! Map) {
      _logDecodeWarning(
        'Skipped vehicle profile entry with type ${item.runtimeType}',
      );
      return null;
    }
    try {
      final vehicle = VehicleProfile.fromJson(_decodeVehicleMap(item));
      if (vehicle.id.isEmpty) {
        _logDecodeWarning('Skipped vehicle profile with blank id');
        return null;
      }
      return vehicle;
    } catch (e) {
      _logDecodeWarning('Skipped vehicle parse error: $e');
      return null;
    }
  }

  Map<String, dynamic> _decodeVehicleMap(Map<Object?, Object?> item) {
    return parsePersistedMap(item)!;
  }

  void _logDecodeWarning(String detail) {
    LogService().operation(
      'VehicleStore',
      detail: detail,
      level: LogLevel.warning,
    );
  }

  bool _rawContainsLegacyQgjCredentials(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    return raw.contains('qgjLoginPassword') || raw.contains('qgjUserId');
  }

  void _normalizeDefaultVehicleId() {
    if (_vehicles.isEmpty) {
      _defaultVehicleId = null;
      return;
    }
    if (_defaultVehicleId == null ||
        !_vehicles.any((vehicle) => vehicle.id == _defaultVehicleId)) {
      _defaultVehicleId = _vehicles.first.id;
    }
  }

  Future<VehicleProfile> upsert({
    required String id,
    required String name,
    VehicleProtocol protocol = VehicleProtocol.auto,
    bool makeDefault = false,
    DateTime? lastConnectedAt,
    DateTime? savedAt,
  }) async {
    await init();
    final normalizedId = _normalizeId(id);
    if (normalizedId == null) {
      throw ArgumentError.value(id, 'id', 'Vehicle id must not be blank');
    }
    final normalizedName = _normalizeName(name);
    final now = _savedAt(savedAt);
    final index = _vehicles.indexWhere((vehicle) => vehicle.id == normalizedId);
    late VehicleProfile profile;
    if (index >= 0) {
      final current = _vehicles[index];
      profile = current.copyWith(
        name: normalizedName ?? current.name,
        protocol: protocol,
        updatedAt: now,
        lastConnectedAt: lastConnectedAt,
      );
      _vehicles[index] = profile;
    } else {
      profile = VehicleProfile(
        id: normalizedId,
        name: normalizedName ?? '未命名车辆',
        protocol: protocol,
        createdAt: now,
        updatedAt: now,
        lastConnectedAt: lastConnectedAt,
      );
      _vehicles.add(profile);
    }

    if (makeDefault || _defaultVehicleId == null || _vehicles.length == 1) {
      _defaultVehicleId = normalizedId;
    }

    await _save();
    return profile;
  }

  Future<void> rename(String id, String name, {DateTime? savedAt}) async {
    await init();
    final normalizedId = _normalizeId(id);
    if (normalizedId == null) return;
    final normalizedName = _normalizeName(name);
    if (normalizedName == null) return;
    final index = _vehicles.indexWhere((vehicle) => vehicle.id == normalizedId);
    if (index < 0) return;
    _vehicles[index] = _vehicles[index].copyWith(
      name: normalizedName,
      updatedAt: _savedAt(savedAt),
    );
    await _save();
  }

  Future<void> updateLastLocation(
    String id,
    VehicleLocation location, {
    DateTime? savedAt,
  }) async {
    await init();
    final normalizedId = _normalizeId(id);
    if (normalizedId == null) return;
    final index = _vehicles.indexWhere((vehicle) => vehicle.id == normalizedId);
    if (index < 0) return;
    _vehicles[index] = _vehicles[index].copyWith(
      lastLocation: location,
      updatedAt: _savedAt(savedAt),
    );
    await _save();
  }

  Future<void> setDefault(String id) async {
    await init();
    final normalizedId = _normalizeId(id);
    if (normalizedId == null) return;
    if (!_vehicles.any((vehicle) => vehicle.id == normalizedId)) return;
    _defaultVehicleId = normalizedId;
    await _save();
  }

  Future<void> remove(String id) async {
    await init();
    final normalizedId = _normalizeId(id);
    if (normalizedId == null) return;
    _vehicles.removeWhere((vehicle) => vehicle.id == normalizedId);
    if (_defaultVehicleId == normalizedId) {
      _defaultVehicleId = _vehicles.isEmpty ? null : _vehicles.first.id;
    }
    await _save();
  }

  String? _normalizeId(String? id) {
    return _nonBlankTrimmed(id);
  }

  String? _normalizeName(String? name) {
    return _nonBlankTrimmed(name);
  }

  String? _nonBlankTrimmed(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  DateTime _savedAt(DateTime? savedAt) => savedAt ?? _clock();

  Future<void> _save() {
    final save = (_saveQueue ?? Future<void>.value())
        .then((_) => _doSave())
        .catchError((Object e) {
          // Isolate save failures so subsequent writes are not poisoned.
          LogService().operation(
            'VehicleStore',
            detail: 'Save failed: $e',
            level: LogLevel.error,
          );
        });
    _saveQueue = save;
    return save;
  }

  Future<void> _doSave() async {
    final prefs = await SharedPreferences.getInstance();
    await _persistVehicleProfiles(prefs);
    _emit();
  }

  Future<void> _persistVehicleProfiles(SharedPreferences prefs) async {
    await prefs.setString(
      _prefVehicles,
      jsonEncode(_vehicles.map((vehicle) => vehicle.toJson()).toList()),
    );
    final defaultVehicleId = _defaultVehicleId;
    if (defaultVehicleId == null) {
      await prefs.remove(_prefDefaultVehicleId);
    } else {
      await prefs.setString(_prefDefaultVehicleId, defaultVehicleId);
    }
  }

  void _emit() {
    if (!_vehiclesController.isClosed) {
      _vehiclesController.add(List.unmodifiable(_vehicles));
    }
  }

  void dispose() {
    if (!_vehiclesController.isClosed) {
      unawaited(_vehiclesController.close());
    }
  }
}
