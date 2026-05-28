import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/constants.dart';
import '../models/official_vehicle.dart';
import 'log_service.dart';

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

class OfficialCloudApiException implements Exception {
  final String message;
  final int? statusCode;

  const OfficialCloudApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class _OfficialApiResponse {
  final int statusCode;
  final Map<String, String> headers;
  final Map<String, dynamic> body;

  const _OfficialApiResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });
}

class OfficialCloudService {
  static final OfficialCloudService _instance = OfficialCloudService._();
  factory OfficialCloudService() => _instance;

  static const _apiBase = 'https://www.tailgdd.com/v1/api/';
  static const _prefToken = 'official_cloud_token';
  static const _prefPhone = 'official_cloud_phone';
  static const _secureToken = 'official_cloud_token';
  static const _securePhone = 'official_cloud_phone';
  static const _secureUserId = 'official_cloud_user_id';
  static const _prefSelectedVehicle = 'official_cloud_selected_vehicle';
  static const _prefControlChannel = 'official_cloud_control_channel';
  static const _prefVehicleLinks = 'official_cloud_vehicle_links';
  static const _prefUserId = 'official_cloud_user_id';

  final FlutterSecureStorage _secureStorage;
  final _log = LogService();
  final _stateController = StreamController<OfficialCloudState>.broadcast();
  OfficialCloudState _state = OfficialCloudState.initial();
  bool _initialized = false;
  OfficialCloudRequestSummary? _lastRequest;

  OfficialCloudService._()
    : _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(storageNamespace: 'official_cloud'),
      );

  Stream<OfficialCloudState> get stateStream => _stateController.stream;
  OfficialCloudState get state => _state;
  OfficialCloudRequestSummary? get lastRequest => _lastRequest;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final channelName = prefs.getString(_prefControlChannel);
    final linksRaw = prefs.getString(_prefVehicleLinks);
    final credentials = await _loadSecureCredentials(prefs);
    _state = _state.copyWith(
      initialized: true,
      token: credentials.$1,
      phone: credentials.$2,
      userId: credentials.$3,
      selectedVehicleKey: prefs.getString(_prefSelectedVehicle),
      controlChannel: OfficialControlChannel.values.firstWhere(
        (item) => item.name == channelName,
        orElse: () => OfficialControlChannel.automatic,
      ),
      localVehicleLinks: _decodeLinks(linksRaw),
    );
    _initialized = true;
    _emit();
    if (_state.token.isNotEmpty) {
      unawaited(refreshVehicles(silent: true));
    }
  }

  Future<void> requestSmsCode(String phone) async {
    final normalized = phone.trim();
    if (!_validPhone(normalized)) {
      throw const OfficialCloudApiException('请输入 11 位手机号');
    }
    _setLoading(true);
    try {
      final response = await _request(
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
      final response = await _request(
        'app/login',
        method: 'POST',
        body: {
          'macCode': '000000000000',
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

      final userId = _extractUserId(response.body);
      await _saveSecureCredentials(
        token: token,
        phone: normalizedPhone,
        userId: userId,
      );
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
    final prefs = await SharedPreferences.getInstance();
    await _clearSecureCredentials(prefs);
    await prefs.remove(_prefSelectedVehicle);
    _state = _state.copyWith(
      token: '',
      phone: '',
      userId: '',
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
  }) async {
    if (_state.token.isEmpty) return;
    if (!silent) _setLoading(true);
    try {
      final response = await _request(
        'app/centralControl/carStatus',
        method: 'POST',
        token: _state.token,
        body: {'phoneMode': 'SM-G998B'},
      );
      _ensureSuccess(response.body, fallback: '获取官方车辆失败');
      final data = response.body['data'];
      final List<dynamic> items = data is List
          ? data
          : data == null
          ? []
          : [data];
      final vehicles = items
          .whereType<Map>()
          .map(
            (item) => OfficialVehicle.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((vehicle) => vehicle.key.isNotEmpty)
          .toList(growable: false);
      var selected = _state.selectedVehicleKey;
      if (vehicles.isEmpty) {
        selected = null;
      } else if (selected == null ||
          !vehicles.any((vehicle) => vehicle.key == selected)) {
        selected = vehicles.first.key;
      }
      final prefs = await SharedPreferences.getInstance();
      if (selected == null) {
        await prefs.remove(_prefSelectedVehicle);
      } else {
        await prefs.setString(_prefSelectedVehicle, selected);
      }
      _state = _state.copyWith(
        vehicles: vehicles,
        selectedVehicleKey: selected,
        error: null,
      );
      _emit();
      _log.operation('官方车辆列表已刷新', detail: 'count=${vehicles.length}');
      unawaited(refreshBatteryInfo(silent: true));
      if (refreshReplicaDetails) {
        unawaited(refreshVehicleLocation(silent: true));
        unawaited(refreshFenceData(silent: true));
      }
    } catch (e) {
      await _handleAuthFailureIfNeeded(e);
      if (_state.signedIn) {
        final message = _errorMessage(e);
        _state = _state.copyWith(error: message);
        _emit();
      }
      rethrow;
    } finally {
      if (!silent) _setLoading(false);
    }
  }

  Future<void> selectVehicle(OfficialVehicle vehicle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSelectedVehicle, vehicle.key);
    _state = _state.copyWith(selectedVehicleKey: vehicle.key);
    _emit();
  }

  Future<void> setControlChannel(OfficialControlChannel channel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefControlChannel, channel.name);
    _state = _state.copyWith(controlChannel: channel);
    _emit();
  }

  Future<void> refreshBatteryInfo({bool silent = false}) async {
    if (_state.token.isEmpty) return;
    if (!silent) {
      _state = _state.copyWith(
        batteryInfoLoading: true,
        batteryInfoError: null,
      );
      _emit();
    }
    try {
      final response = await _request(
        'app/mine/batteryInfo',
        method: 'POST',
        token: _state.token,
      );
      _ensureSuccess(response.body, fallback: '获取官方电池信息失败');
      final data = response.body['data'];
      final info = data is Map
          ? OfficialBatteryInfo.fromJson(Map<String, dynamic>.from(data))
          : OfficialBatteryInfo.fromJson(const <String, dynamic>{});
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
    } catch (e) {
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
      if (!silent && _state.batteryInfoLoading) {
        _state = _state.copyWith(batteryInfoLoading: false);
        _emit();
      }
    }
  }

  Future<void> refreshVehicleLocation({bool silent = false}) async {
    final vehicle = _state.selectedVehicle;
    if (_state.token.isEmpty || vehicle == null || vehicle.carId.isEmpty) {
      return;
    }
    if (!silent) {
      _state = _state.copyWith(
        vehicleLocationLoading: true,
        vehicleLocationError: null,
      );
      _emit();
    }
    try {
      final response = await _request(
        'app/car/extend/getByCarId',
        method: 'POST',
        token: _state.token,
        body: {'carId': vehicle.carId},
      );
      _ensureSuccess(response.body, fallback: '获取官方停车位置失败');
      final data = response.body['data'];
      final location = data is Map
          ? OfficialVehicleLocation.fromJson(Map<String, dynamic>.from(data))
          : OfficialVehicleLocation.fromJson(const <String, dynamic>{});
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
    } catch (e) {
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
      if (!silent && _state.vehicleLocationLoading) {
        _state = _state.copyWith(vehicleLocationLoading: false);
        _emit();
      }
    }
  }

  Future<void> refreshFenceData({bool silent = false}) async {
    final vehicle = _state.selectedVehicle;
    if (_state.token.isEmpty || vehicle == null || vehicle.carId.isEmpty) {
      return;
    }
    if (!silent) {
      _state = _state.copyWith(fenceLoading: true, fenceError: null);
      _emit();
    }
    try {
      final response = await _request(
        'app/device/getFenceData',
        method: 'POST',
        token: _state.token,
        body: {'carId': vehicle.carId},
      );
      _ensureSuccess(response.body, fallback: '获取官方围栏失败');
      final data = response.body['data'];
      final fence = data is Map
          ? OfficialFenceData.fromJson(Map<String, dynamic>.from(data))
          : OfficialFenceData.fromJson(const <String, dynamic>{});
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
    } catch (e) {
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
      if (!silent && _state.fenceLoading) {
        _state = _state.copyWith(fenceLoading: false);
        _emit();
      }
    }
  }

  Future<void> refreshTravelHistory({
    String? month,
    bool silent = false,
  }) async {
    final vehicle = _state.selectedVehicle;
    if (_state.token.isEmpty || vehicle == null) return;
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
    if (!silent) {
      _state = _state.copyWith(
        travelLoading: true,
        travelError: null,
        travelMonth: queryMonth,
      );
      _emit();
    }
    try {
      final response = await _request(
        'app/centralControl/deviceTravel',
        method: 'POST',
        token: _state.token,
        body: {'queryMonth': queryMonth, 'frame': vehicle.frame, 'uid': userId},
      );
      _ensureSuccess(response.body, fallback: '获取官方历史轨迹失败');
      final data = response.body['data'];
      final days = data is List
          ? data
                .whereType<Map>()
                .map(
                  (item) => OfficialTravelDay.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((day) => day.hasData)
                .toList(growable: false)
          : const <OfficialTravelDay>[];
      _state = _state.copyWith(
        travelDays: days,
        travelMonth: queryMonth,
        travelLoading: false,
        travelError: null,
      );
      _emit();
      _log.operation('官方历史轨迹已刷新', detail: 'days=${days.length}');
    } catch (e) {
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
      if (!silent && _state.travelLoading) {
        _state = _state.copyWith(travelLoading: false);
        _emit();
      }
    }
  }

  Future<void> refreshTravelDetail(String travelId) async {
    if (_state.token.isEmpty || travelId.trim().isEmpty) return;
    _state = _state.copyWith(
      travelDetailLoading: true,
      travelDetailError: null,
    );
    _emit();
    try {
      final response = await _request(
        'app/centralControl/deviceTravelDetail',
        method: 'POST',
        token: _state.token,
        body: {'deviceTravelId': travelId},
      );
      _ensureSuccess(response.body, fallback: '获取官方轨迹详情失败');
      final data = response.body['data'];
      final points = data is List
          ? data
                .whereType<Map>()
                .map(
                  (item) => OfficialTravelPoint.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((point) => point.hasCoordinate)
                .toList(growable: false)
          : const <OfficialTravelPoint>[];
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
      if (_state.travelDetailLoading) {
        _state = _state.copyWith(travelDetailLoading: false);
        _emit();
      }
    }
  }

  Future<void> linkLocalVehicle({
    required String officialVehicleKey,
    required String localVehicleId,
  }) async {
    final links = Map<String, String>.from(_state.localVehicleLinks);
    links[officialVehicleKey] = localVehicleId;
    await _saveLinks(links);
  }

  Future<void> unlinkLocalVehicle(String officialVehicleKey) async {
    final links = Map<String, String>.from(_state.localVehicleLinks);
    links.remove(officialVehicleKey);
    await _saveLinks(links);
  }

  Future<void> pruneLocalVehicleLinks(Set<String> validLocalVehicleIds) async {
    final links = Map<String, String>.from(_state.localVehicleLinks);
    links.removeWhere((_, localVehicleId) {
      return !validLocalVehicleIds.contains(localVehicleId);
    });
    if (links.length == _state.localVehicleLinks.length) return;
    await _saveLinks(links);
    _log.operation('官方车辆失效关联已清理');
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
      final response = await _request(
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
      final response = await _request(
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
    unawaited(
      refreshVehicles(silent: true).catchError((Object e) {
        _log.operation(
          '官方云端指令后刷新状态失败: ${command.label}',
          detail: _errorMessage(e),
          level: LogLevel.warning,
        );
      }),
    );
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

  Future<void> _saveSecureCredentials({
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
  }

  Future<void> _clearSecureCredentials(SharedPreferences prefs) async {
    await _secureStorage.delete(key: _secureToken);
    await _secureStorage.delete(key: _securePhone);
    await _secureStorage.delete(key: _secureUserId);
    await prefs.remove(_prefToken);
    await prefs.remove(_prefPhone);
    await prefs.remove(_prefUserId);
  }

  Future<void> _handleAuthFailureIfNeeded(Object e) async {
    final message = _errorMessage(e);
    if (!_looksLikeAuthError(message)) return;
    await logout();
    _state = _state.copyWith(error: '官方登录已失效，请重新登录');
    _emit();
  }

  Future<_OfficialApiResponse> _request(
    String path, {
    required String method,
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    final startedAt = DateTime.now();
    try {
      final uri = Uri.parse('$_apiBase$path');
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('Forward-Service-Ip', 'localhost');
      request.headers.set('Forward-ServiceIp', 'localhost');
      request.headers.set('language', 'zh_CN');
      request.headers.set(HttpHeaders.acceptLanguageHeader, 'zh_CN');
      request.headers.set('Zone-id', 'UTC+08:00');
      request.headers.set('Api-Version', '3.0.0');
      request.headers.set(HttpHeaders.userAgentHeader, 'okhttp/4.9.3');
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, token);
      }
      if (body != null) {
        request.add(utf8.encode(jsonEncode(body)));
      }

      final response = await request.close().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw const OfficialCloudApiException('请求超时，请检查网络'),
      );
      final text = await response.transform(utf8.decoder).join();
      final decoded = _decodeBody(text);
      _recordRequest(
        path: path,
        method: method,
        startedAt: startedAt,
        statusCode: response.statusCode,
        body: decoded,
      );
      final headers = <String, String>{};
      response.headers.forEach((name, values) {
        if (values.isNotEmpty) headers[name.toLowerCase()] = values.first;
      });
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OfficialCloudApiException(
          decoded['msg']?.toString() ?? '官方接口返回 ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      return _OfficialApiResponse(
        statusCode: response.statusCode,
        headers: headers,
        body: decoded,
      );
    } on TimeoutException {
      _recordRequestFailure(
        path: path,
        method: method,
        startedAt: startedAt,
        message: '请求超时，请检查网络',
      );
      throw const OfficialCloudApiException('请求超时，请检查网络');
    } on SocketException {
      _recordRequestFailure(
        path: path,
        method: method,
        startedAt: startedAt,
        message: '网络不可用，请检查连接',
      );
      throw const OfficialCloudApiException('网络不可用，请检查连接');
    } on OfficialCloudApiException catch (e) {
      _recordRequestFailure(
        path: path,
        method: method,
        startedAt: startedAt,
        message: e.message,
        statusCode: e.statusCode,
      );
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  void _recordRequest({
    required String path,
    required String method,
    required DateTime startedAt,
    required int statusCode,
    required Map<String, dynamic> body,
  }) {
    final elapsed = DateTime.now().difference(startedAt);
    final code = body['code']?.toString();
    final msg = _shortMessage(body['msg']?.toString());
    _lastRequest = OfficialCloudRequestSummary(
      path: path,
      method: method,
      statusCode: statusCode,
      code: code,
      message: msg,
      elapsed: elapsed,
      success: statusCode >= 200 && statusCode < 300,
      at: DateTime.now(),
    );
    _log.operation(
      '官方云接口返回',
      detail:
          '$method $path status=$statusCode code=${code ?? 'none'} elapsed=${elapsed.inMilliseconds}ms msg=${msg ?? 'none'}',
      level: LogLevel.debug,
    );
  }

  void _recordRequestFailure({
    required String path,
    required String method,
    required DateTime startedAt,
    required String message,
    int? statusCode,
  }) {
    final elapsed = DateTime.now().difference(startedAt);
    _lastRequest = OfficialCloudRequestSummary(
      path: path,
      method: method,
      statusCode: statusCode,
      code: null,
      message: _shortMessage(message),
      elapsed: elapsed,
      success: false,
      at: DateTime.now(),
    );
    _log.operation(
      '官方云接口失败',
      detail:
          '$method $path status=${statusCode?.toString() ?? 'none'} elapsed=${elapsed.inMilliseconds}ms msg=${_shortMessage(message)}',
      level: LogLevel.warning,
    );
  }

  String? _shortMessage(String? message) {
    if (message == null || message.trim().isEmpty) return null;
    final normalized = message.trim();
    if (normalized.length <= 80) return normalized;
    return normalized.substring(0, 80);
  }

  Map<String, dynamic> _decodeBody(String text) {
    if (text.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      final end = text.length < 80 ? text.length : 80;
      throw OfficialCloudApiException(
        '服务器返回非 JSON 数据: ${text.substring(0, end)}',
      );
    }
    throw const OfficialCloudApiException('服务器返回数据格式不正确');
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefVehicleLinks, jsonEncode(links));
    _state = _state.copyWith(localVehicleLinks: links);
    _emit();
  }

  Map<String, String> _decodeLinks(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
    } catch (_) {
      return {};
    }
    return {};
  }

  bool _looksLikeAuthError(String message) {
    return message.contains('token') ||
        message.contains('登录') ||
        message.contains('认证') ||
        message.contains('授权') ||
        message.contains('401') ||
        message.contains('403') ||
        message.contains('过期') ||
        message.contains('失效');
  }

  String _errorMessage(Object e) {
    if (e is OfficialCloudApiException) return e.message;
    return e.toString();
  }

  bool _validPhone(String value) => RegExp(r'^\d{11}$').hasMatch(value);

  bool _validSmsCode(String value) => RegExp(r'^\d{4,8}$').hasMatch(value);

  String _extractUserId(Map<String, dynamic> body) {
    Object? find(Object? value) {
      if (value is Map) {
        for (final key in const ['uid', 'userId', 'id']) {
          final candidate = value[key];
          if (candidate != null && candidate.toString().trim().isNotEmpty) {
            return candidate;
          }
        }
        for (final child in value.values) {
          final found = find(child);
          if (found != null) return found;
        }
      } else if (value is List) {
        for (final child in value) {
          final found = find(child);
          if (found != null) return found;
        }
      }
      return null;
    }

    return find(body)?.toString().trim() ?? '';
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

class OfficialCloudRequestSummary {
  final String path;
  final String method;
  final int? statusCode;
  final String? code;
  final String? message;
  final Duration elapsed;
  final bool success;
  final DateTime at;

  const OfficialCloudRequestSummary({
    required this.path,
    required this.method,
    required this.statusCode,
    required this.code,
    required this.message,
    required this.elapsed,
    required this.success,
    required this.at,
  });
}
