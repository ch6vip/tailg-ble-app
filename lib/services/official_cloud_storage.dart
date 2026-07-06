part of 'official_cloud_service.dart';

class _OfficialCloudStoredSession {
  final String token;
  final String phone;
  final String userId;
  final String? selectedVehicleKey;
  final List<OfficialVehicle> cachedVehicles;
  final OfficialControlChannel controlChannel;
  final Map<String, String> localVehicleLinks;

  const _OfficialCloudStoredSession({
    required this.token,
    required this.phone,
    required this.userId,
    required this.selectedVehicleKey,
    required this.cachedVehicles,
    required this.controlChannel,
    required this.localVehicleLinks,
  });
}

class _OfficialCloudStorage {
  static const _prefToken = 'official_cloud_token';
  static const _prefPhone = 'official_cloud_phone';
  static const _secureToken = 'official_cloud_token';
  static const _securePhone = 'official_cloud_phone';
  static const _secureUserId = 'official_cloud_user_id';
  static const _prefSelectedVehicle = 'official_cloud_selected_vehicle';
  static const _prefControlChannel = 'official_cloud_control_channel';
  static const _prefVehicleLinks = 'official_cloud_vehicle_links';
  static const _prefUserId = 'official_cloud_user_id';
  static const _prefCarControlInfo = 'carControlInfo';

  final FlutterSecureStorage _secureStorage;
  final LogService _log;

  _OfficialCloudStorage({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(storageNamespace: 'official_cloud'),
    ),
    LogService? log,
  }) : _secureStorage = secureStorage,
       _log = log ?? LogService();

  Future<_OfficialCloudStoredSession> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final channelName = prefs.getString(_prefControlChannel);
    final credentials = await _loadSecureCredentials(prefs);
    final token = credentials.$1;
    return _OfficialCloudStoredSession(
      token: token,
      phone: credentials.$2,
      userId: credentials.$3,
      selectedVehicleKey: prefs.getString(_prefSelectedVehicle),
      cachedVehicles: token.isEmpty
          ? const <OfficialVehicle>[]
          : _decodeCarControlInfo(prefs.getString(_prefCarControlInfo)),
      controlChannel: OfficialControlChannel.values.firstWhere(
        (item) => item.name == channelName,
        orElse: () => OfficialControlChannel.automatic,
      ),
      localVehicleLinks: _decodeLinks(prefs.getString(_prefVehicleLinks)),
    );
  }

  Future<void> saveCredentials({
    required String token,
    required String phone,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.write(key: _secureToken, value: token);
    await _secureStorage.write(key: _securePhone, value: phone);
    if (userId.isEmpty) {
      await _secureStorage.delete(key: _secureUserId);
    } else {
      await _secureStorage.write(key: _secureUserId, value: userId);
    }
    await prefs.remove(_prefToken);
    await prefs.remove(_prefPhone);
    await prefs.remove(_prefUserId);
    await prefs.remove(_prefSelectedVehicle);
    await prefs.remove(_prefCarControlInfo);
  }

  Future<void> clearCredentialsAndSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _secureToken);
    await _secureStorage.delete(key: _securePhone);
    await _secureStorage.delete(key: _secureUserId);
    await prefs.remove(_prefToken);
    await prefs.remove(_prefPhone);
    await prefs.remove(_prefUserId);
    await prefs.remove(_prefSelectedVehicle);
    await prefs.remove(_prefCarControlInfo);
  }

  Future<void> saveSelectedVehicleKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null) {
      await prefs.remove(_prefSelectedVehicle);
    } else {
      await prefs.setString(_prefSelectedVehicle, key);
    }
  }

  Future<void> saveCarControlInfo(OfficialVehicle? vehicle) async {
    final prefs = await SharedPreferences.getInstance();
    if (vehicle == null) {
      await prefs.remove(_prefCarControlInfo);
      return;
    }
    await prefs.setString(_prefCarControlInfo, jsonEncode(vehicle.toJson()));
  }

  Future<void> saveControlChannel(OfficialControlChannel channel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefControlChannel, channel.name);
  }

  Future<void> saveLinks(Map<String, String> links) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefVehicleLinks, jsonEncode(links));
  }

  Future<(String, String, String)> _loadSecureCredentials(
    SharedPreferences prefs,
  ) async {
    final secureToken = await _secureStorage.read(key: _secureToken);
    final securePhone = await _secureStorage.read(key: _securePhone);
    final secureUserId = await _secureStorage.read(key: _secureUserId);
    final legacyToken = prefs.getString(_prefToken) ?? '';
    final legacyPhone = prefs.getString(_prefPhone) ?? '';
    final legacyUserId = prefs.getString(_prefUserId) ?? '';
    final token = secureToken ?? legacyToken;
    final phone = securePhone ?? legacyPhone;
    final userId = secureUserId ?? legacyUserId;
    if (legacyToken.isNotEmpty ||
        legacyPhone.isNotEmpty ||
        legacyUserId.isNotEmpty) {
      if (token.isNotEmpty) {
        await _secureStorage.write(key: _secureToken, value: token);
      }
      if (phone.isNotEmpty) {
        await _secureStorage.write(key: _securePhone, value: phone);
      }
      if (userId.isNotEmpty) {
        await _secureStorage.write(key: _secureUserId, value: userId);
      }
      await prefs.remove(_prefToken);
      await prefs.remove(_prefPhone);
      await prefs.remove(_prefUserId);
      _log.operation('官方云登录态已迁移到安全存储');
    }
    return (token, phone, userId);
  }

  Map<String, String> _decodeLinks(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return _decodeLinkMap(decoded);
      }
      _log.operation(
        '官云本地车辆关联数据格式异常，已忽略',
        detail: 'Expected JSON object, got ${decoded.runtimeType}',
        level: LogLevel.warning,
      );
    } catch (e) {
      _log.operation(
        '官云本地车辆关联数据损坏，已忽略',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      return {};
    }
    return {};
  }

  Map<String, String> _decodeLinkMap(Map<Object?, Object?> decoded) {
    return OfficialCloudVehicleLinks.normalize(
      decoded.map((key, value) => MapEntry(key.toString(), value.toString())),
    );
  }

  List<OfficialVehicle> _decodeCarControlInfo(String? raw) {
    if (raw == null || raw.isEmpty) return const <OfficialVehicle>[];
    try {
      final decoded = jsonDecode(raw);
      final vehicles = OfficialCloudDataParser.vehicles(decoded);
      if (vehicles.isNotEmpty) return vehicles;
      _log.operation(
        '官云车辆控制缓存无有效车辆，已忽略',
        detail: 'type=${decoded.runtimeType}',
        level: LogLevel.warning,
      );
    } catch (e) {
      _log.operation(
        '官云车辆控制缓存损坏，已忽略',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      return const <OfficialVehicle>[];
    }
    return const <OfficialVehicle>[];
  }
}
