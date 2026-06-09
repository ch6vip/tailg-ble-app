import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/vehicle_profile.dart';

class VehicleStore {
  static final VehicleStore _instance = VehicleStore._();
  factory VehicleStore() => _instance;
  VehicleStore._();

  static const _prefVehicles = 'vehicle_profiles';
  static const _prefDefaultVehicleId = 'vehicle_default_id';

  final _vehiclesController =
      StreamController<List<VehicleProfile>>.broadcast();
  final List<VehicleProfile> _vehicles = [];
  String? _defaultVehicleId;
  bool _initialized = false;
  Future<void>? _initializing;

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
      _defaultVehicleId = prefs.getString(_prefDefaultVehicleId);
      _vehicles
        ..clear()
        ..addAll(_decodeVehicles(prefs.getString(_prefVehicles)));
      _normalizeDefaultVehicleId();
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
  }

  List<VehicleProfile> _decodeVehicles(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
    if (decoded is! List) return const [];

    final vehicles = <VehicleProfile>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      try {
        final vehicle = VehicleProfile.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (vehicle.id.isNotEmpty) vehicles.add(vehicle);
      } catch (_) {
        continue;
      }
    }
    return vehicles;
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
    final now = DateTime.now();
    final index = _vehicles.indexWhere((vehicle) => vehicle.id == id);
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
        id: id,
        name: name.trim().isEmpty ? '未命名车辆' : name.trim(),
        protocol: protocol,
        createdAt: now,
        updatedAt: now,
        lastConnectedAt: lastConnectedAt,
      );
      _vehicles.add(profile);
    }

    if (makeDefault || _defaultVehicleId == null || _vehicles.length == 1) {
      _defaultVehicleId = id;
    }

    await _save();
    return profile;
  }

  Future<void> rename(String id, String name) async {
    await init();
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final index = _vehicles.indexWhere((vehicle) => vehicle.id == id);
    if (index < 0) return;
    _vehicles[index] = _vehicles[index].copyWith(
      name: trimmed,
      updatedAt: DateTime.now(),
    );
    await _save();
  }

  Future<void> updateLastLocation(String id, VehicleLocation location) async {
    await init();
    final index = _vehicles.indexWhere((vehicle) => vehicle.id == id);
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
    final index = _vehicles.indexWhere((vehicle) => vehicle.id == id);
    if (index < 0) return;
    final current = _vehicles[index];
    _vehicles[index] = VehicleProfile(
      id: current.id,
      name: current.name,
      protocol: current.protocol,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      lastConnectedAt: current.lastConnectedAt,
      lastLocation: current.lastLocation,
      qgjLoginPassword: clear ? null : password,
      qgjUserId: clear ? null : userId,
    );
    await _save();
  }

  Future<void> setDefault(String id) async {
    await init();
    if (!_vehicles.any((vehicle) => vehicle.id == id)) return;
    _defaultVehicleId = id;
    await _save();
  }

  Future<void> remove(String id) async {
    await init();
    _vehicles.removeWhere((vehicle) => vehicle.id == id);
    if (_defaultVehicleId == id) {
      _defaultVehicleId = _vehicles.isEmpty ? null : _vehicles.first.id;
    }
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefVehicles,
      jsonEncode(_vehicles.map((vehicle) => vehicle.toJson()).toList()),
    );
    if (_defaultVehicleId == null) {
      await prefs.remove(_prefDefaultVehicleId);
    } else {
      await prefs.setString(_prefDefaultVehicleId, _defaultVehicleId!);
    }
    _emit();
  }

  void _emit() {
    _vehiclesController.add(List.unmodifiable(_vehicles));
  }
}
