import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vehicle_profile.dart';
import 'log_service.dart';

class VehicleStore {
  static final VehicleStore _instance = VehicleStore._internal();
  factory VehicleStore() => _instance;

  static const _prefVehicles = 'vehicle_profiles';
  static const _prefDefaultVehicleId = 'vehicle_default_id';
  static const _secureQgjPasswordPrefix = 'vehicle_qgj_password:';
  static const _secureQgjUserIdPrefix = 'vehicle_qgj_user_id:';

  final _vehiclesController =
      StreamController<List<VehicleProfile>>.broadcast();
  final FlutterSecureStorage _secureStorage;
  final List<VehicleProfile> _vehicles = [];
  String? _defaultVehicleId;
  bool _initialized = false;
  Future<void>? _initializing;
  Future<void>? _saveQueue;

  VehicleStore._internal({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(storageNamespace: 'vehicle_store'),
    ),
  }) : _secureStorage = secureStorage;

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
    _initializing = _load();
    return _initializing!;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      _defaultVehicleId = _normalizeId(prefs.getString(_prefDefaultVehicleId));
      final decodedVehicles = _decodeVehicles(prefs.getString(_prefVehicles));
      final hydratedVehicles = await _hydrateQgjCredentials(decodedVehicles);
      _vehicles
        ..clear()
        ..addAll(hydratedVehicles);
      _normalizeDefaultVehicleId();
      if (_containsLegacyQgjCredentials(decodedVehicles)) {
        await _persistVehicleProfiles(prefs);
      }
      _initialized = true;
      _emit();
    } finally {
      _initializing = null;
    }
  }

  void resetForTest() {
    _vehicles.clear();
    _defaultVehicleId = null;
    _initialized = false;
    _initializing = null;
    _saveQueue = null;
  }

  List<VehicleProfile> _decodeVehicles(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      _logDecodeWarning('Failed to decode persisted vehicle profiles: $e');
      return const [];
    }
    if (decoded is! List) {
      _logDecodeWarning(
        'Expected persisted vehicle profiles to be a list, '
        'got ${decoded.runtimeType}',
      );
      return const [];
    }

    final vehicles = <VehicleProfile>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      try {
        final vehicle = VehicleProfile.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (vehicle.id.isNotEmpty) vehicles.add(vehicle);
      } catch (e) {
        LogService().operation(
          'VehicleStore',
          detail: 'Skipped vehicle parse error: $e',
          level: LogLevel.warning,
        );
        continue;
      }
    }
    return vehicles;
  }

  void _logDecodeWarning(String detail) {
    LogService().operation(
      'VehicleStore',
      detail: detail,
      level: LogLevel.warning,
    );
  }

  Future<List<VehicleProfile>> _hydrateQgjCredentials(
    List<VehicleProfile> vehicles,
  ) async {
    final hydrated = <VehicleProfile>[];
    for (final vehicle in vehicles) {
      final legacyPassword = vehicle.qgjLoginPassword;
      final legacyUserId = vehicle.qgjUserId;
      final securePassword = await _readSecureInt(
        _securePasswordKey(vehicle.id),
      );
      final secureUserId = await _readSecureInt(_secureUserIdKey(vehicle.id));
      final resolvedPassword = securePassword ?? legacyPassword;
      final resolvedUserId = secureUserId ?? legacyUserId;
      if (securePassword == null && legacyPassword != null) {
        await _secureStorage.write(
          key: _securePasswordKey(vehicle.id),
          value: legacyPassword.toString(),
        );
      }
      if (secureUserId == null && legacyUserId != null) {
        await _secureStorage.write(
          key: _secureUserIdKey(vehicle.id),
          value: legacyUserId.toString(),
        );
      }
      hydrated.add(
        vehicle.copyWith(
          qgjLoginPassword: resolvedPassword,
          qgjUserId: resolvedUserId,
        ),
      );
    }
    return hydrated;
  }

  bool _containsLegacyQgjCredentials(List<VehicleProfile> vehicles) {
    return vehicles.any((vehicle) => vehicle.hasQgjCredentials);
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
  }) async {
    await init();
    final normalizedId = _normalizeId(id);
    if (normalizedId == null) {
      throw ArgumentError.value(id, 'id', 'Vehicle id must not be blank');
    }
    final now = DateTime.now();
    final index = _vehicles.indexWhere((vehicle) => vehicle.id == normalizedId);
    late VehicleProfile profile;
    if (index >= 0) {
      final current = _vehicles[index];
      profile = current.copyWith(
        name: name.trim().isEmpty ? current.name : name.trim(),
        protocol: protocol,
        updatedAt: now,
        lastConnectedAt: lastConnectedAt,
      );
      _vehicles[index] = profile;
    } else {
      profile = VehicleProfile(
        id: normalizedId,
        name: name.trim().isEmpty ? '未命名车辆' : name.trim(),
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

  Future<void> rename(String id, String name) async {
    await init();
    final normalizedId = _normalizeId(id);
    if (normalizedId == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final index = _vehicles.indexWhere((vehicle) => vehicle.id == normalizedId);
    if (index < 0) return;
    _vehicles[index] = _vehicles[index].copyWith(
      name: trimmed,
      updatedAt: DateTime.now(),
    );
    await _save();
  }

  Future<void> updateLastLocation(String id, VehicleLocation location) async {
    await init();
    final normalizedId = _normalizeId(id);
    if (normalizedId == null) return;
    final index = _vehicles.indexWhere((vehicle) => vehicle.id == normalizedId);
    if (index < 0) return;
    _vehicles[index] = _vehicles[index].copyWith(
      lastLocation: location,
      updatedAt: DateTime.now(),
    );
    await _save();
  }

  Future<void> updateQgjCredentials({
    required String id,
    int? password,
    int? userId,
    bool clear = false,
  }) async {
    await init();
    final normalizedId = _normalizeId(id);
    if (normalizedId == null) return;
    final index = _vehicles.indexWhere((vehicle) => vehicle.id == normalizedId);
    if (index < 0) return;
    final current = _vehicles[index];
    if (clear || password == null) {
      await _secureStorage.delete(key: _securePasswordKey(normalizedId));
    } else {
      await _secureStorage.write(
        key: _securePasswordKey(normalizedId),
        value: password.toString(),
      );
    }
    if (clear || userId == null) {
      await _secureStorage.delete(key: _secureUserIdKey(normalizedId));
    } else {
      await _secureStorage.write(
        key: _secureUserIdKey(normalizedId),
        value: userId.toString(),
      );
    }
    _vehicles[index] = current.copyWith(
      updatedAt: DateTime.now(),
      qgjLoginPassword: clear ? null : password,
      qgjUserId: clear ? null : userId,
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
    await _secureStorage.delete(key: _securePasswordKey(normalizedId));
    await _secureStorage.delete(key: _secureUserIdKey(normalizedId));
    if (_defaultVehicleId == normalizedId) {
      _defaultVehicleId = _vehicles.isEmpty ? null : _vehicles.first.id;
    }
    await _save();
  }

  String? _normalizeId(String? id) {
    final trimmed = id?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _save() {
    _saveQueue = (_saveQueue ?? Future<void>.value())
        .then((_) => _doSave())
        .catchError((Object e) {
          // Isolate save failures so subsequent writes are not poisoned.
          LogService().operation(
            'VehicleStore',
            detail: 'Save failed: $e',
            level: LogLevel.error,
          );
        });
    return _saveQueue!;
  }

  Future<void> _doSave() async {
    final prefs = await SharedPreferences.getInstance();
    await _persistVehicleProfiles(prefs);
    _emit();
  }

  Future<void> _persistVehicleProfiles(SharedPreferences prefs) async {
    await prefs.setString(
      _prefVehicles,
      jsonEncode(
        _vehicles
            .map((vehicle) => _profileJsonWithoutQgjCredentials(vehicle))
            .toList(),
      ),
    );
    if (_defaultVehicleId == null) {
      await prefs.remove(_prefDefaultVehicleId);
    } else {
      await prefs.setString(_prefDefaultVehicleId, _defaultVehicleId!);
    }
  }

  Map<String, dynamic> _profileJsonWithoutQgjCredentials(
    VehicleProfile vehicle,
  ) {
    final json = vehicle.copyWith(clearQgjCredentials: true).toJson();
    json.remove('qgjLoginPassword');
    json.remove('qgjUserId');
    return json;
  }

  Future<int?> _readSecureInt(String key) async {
    final raw = await _secureStorage.read(key: key);
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
  }

  String _securePasswordKey(String vehicleId) {
    return '$_secureQgjPasswordPrefix$vehicleId';
  }

  String _secureUserIdKey(String vehicleId) {
    return '$_secureQgjUserIdPrefix$vehicleId';
  }

  void _emit() {
    _vehiclesController.add(List.unmodifiable(_vehicles));
  }

  void dispose() {
    _vehiclesController.close();
  }
}
