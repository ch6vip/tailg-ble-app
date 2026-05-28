import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  final bool loading;
  final String? error;
  final List<OfficialVehicle> vehicles;
  final String? selectedVehicleKey;
  final OfficialControlChannel controlChannel;
  final Map<String, String> localVehicleLinks;

  const OfficialCloudState({
    required this.initialized,
    required this.token,
    required this.phone,
    required this.loading,
    required this.error,
    required this.vehicles,
    required this.selectedVehicleKey,
    required this.controlChannel,
    required this.localVehicleLinks,
  });

  factory OfficialCloudState.initial() => const OfficialCloudState(
    initialized: false,
    token: '',
    phone: '',
    loading: false,
    error: null,
    vehicles: [],
    selectedVehicleKey: null,
    controlChannel: OfficialControlChannel.automatic,
    localVehicleLinks: {},
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
    bool? loading,
    Object? error = _sentinel,
    List<OfficialVehicle>? vehicles,
    Object? selectedVehicleKey = _sentinel,
    OfficialControlChannel? controlChannel,
    Map<String, String>? localVehicleLinks,
  }) {
    return OfficialCloudState(
      initialized: initialized ?? this.initialized,
      token: token ?? this.token,
      phone: phone ?? this.phone,
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      vehicles: vehicles ?? this.vehicles,
      selectedVehicleKey: identical(selectedVehicleKey, _sentinel)
          ? this.selectedVehicleKey
          : selectedVehicleKey as String?,
      controlChannel: controlChannel ?? this.controlChannel,
      localVehicleLinks: localVehicleLinks ?? this.localVehicleLinks,
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
  OfficialCloudService._();

  static const _apiBase = 'https://www.tailgdd.com/v1/api/';
  static const _prefToken = 'official_cloud_token';
  static const _prefPhone = 'official_cloud_phone';
  static const _prefSelectedVehicle = 'official_cloud_selected_vehicle';
  static const _prefControlChannel = 'official_cloud_control_channel';
  static const _prefVehicleLinks = 'official_cloud_vehicle_links';

  final _log = LogService();
  final _stateController = StreamController<OfficialCloudState>.broadcast();
  OfficialCloudState _state = OfficialCloudState.initial();
  bool _initialized = false;

  Stream<OfficialCloudState> get stateStream => _stateController.stream;
  OfficialCloudState get state => _state;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final channelName = prefs.getString(_prefControlChannel);
    final linksRaw = prefs.getString(_prefVehicleLinks);
    _state = _state.copyWith(
      initialized: true,
      token: prefs.getString(_prefToken) ?? '',
      phone: prefs.getString(_prefPhone) ?? '',
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
    if (normalized.isEmpty) {
      throw const OfficialCloudApiException('请输入手机号');
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
    if (normalizedPhone.isEmpty || normalizedSms.isEmpty) {
      throw const OfficialCloudApiException('请输入手机号和验证码');
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefToken, token);
      await prefs.setString(_prefPhone, normalizedPhone);
      _state = _state.copyWith(
        token: token,
        phone: normalizedPhone,
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
    await prefs.remove(_prefToken);
    await prefs.remove(_prefPhone);
    await prefs.remove(_prefSelectedVehicle);
    _state = _state.copyWith(
      token: '',
      phone: '',
      vehicles: const [],
      selectedVehicleKey: null,
      error: null,
    );
    _emit();
    _log.operation('官方云已退出登录');
  }

  Future<void> refreshVehicles({bool silent = false}) async {
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
    } catch (e) {
      final message = _errorMessage(e);
      if (_looksLikeAuthError(message)) {
        await logout();
        _state = _state.copyWith(error: '官方登录已失效，请重新登录');
        _emit();
      } else {
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
    await refreshVehicles(silent: true);
    return message == null || message.isEmpty ? 'success' : message;
  }

  Future<_OfficialApiResponse> _request(
    String path, {
    required String method,
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = Uri.parse('$_apiBase$path');
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('Forward-ServiceIp', 'localhost');
      request.headers.set('language', 'zh_CN');
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
      throw const OfficialCloudApiException('请求超时，请检查网络');
    } on SocketException {
      throw const OfficialCloudApiException('网络不可用，请检查连接');
    } finally {
      client.close(force: true);
    }
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

  void _emit() {
    _stateController.add(_state);
  }
}
