import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/constants.dart';
import '../models/official_vehicle.dart';
import '../models/vehicle_profile.dart';
import 'log_service.dart';
import 'vehicle_store.dart';

part 'official_cloud_api_client.dart';
part 'official_cloud_auth_parser.dart';
part 'official_cloud_data_parser.dart';
part 'official_cloud_vehicle_mapper.dart';
part 'official_cloud_vehicle_links.dart';
part 'official_cloud_vehicle_sync.dart';
part 'official_cloud_storage.dart';

enum OfficialControlChannel {
  automatic('自动', '优先 BLE，未连接时走官方云端'),
  ble('BLE', '只使用本地蓝牙直连'),
  officialCloud('官方云端', '使用官方账号远程控车');

  final String label;
  final String description;

  const OfficialControlChannel(this.label, this.description);
}

class OfficialCloudState {
  final bool initialized;
  final String token;
  final String phone;
  final String userId;
  final bool loading;
  final String? error;
  final List<OfficialVehicle> vehicles;
  final String? selectedVehicleKey;
  final OfficialControlChannel controlChannel;
  final Map<String, String> localVehicleLinks;
  final OfficialBatteryInfo? batteryInfo;
  final bool batteryInfoLoading;
  final String? batteryInfoError;
  final OfficialVehicleLocation? vehicleLocation;
  final bool vehicleLocationLoading;
  final String? vehicleLocationError;
  final OfficialFenceData? fenceData;
  final bool fenceLoading;
  final String? fenceError;
  final List<OfficialTravelDay> travelDays;
  final String travelMonth;
  final bool travelLoading;
  final String? travelError;
  final Map<String, List<OfficialTravelPoint>> travelDetails;
  final bool travelDetailLoading;
  final String? travelDetailError;

  const OfficialCloudState({
    required this.initialized,
    required this.token,
    required this.phone,
    required this.userId,
    required this.loading,
    required this.error,
    required this.vehicles,
    required this.selectedVehicleKey,
    required this.controlChannel,
    required this.localVehicleLinks,
    required this.batteryInfo,
    required this.batteryInfoLoading,
    required this.batteryInfoError,
    required this.vehicleLocation,
    required this.vehicleLocationLoading,
    required this.vehicleLocationError,
    required this.fenceData,
    required this.fenceLoading,
    required this.fenceError,
    required this.travelDays,
    required this.travelMonth,
    required this.travelLoading,
    required this.travelError,
    required this.travelDetails,
    required this.travelDetailLoading,
    required this.travelDetailError,
  });

  factory OfficialCloudState.initial() => const OfficialCloudState(
    initialized: false,
    token: '',
    phone: '',
    userId: '',
    loading: false,
    error: null,
    vehicles: [],
    selectedVehicleKey: null,
    controlChannel: OfficialControlChannel.automatic,
    localVehicleLinks: {},
    batteryInfo: null,
    batteryInfoLoading: false,
    batteryInfoError: null,
    vehicleLocation: null,
    vehicleLocationLoading: false,
    vehicleLocationError: null,
    fenceData: null,
    fenceLoading: false,
    fenceError: null,
    travelDays: [],
    travelMonth: '',
    travelLoading: false,
    travelError: null,
    travelDetails: {},
    travelDetailLoading: false,
    travelDetailError: null,
  );

  bool get signedIn => token.isNotEmpty;

  OfficialVehicle? get selectedVehicle {
    if (vehicles.isEmpty) return null;
    if (selectedVehicleKey == null) return vehicles.first;
    for (final vehicle in vehicles) {
      if (vehicle.key == selectedVehicleKey) return vehicle;
    }
    return vehicles.first;
  }

  String? linkedLocalVehicleId(String officialVehicleKey) =>
      localVehicleLinks[officialVehicleKey];

  OfficialCloudState copyWith({
    bool? initialized,
    String? token,
    String? phone,
    String? userId,
    bool? loading,
    Object? error = _sentinel,
    List<OfficialVehicle>? vehicles,
    Object? selectedVehicleKey = _sentinel,
    OfficialControlChannel? controlChannel,
    Map<String, String>? localVehicleLinks,
    Object? batteryInfo = _sentinel,
    bool? batteryInfoLoading,
    Object? batteryInfoError = _sentinel,
    Object? vehicleLocation = _sentinel,
    bool? vehicleLocationLoading,
    Object? vehicleLocationError = _sentinel,
    Object? fenceData = _sentinel,
    bool? fenceLoading,
    Object? fenceError = _sentinel,
    List<OfficialTravelDay>? travelDays,
    String? travelMonth,
    bool? travelLoading,
    Object? travelError = _sentinel,
    Map<String, List<OfficialTravelPoint>>? travelDetails,
    bool? travelDetailLoading,
    Object? travelDetailError = _sentinel,
  }) {
    return OfficialCloudState(
      initialized: initialized ?? this.initialized,
      token: token ?? this.token,
      phone: phone ?? this.phone,
      userId: userId ?? this.userId,
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      vehicles: vehicles ?? this.vehicles,
      selectedVehicleKey: identical(selectedVehicleKey, _sentinel)
          ? this.selectedVehicleKey
          : selectedVehicleKey as String?,
      controlChannel: controlChannel ?? this.controlChannel,
      localVehicleLinks: localVehicleLinks ?? this.localVehicleLinks,
      batteryInfo: identical(batteryInfo, _sentinel)
          ? this.batteryInfo
          : batteryInfo as OfficialBatteryInfo?,
      batteryInfoLoading: batteryInfoLoading ?? this.batteryInfoLoading,
      batteryInfoError: identical(batteryInfoError, _sentinel)
          ? this.batteryInfoError
          : batteryInfoError as String?,
      vehicleLocation: identical(vehicleLocation, _sentinel)
          ? this.vehicleLocation
          : vehicleLocation as OfficialVehicleLocation?,
      vehicleLocationLoading:
          vehicleLocationLoading ?? this.vehicleLocationLoading,
      vehicleLocationError: identical(vehicleLocationError, _sentinel)
          ? this.vehicleLocationError
          : vehicleLocationError as String?,
      fenceData: identical(fenceData, _sentinel)
          ? this.fenceData
          : fenceData as OfficialFenceData?,
      fenceLoading: fenceLoading ?? this.fenceLoading,
      fenceError: identical(fenceError, _sentinel)
          ? this.fenceError
          : fenceError as String?,
      travelDays: travelDays ?? this.travelDays,
      travelMonth: travelMonth ?? this.travelMonth,
      travelLoading: travelLoading ?? this.travelLoading,
      travelError: identical(travelError, _sentinel)
          ? this.travelError
          : travelError as String?,
      travelDetails: travelDetails ?? this.travelDetails,
      travelDetailLoading: travelDetailLoading ?? this.travelDetailLoading,
      travelDetailError: identical(travelDetailError, _sentinel)
          ? this.travelDetailError
          : travelDetailError as String?,
    );
  }

  static const _sentinel = Object();
}

class OfficialCloudService {
  static final OfficialCloudService _instance = OfficialCloudService._();
  factory OfficialCloudService() => _instance;
  static const _silentRefreshTtl = Duration(seconds: 45);

  final _log = LogService();
  final _storage = _OfficialCloudStorage();
  final _apiClient = _OfficialCloudApiClient(
    config: const OfficialCloudApiConfig(),
    log: LogService(),
  );
  final _stateController = StreamController<OfficialCloudState>.broadcast();
  OfficialCloudState _state = OfficialCloudState.initial();
  final Map<String, DateTime> _lastSuccessfulRefresh = {};
  final Map<String, Future<void>> _inFlightRefreshes = {};
  bool _initialized = false;
  Future<void>? _initializing;

  OfficialCloudService._();

  Stream<OfficialCloudState> get stateStream => _stateController.stream;
  OfficialCloudState get state => _state;
  OfficialCloudRequestSummary? get lastRequest => _apiClient.lastRequest;

  Future<void> init() async {
    if (_initialized) return;
    final initializing = _initializing;
    if (initializing != null) return initializing;
    _initializing = _loadInitialSession();
    return _initializing!;
  }

  Future<void> _loadInitialSession() async {
    try {
      final stored = await _storage.loadSession();
      _state = _state.copyWith(
        initialized: true,
        token: stored.token,
        phone: stored.phone,
        userId: stored.userId,
        selectedVehicleKey: stored.selectedVehicleKey,
        controlChannel: stored.controlChannel,
        localVehicleLinks: stored.localVehicleLinks,
      );
      _initialized = true;
      _emit();
      if (_state.token.isNotEmpty) {
        _runSilentRefresh(
          refreshVehicles(silent: true),
          failureMessage: '官方车辆静默刷新失败',
        );
      }
    } finally {
      _initializing = null;
    }
  }

  Future<void> requestSmsCode(String phone) async {
    final normalized = phone.trim();
    if (!_validPhone(normalized)) {
      throw const OfficialCloudApiException('请输入 11 位手机号');
    }
    _setLoading(true);
    try {
      final response = await _apiClient.request(
        'app/getCode?phone=${Uri.encodeQueryComponent(normalized)}',
        method: 'POST',
      );
      _ensureSuccess(response.body, fallback: '验证码发送失败');
      _log.operation('官方云验证码已发送');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> login(String phone, String smsCode) async {
    final normalizedPhone = phone.trim();
    final normalizedSms = smsCode.trim();
    if (!_validPhone(normalizedPhone)) {
      throw const OfficialCloudApiException('请输入 11 位手机号');
    }
    if (!_validSmsCode(normalizedSms)) {
      throw const OfficialCloudApiException('请输入短信验证码');
    }
    _setLoading(true);
    try {
      final response = await _apiClient.request(
        'app/login',
        method: 'POST',
        body: {
          'macCode': _apiClient.config.loginMacCode,
          'phone': normalizedPhone,
          'smsCode': normalizedSms,
          'autoCompleteUserDetail': 'true',
        },
      );
      final token =
          response.headers['authorization'] ??
          response.headers['Authorization'.toLowerCase()] ??
          '';
      if (token.isEmpty) {
        _ensureSuccess(response.body, fallback: '登录失败，未返回 token');
        throw const OfficialCloudApiException('登录失败，未返回 token');
      }

      final userId = OfficialCloudAuthParser.extractUserId(response.body);
      await _storage.saveCredentials(
        token: token,
        phone: normalizedPhone,
        userId: userId,
      );
      _clearRefreshCache();
      _state = _state.copyWith(
        token: token,
        phone: normalizedPhone,
        userId: userId,
        error: null,
      );
      _emit();
      _log.operation('官方云登录成功');
      await refreshVehicles();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _storage.clearCredentialsAndSelection();
    _clearRefreshCache();
    _state = _state.copyWith(
      token: '',
      phone: '',
      userId: '',
      loading: false,
      vehicles: const [],
      selectedVehicleKey: null,
      error: null,
      batteryInfo: null,
      batteryInfoLoading: false,
      batteryInfoError: null,
      vehicleLocation: null,
      vehicleLocationLoading: false,
      vehicleLocationError: null,
      fenceData: null,
      fenceLoading: false,
      fenceError: null,
      travelDays: const [],
      travelMonth: '',
      travelLoading: false,
      travelError: null,
      travelDetails: const {},
      travelDetailLoading: false,
      travelDetailError: null,
    );
    _emit();
    _log.operation('官方云已退出登录');
  }

  Future<void> refreshVehicles({
    bool silent = false,
    bool refreshReplicaDetails = true,
    bool force = false,
  }) async {
    final token = _state.token;
    if (token.isEmpty) return;
    const refreshKey = 'vehicles';
    if (!force && silent && _shouldUseRecentRefresh(refreshKey)) {
      _refreshVehicleDependents(refreshReplicaDetails: refreshReplicaDetails);
      return;
    }
    final inFlight = _inFlightRefreshes[refreshKey];
    if (silent && inFlight != null) return inFlight;

    late Future<void> refresh;
    refresh = _refreshVehiclesNow(
      silent: silent,
      refreshReplicaDetails: refreshReplicaDetails,
      refreshKey: refreshKey,
      token: token,
    );
    _inFlightRefreshes[refreshKey] = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_inFlightRefreshes[refreshKey], refresh)) {
        _inFlightRefreshes.remove(refreshKey);
      }
    }
  }

  Future<void> _refreshVehiclesNow({
    required bool silent,
    required bool refreshReplicaDetails,
    required String refreshKey,
    required String token,
  }) async {
    if (!silent) _setLoading(true);
    try {
      final response = await _apiClient.request(
        'app/centralControl/carStatus',
        method: 'POST',
        token: token,
        body: {'phoneMode': _apiClient.config.phoneMode},
      );
      _ensureSuccess(response.body, fallback: '获取官方车辆失败');
      if (!_isCurrentSession(token)) return;
      final vehicles = OfficialCloudDataParser.vehicles(response.body['data']);
      var selected = _state.selectedVehicleKey;
      if (vehicles.isEmpty) {
        selected = null;
      } else if (selected == null ||
          !vehicles.any((vehicle) => vehicle.key == selected)) {
        selected = vehicles.first.key;
      }
      await _storage.saveSelectedVehicleKey(selected);
      _state = _state.copyWith(
        vehicles: vehicles,
        selectedVehicleKey: selected,
        error: null,
      );
      _emit();
      await _applySelectedVehicleToLocalProfile();
      _log.operation('官方车辆列表已刷新', detail: 'count=${vehicles.length}');
      _refreshVehicleDependents(refreshReplicaDetails: refreshReplicaDetails);
      _markRefreshSuccess(refreshKey);
    } catch (e) {
      if (!_isCurrentSession(token)) return;
      await _handleAuthFailureIfNeeded(e);
      if (_state.signedIn) {
        final message = _errorMessage(e);
        _state = _state.copyWith(error: message);
        _emit();
      }
      rethrow;
    } finally {
      if (!silent && _isCurrentSession(token)) _setLoading(false);
    }
  }

  Future<void> selectVehicle(OfficialVehicle vehicle) async {
    await _storage.saveSelectedVehicleKey(vehicle.key);
    _state = _state.copyWith(selectedVehicleKey: vehicle.key);
    _emit();
    await _applySelectedVehicleToLocalProfile();
  }

  Future<void> setControlChannel(OfficialControlChannel channel) async {
    await _storage.saveControlChannel(channel);
    _state = _state.copyWith(controlChannel: channel);
    _emit();
  }

  Future<void> refreshBatteryInfo({bool silent = false}) async {
    final token = _state.token;
    if (token.isEmpty) return;
    const refreshKey = 'batteryInfo';
    if (silent && _shouldUseRecentRefresh(refreshKey)) return;
    final inFlight = _inFlightRefreshes[refreshKey];
    if (silent && inFlight != null) return inFlight;

    late Future<void> refresh;
    refresh = _refreshBatteryInfoNow(
      silent: silent,
      refreshKey: refreshKey,
      token: token,
    );
    _inFlightRefreshes[refreshKey] = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_inFlightRefreshes[refreshKey], refresh)) {
        _inFlightRefreshes.remove(refreshKey);
      }
    }
  }

  Future<void> _refreshBatteryInfoNow({
    required bool silent,
    required String refreshKey,
    required String token,
  }) async {
    if (!silent) {
      _state = _state.copyWith(
        batteryInfoLoading: true,
        batteryInfoError: null,
      );
      _emit();
    }
    try {
      final response = await _apiClient.request(
        'app/mine/batteryInfo',
        method: 'POST',
        token: token,
      );
      _ensureSuccess(response.body, fallback: '获取官方电池信息失败');
      if (!_isCurrentSession(token)) return;
      final info = OfficialCloudDataParser.batteryInfo(response.body['data']);
      _state = _state.copyWith(
        batteryInfo: info.hasData ? info : null,
        batteryInfoLoading: false,
        batteryInfoError: null,
      );
      _emit();
      _log.operation(
        '官方电池信息已刷新',
        detail: info.hasData ? 'hasData=true' : 'hasData=false',
      );
      _markRefreshSuccess(refreshKey);
    } catch (e) {
      if (!_isCurrentSession(token)) return;
      await _handleAuthFailureIfNeeded(e);
      if (_state.signedIn) {
        final message = _errorMessage(e);
        _state = _state.copyWith(
          batteryInfoLoading: false,
          batteryInfoError: message,
        );
        _emit();
      }
      if (!silent) rethrow;
      _log.operation(
        '官方电池信息刷新失败',
        detail: _errorMessage(e),
        level: LogLevel.warning,
      );
    } finally {
      if (!silent && _isCurrentSession(token) && _state.batteryInfoLoading) {
        _state = _state.copyWith(batteryInfoLoading: false);
        _emit();
      }
    }
  }

  Future<void> refreshVehicleLocation({bool silent = false}) async {
    final token = _state.token;
    final vehicle = _state.selectedVehicle;
    if (token.isEmpty || vehicle == null || vehicle.carId.isEmpty) {
      return;
    }
    final refreshKey = 'vehicleLocation:${vehicle.key}';
    if (silent && _shouldUseRecentRefresh(refreshKey)) return;
    final inFlight = _inFlightRefreshes[refreshKey];
    if (silent && inFlight != null) return inFlight;

    late Future<void> refresh;
    refresh = _refreshVehicleLocationNow(
      silent: silent,
      refreshKey: refreshKey,
      vehicle: vehicle,
      token: token,
    );
    _inFlightRefreshes[refreshKey] = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_inFlightRefreshes[refreshKey], refresh)) {
        _inFlightRefreshes.remove(refreshKey);
      }
    }
  }

  Future<void> _refreshVehicleLocationNow({
    required bool silent,
    required String refreshKey,
    required OfficialVehicle vehicle,
    required String token,
  }) async {
    if (!silent) {
      _state = _state.copyWith(
        vehicleLocationLoading: true,
        vehicleLocationError: null,
      );
      _emit();
    }
    try {
      final response = await _apiClient.request(
        'app/car/extend/getByCarId',
        method: 'POST',
        token: token,
        body: {'carId': vehicle.carId},
      );
      _ensureSuccess(response.body, fallback: '获取官方停车位置失败');
      if (!_isCurrentSession(token)) return;
      final location = OfficialCloudDataParser.vehicleLocation(
        response.body['data'],
      );
      _state = _state.copyWith(
        vehicleLocation: location.hasData ? location : null,
        vehicleLocationLoading: false,
        vehicleLocationError: null,
      );
      _emit();
      _log.operation(
        '官方停车位置已刷新',
        detail: location.hasData ? 'hasData=true' : 'hasData=false',
      );
      _markRefreshSuccess(refreshKey);
    } catch (e) {
      if (!_isCurrentSession(token)) return;
      await _handleAuthFailureIfNeeded(e);
      if (_state.signedIn) {
        _state = _state.copyWith(
          vehicleLocationLoading: false,
          vehicleLocationError: _errorMessage(e),
        );
        _emit();
      }
      if (!silent) rethrow;
      _log.operation(
        '官方停车位置刷新失败',
        detail: _errorMessage(e),
        level: LogLevel.warning,
      );
    } finally {
      if (!silent &&
          _isCurrentSession(token) &&
          _state.vehicleLocationLoading) {
        _state = _state.copyWith(vehicleLocationLoading: false);
        _emit();
      }
    }
  }

  Future<void> refreshFenceData({bool silent = false}) async {
    final token = _state.token;
    final vehicle = _state.selectedVehicle;
    if (token.isEmpty || vehicle == null || vehicle.carId.isEmpty) {
      return;
    }
    final refreshKey = 'fence:${vehicle.key}';
    if (silent && _shouldUseRecentRefresh(refreshKey)) return;
    final inFlight = _inFlightRefreshes[refreshKey];
    if (silent && inFlight != null) return inFlight;

    late Future<void> refresh;
    refresh = _refreshFenceDataNow(
      silent: silent,
      refreshKey: refreshKey,
      vehicle: vehicle,
      token: token,
    );
    _inFlightRefreshes[refreshKey] = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_inFlightRefreshes[refreshKey], refresh)) {
        _inFlightRefreshes.remove(refreshKey);
      }
    }
  }

  Future<void> _refreshFenceDataNow({
    required bool silent,
    required String refreshKey,
    required OfficialVehicle vehicle,
    required String token,
  }) async {
    if (!silent) {
      _state = _state.copyWith(fenceLoading: true, fenceError: null);
      _emit();
    }
    try {
      final response = await _apiClient.request(
        'app/device/getFenceData',
        method: 'POST',
        token: token,
        body: {'carId': vehicle.carId},
      );
      _ensureSuccess(response.body, fallback: '获取官方围栏失败');
      if (!_isCurrentSession(token)) return;
      final fence = OfficialCloudDataParser.fenceData(response.body['data']);
      _state = _state.copyWith(
        fenceData: fence.hasData ? fence : null,
        fenceLoading: false,
        fenceError: null,
      );
      _emit();
      _log.operation(
        '官方电子围栏已刷新',
        detail: fence.hasData ? 'hasData=true' : 'hasData=false',
      );
      _markRefreshSuccess(refreshKey);
    } catch (e) {
      if (!_isCurrentSession(token)) return;
      await _handleAuthFailureIfNeeded(e);
      if (_state.signedIn) {
        _state = _state.copyWith(
          fenceLoading: false,
          fenceError: _errorMessage(e),
        );
        _emit();
      }
      if (!silent) rethrow;
      _log.operation(
        '官方电子围栏刷新失败',
        detail: _errorMessage(e),
        level: LogLevel.warning,
      );
    } finally {
      if (!silent && _isCurrentSession(token) && _state.fenceLoading) {
        _state = _state.copyWith(fenceLoading: false);
        _emit();
      }
    }
  }

  Future<void> refreshTravelHistory({
    String? month,
    bool silent = false,
  }) async {
    final token = _state.token;
    final vehicle = _state.selectedVehicle;
    if (token.isEmpty || vehicle == null) return;
    final userId = _state.userId.trim();
    if (userId.isEmpty) {
      _state = _state.copyWith(
        travelDays: const [],
        travelMonth: month ?? _currentMonth(),
        travelError: '官方登录未返回 uid，无法读取历史轨迹',
      );
      _emit();
      return;
    }
    final queryMonth = month ?? _state.travelMonth.ifEmpty(_currentMonth);
    final refreshKey = 'travel:${vehicle.key}:$queryMonth';
    if (silent &&
        _state.travelMonth == queryMonth &&
        _shouldUseRecentRefresh(refreshKey)) {
      return;
    }
    final inFlight = _inFlightRefreshes[refreshKey];
    if (silent && inFlight != null) return inFlight;

    late Future<void> refresh;
    refresh = _refreshTravelHistoryNow(
      silent: silent,
      refreshKey: refreshKey,
      vehicle: vehicle,
      queryMonth: queryMonth,
      userId: userId,
      token: token,
    );
    _inFlightRefreshes[refreshKey] = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_inFlightRefreshes[refreshKey], refresh)) {
        _inFlightRefreshes.remove(refreshKey);
      }
    }
  }

  Future<void> _refreshTravelHistoryNow({
    required bool silent,
    required String refreshKey,
    required OfficialVehicle vehicle,
    required String queryMonth,
    required String userId,
    required String token,
  }) async {
    if (!silent) {
      _state = _state.copyWith(
        travelLoading: true,
        travelError: null,
        travelMonth: queryMonth,
      );
      _emit();
    }
    try {
      final response = await _apiClient.request(
        'app/centralControl/deviceTravel',
        method: 'POST',
        token: token,
        body: {'queryMonth': queryMonth, 'frame': vehicle.frame, 'uid': userId},
      );
      _ensureSuccess(response.body, fallback: '获取官方历史轨迹失败');
      if (!_isCurrentSession(token)) return;
      final days = OfficialCloudDataParser.travelDays(response.body['data']);
      _state = _state.copyWith(
        travelDays: days,
        travelMonth: queryMonth,
        travelLoading: false,
        travelError: null,
      );
      _emit();
      _log.operation('官方历史轨迹已刷新', detail: 'days=${days.length}');
      _markRefreshSuccess(refreshKey);
    } catch (e) {
      if (!_isCurrentSession(token)) return;
      await _handleAuthFailureIfNeeded(e);
      if (_state.signedIn) {
        _state = _state.copyWith(
          travelLoading: false,
          travelError: _errorMessage(e),
        );
        _emit();
      }
      if (!silent) rethrow;
      _log.operation(
        '官方历史轨迹刷新失败',
        detail: _errorMessage(e),
        level: LogLevel.warning,
      );
    } finally {
      if (!silent && _isCurrentSession(token) && _state.travelLoading) {
        _state = _state.copyWith(travelLoading: false);
        _emit();
      }
    }
  }

  Future<void> refreshTravelDetail(String travelId) async {
    final token = _state.token;
    if (token.isEmpty || travelId.trim().isEmpty) return;
    _state = _state.copyWith(
      travelDetailLoading: true,
      travelDetailError: null,
    );
    _emit();
    try {
      final response = await _apiClient.request(
        'app/centralControl/deviceTravelDetail',
        method: 'POST',
        token: token,
        body: {'deviceTravelId': travelId},
      );
      _ensureSuccess(response.body, fallback: '获取官方轨迹详情失败');
      if (!_isCurrentSession(token)) return;
      final points = OfficialCloudDataParser.travelPoints(
        response.body['data'],
      );
      final details = Map<String, List<OfficialTravelPoint>>.from(
        _state.travelDetails,
      );
      details[travelId] = points;
      _state = _state.copyWith(
        travelDetails: details,
        travelDetailLoading: false,
        travelDetailError: null,
      );
      _emit();
      _log.operation('官方轨迹详情已刷新', detail: 'points=${points.length}');
    } catch (e) {
      if (!_isCurrentSession(token)) return;
      await _handleAuthFailureIfNeeded(e);
      if (_state.signedIn) {
        _state = _state.copyWith(
          travelDetailLoading: false,
          travelDetailError: _errorMessage(e),
        );
        _emit();
      }
      rethrow;
    } finally {
      if (_isCurrentSession(token) && _state.travelDetailLoading) {
        _state = _state.copyWith(travelDetailLoading: false);
        _emit();
      }
    }
  }

  Future<void> linkLocalVehicle({
    required String officialVehicleKey,
    required String localVehicleId,
  }) async {
    await _saveLinks(
      OfficialCloudVehicleLinks.link(
        _state.localVehicleLinks,
        officialVehicleKey: officialVehicleKey,
        localVehicleId: localVehicleId,
      ),
    );
  }

  Future<void> unlinkLocalVehicle(String officialVehicleKey) async {
    await _saveLinks(
      OfficialCloudVehicleLinks.unlink(
        _state.localVehicleLinks,
        officialVehicleKey,
      ),
    );
  }

  Future<void> pruneLocalVehicleLinks(Set<String> validLocalVehicleIds) async {
    final links = OfficialCloudVehicleLinks.prune(
      _state.localVehicleLinks,
      validLocalVehicleIds,
    );
    if (links.length == _state.localVehicleLinks.length) return;
    await _saveLinks(links);
    _log.operation('官方车辆失效关联已清理');
  }

  Future<void> _applySelectedVehicleToLocalProfile() async {
    final vehicle = _state.selectedVehicle;
    if (vehicle == null) return;
    final store = VehicleStore();
    await store.init();

    final decision = OfficialCloudVehicleSyncPlanner.plan(
      selectedVehicle: vehicle,
      localVehicleLinks: _state.localVehicleLinks,
      localVehicles: store.vehicles,
    );
    if (decision == null) return;

    if (decision.linkedLocalVehicleId != null) {
      await store.setDefault(decision.linkedLocalVehicleId!);
      return;
    }

    final profileData = decision.profileData;
    if (profileData == null) return;

    final profile = await store.upsert(
      id: profileData.id,
      name: profileData.name,
      protocol: profileData.protocol,
      makeDefault: true,
    );
    if (!OfficialCloudVehicleLinks.isLinkedTo(
      _state.localVehicleLinks,
      officialVehicleKey: vehicle.key,
      localVehicleId: profile.id,
    )) {
      await _saveLinks(
        OfficialCloudVehicleLinks.link(
          _state.localVehicleLinks,
          officialVehicleKey: vehicle.key,
          localVehicleId: profile.id,
        ),
      );
    }
    _log.operation(
      '官方车辆已同步到本地车库',
      detail: '${vehicle.displayName} ${profile.id}',
    );
  }

  Future<OfficialVehicleSelfCheck> selfCheck() async {
    final vehicle = _state.selectedVehicle;
    if (_state.token.isEmpty || vehicle == null) {
      throw const OfficialCloudApiException('请先登录官方账号并选择车辆');
    }
    if (vehicle.commandImei.isEmpty) {
      throw const OfficialCloudApiException('当前车辆缺少官方 IMEI，无法云端自检');
    }

    try {
      _log.operation('发送官方云端自检');
      final response = await _apiClient.request(
        'app/device/cmd/status',
        method: 'POST',
        token: _state.token,
        body: {'imei': vehicle.commandImei},
      );
      _ensureSuccess(response.body, fallback: '云端自检失败');
      final result = OfficialVehicleSelfCheck.fromResponse(response.body);
      _log.operation(
        '官方云端自检已返回',
        detail:
            'code=${result.code?.toString() ?? 'none'}, data=${result.hasData}',
      );
      return result;
    } catch (e) {
      await _handleAuthFailureIfNeeded(e);
      _log.operation(
        '官方云端自检失败',
        detail: _errorMessage(e),
        level: LogLevel.warning,
      );
      rethrow;
    }
  }

  Future<String> sendCommand(CommandCode command) async {
    final cloudCommand = OfficialCloudCommand.fromCommandCode(command);
    if (cloudCommand == null) {
      throw OfficialCloudApiException('官方云端不支持${command.label}');
    }
    final vehicle = _state.selectedVehicle;
    if (_state.token.isEmpty || vehicle == null) {
      throw const OfficialCloudApiException('请先登录官方账号并选择车辆');
    }
    if (vehicle.commandImei.isEmpty) {
      throw const OfficialCloudApiException('当前车辆缺少官方 IMEI，无法云端控车');
    }

    try {
      _log.operation('发送官方云端指令: ${command.label}');
      final response = await _apiClient.request(
        'app/device/cmd/${cloudCommand.apiName}',
        method: 'POST',
        token: _state.token,
        body: {'imei': vehicle.commandImei},
      );
      _ensureSuccess(response.body, fallback: '${command.label}失败');
      final message = response.body['msg']?.toString();
      _log.operation('官方云端指令已返回: ${command.label}');
      _refreshVehiclesAfterCommand(command);
      return message == null || message.isEmpty ? 'success' : message;
    } catch (e) {
      await _handleAuthFailureIfNeeded(e);
      rethrow;
    }
  }

  void _refreshVehiclesAfterCommand(CommandCode command) {
    _runSilentRefresh(
      refreshVehicles(silent: true, force: true),
      failureMessage: '官方云端指令后刷新状态失败: ${command.label}',
    );
  }

  void _refreshVehicleDependents({required bool refreshReplicaDetails}) {
    _runSilentRefresh(
      refreshBatteryInfo(silent: true),
      failureMessage: '官方电池信息静默刷新失败',
    );
    if (!refreshReplicaDetails) return;
    _runSilentRefresh(
      refreshVehicleLocation(silent: true),
      failureMessage: '官方停车位置静默刷新失败',
    );
    _runSilentRefresh(
      refreshFenceData(silent: true),
      failureMessage: '官方电子围栏静默刷新失败',
    );
  }

  void _runSilentRefresh(
    Future<void> future, {
    required String failureMessage,
  }) {
    unawaited(
      future.catchError((Object e) {
        _log.operation(
          failureMessage,
          detail: _errorMessage(e),
          level: LogLevel.warning,
        );
      }),
    );
  }

  Future<void> _handleAuthFailureIfNeeded(Object e) async {
    final message = _errorMessage(e);
    if (!OfficialCloudAuthParser.looksLikeAuthError(message)) return;
    await logout();
    _state = _state.copyWith(error: '官方登录已失效，请重新登录');
    _emit();
  }

  bool _isCurrentSession(String token) {
    return token.isNotEmpty && _state.token == token;
  }

  void _ensureSuccess(Map<String, dynamic> body, {required String fallback}) {
    final code = body['code']?.toString();
    final msg = body['msg']?.toString();
    final success =
        code == '200' || code == '0' || (msg != null && msg.contains('成功'));
    if (!success) {
      throw OfficialCloudApiException(
        msg == null || msg.isEmpty ? fallback : msg,
      );
    }
  }

  void _setLoading(bool loading) {
    _state = _state.copyWith(loading: loading);
    _emit();
  }

  Future<void> _saveLinks(Map<String, String> links) async {
    await _storage.saveLinks(links);
    _state = _state.copyWith(localVehicleLinks: links);
    _emit();
  }

  String _errorMessage(Object e) {
    if (e is OfficialCloudApiException) return e.message;
    return e.toString();
  }

  bool _validPhone(String value) => RegExp(r'^\d{11}$').hasMatch(value);

  bool _validSmsCode(String value) => RegExp(r'^\d{4,8}$').hasMatch(value);

  bool _shouldUseRecentRefresh(String key) {
    final refreshedAt = _lastSuccessfulRefresh[key];
    if (refreshedAt == null) return false;
    return DateTime.now().difference(refreshedAt) < _silentRefreshTtl;
  }

  void _markRefreshSuccess(String key) {
    _lastSuccessfulRefresh[key] = DateTime.now();
  }

  void _clearRefreshCache() {
    _lastSuccessfulRefresh.clear();
    _inFlightRefreshes.clear();
  }

  String _currentMonth() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }

  void _emit() {
    _stateController.add(_state);
  }
}

extension on String {
  String ifEmpty(String Function() fallback) => isEmpty ? fallback() : this;
}
