import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/command_types.dart';
import '../models/official_user_profile.dart';
import '../models/official_vehicle.dart';
import '../models/persistence_value.dart';
import '../models/vehicle_profile.dart';
import 'display_time_formatter.dart';
import 'log_service.dart';
import 'sensitive_value_masker.dart';
import 'vehicle_store.dart';

part 'official_cloud_state.dart';
part 'official_cloud_api_client.dart';
part 'official_cloud_auth_parser.dart';
part 'official_cloud_data_parser.dart';
part 'official_cloud_vehicle_mapper.dart';
part 'official_cloud_vehicle_links.dart';
part 'official_cloud_vehicle_sync.dart';
part 'official_cloud_storage.dart';

class OfficialCloudService {
  static final OfficialCloudService _instance = OfficialCloudService._();
  factory OfficialCloudService() => _instance;
  static const _silentRefreshTtl = Duration(seconds: 45);

  final _log = LogService();
  final _storage = _OfficialCloudStorage();
  OfficialCloudApiClient _apiClient = OfficialCloudApiClient(
    config: const OfficialCloudApiConfig(),
    log: LogService(),
  );
  DateTime Function() _clock = DateTime.now;
  StreamController<OfficialCloudState> _stateController =
      StreamController<OfficialCloudState>.broadcast();
  OfficialCloudState _state = OfficialCloudState.initial();
  final Map<String, DateTime> _lastSuccessfulRefresh = {};
  final Map<String, Future<void>> _inFlightRefreshes = {};
  bool _initialized = false;
  Future<void>? _initializing;
  bool _disposed = false;

  OfficialCloudService._();

  Stream<OfficialCloudState> get stateStream => _stateController.stream;
  OfficialCloudState get state => _state;
  OfficialCloudRequestSummary? get lastRequest => _apiClient.lastRequest;
  DateTime? get lastVehiclesRefreshAt => _lastSuccessfulRefresh['vehicles'];
  DateTime? get lastBatteryRefreshAt => _lastSuccessfulRefresh['batteryInfo'];

  Future<void> init() => _init(refreshOnSignedIn: true);

  @visibleForTesting
  Future<void> initForTest({bool refreshOnSignedIn = false}) {
    return _init(refreshOnSignedIn: refreshOnSignedIn);
  }

  Future<void> _init({required bool refreshOnSignedIn}) async {
    if (_initialized) return;
    final initializing = _initializing;
    if (initializing != null) return initializing;
    final loading = _loadInitialSession(refreshOnSignedIn: refreshOnSignedIn);
    _initializing = loading;
    return loading;
  }

  Future<void> _loadInitialSession({required bool refreshOnSignedIn}) async {
    try {
      final stored = await _storage.loadSession();
      final cachedVehicles = stored.token.isEmpty
          ? const <OfficialVehicle>[]
          : stored.cachedVehicles;
      final selectedVehicleKey = _selectVehicleKey(
        cachedVehicles,
        stored.selectedVehicleKey,
      );
      _state = _state.copyWith(
        initialized: true,
        token: stored.token,
        phone: stored.phone,
        userId: stored.userId,
        userProfile: stored.cachedUserProfile,
        vehicles: cachedVehicles,
        selectedVehicleKey: selectedVehicleKey,
        localVehicleLinks: stored.localVehicleLinks,
      );
      _initialized = true;
      _emit();
      if (_state.selectedVehicle != null) {
        _runSilentRefresh(
          _applySelectedVehicleToLocalProfile(),
          failureMessage: '官方缓存车辆同步到本地车库失败',
        );
      }
      if (refreshOnSignedIn && _state.token.isNotEmpty) {
        _runSilentRefresh(
          refreshVehicles(silent: true),
          failureMessage: '官方车辆静默刷新失败',
        );
        _runSilentRefresh(
          refreshUserProfile(silent: true),
          failureMessage: '官方用户资料静默刷新失败',
        );
      }
    } finally {
      _initializing = null;
    }
  }

  Future<void> requestSmsCode(String phone) async {
    final normalized = phone.trim();
    if (!OfficialCloudLoginValidator.isValidPhone(normalized)) {
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
    if (!OfficialCloudLoginValidator.isValidPhone(normalizedPhone)) {
      throw const OfficialCloudApiException('请输入 11 位手机号');
    }
    if (!OfficialCloudLoginValidator.isValidSmsCode(normalizedSms)) {
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
        userProfile: null,
        vehicles: const [],
        selectedVehicleKey: null,
        error: null,
      );
      _emit();
      _log.operation('官方云登录成功');
      await Future.wait<void>([
        refreshVehicles(),
        refreshUserProfile(silent: true),
      ]);
    } finally {
      _setLoading(false);
    }
  }

  /// Restore an existing official session from a pasted Authorization token.
  ///
  /// Accepts either a raw token or a `Bearer ...` value. Unlike SMS login, the
  /// caller does not bring a verified [userId]/[phone]; pasted material is only
  /// a hint. The token is treated as **unverified** until it successfully pulls
  /// vehicles/profile from the server — a signed-in state is only committed
  /// (and persisted) once that server round-trip proves the token live. This
  /// matches official cold-start behaviour (local token → auth-gated fetch →
  /// online), so a Token login ends in the same usable session state as SMS.
  ///
  /// On any auth/transport failure during hydration we discard the candidate
  /// session and rethrow, so the UI shows "登录失败" rather than a fake
  /// signed-in state. [phone]/[userId] are best-effort seeds; the hydrated
  /// session overwrites them with server-derived values when available.
  Future<void> loginWithToken(
    String rawToken, {
    String phone = '',
    String userId = '',
  }) async {
    final token = _normalizeAuthorizationToken(rawToken);
    if (token.isEmpty) {
      throw const OfficialCloudApiException('请粘贴有效的官方 Token');
    }
    _setLoading(true);
    try {
      await _hydrateOfficialSession(
        token: token,
        seedPhone: phone,
        seedUserId: userId,
      );
      _log.operation('官方云 Token 登录成功');
    } finally {
      _setLoading(false);
    }
  }

  /// Shared "make this token a usable signed-in session" routine.
  ///
  /// Used by [loginWithToken]; SMS [login] keeps its own path because it
  /// already has verified phone/userId from the login response and must not
  /// be blocked by a separate profile fetch (historical behaviour).
  ///
  /// 1. Stage the candidate token/phone/userId in-memory so callers see it,
  ///    but do not persist until verification.
  /// 2. Pull vehicles + profile using the candidate token. Either succeeding
  ///    proves the token is live. 401/transport failures abort.
  /// 3. Backfill [userId]/[phone] from server responses when available; only
  ///    non-empty server values replace the seeds.
  /// 4. Persist the now-verified credentials and emit signedIn.
  /// 5. On failure: drop the staged state, clear seeds, and rethrow.
  Future<void> _hydrateOfficialSession({
    required String token,
    String seedPhone = '',
    String seedUserId = '',
  }) async {
    // Stage candidate session in-memory (unverified). Do NOT save to disk yet.
    _clearRefreshCache();
    _state = _state.copyWith(
      token: token,
      phone: seedPhone.trim(),
      userId: seedUserId.trim(),
      userProfile: null,
      vehicles: const [],
      selectedVehicleKey: null,
      error: null,
    );
    _emit();

    final String verifiedUserId;
    final verifiedPhone = seedPhone.trim();
    try {
      await refreshVehicles();
      await refreshUserProfile(silent: true);

      // userId first from profile, then from current state (refreshVehicles may
      // have populated it via parsed payload), then keep the seed.
      final profileUserId = _state.userProfile?.id.trim() ?? '';
      final stateUserId = _state.userId.trim();
      verifiedUserId = profileUserId.isNotEmpty
          ? profileUserId
          : (stateUserId.isNotEmpty ? stateUserId : seedUserId.trim());
    } catch (e) {
      // Verification failed: the token is not a usable session. Discard it so
      // the UI does not show a fake signed-in state, then rethrow.
      await _abortCandidateSession();
      rethrow;
    }

    // Persist only after a successful server round-trip. An empty userId here
    // is acceptable (some payloads omit it); refresh travel/history will guide
    // the user to re-login when it actually needs uid.
    await _storage.saveCredentials(
      token: token,
      phone: verifiedPhone,
      userId: verifiedUserId,
    );
    _state = _state.copyWith(userId: verifiedUserId);
    _emit();
  }

  /// Drop an unverified staged candidate session without running logout side
  /// effects (this candidate never reached MQTT/BLE).
  Future<void> _abortCandidateSession() async {
    await _storage.clearCredentialsAndSelection();
    _clearRefreshCache();
    _inFlightRefreshes.clear();
    _state = _state.copyWith(
      token: '',
      phone: '',
      userId: '',
      userProfile: null,
      vehicles: const [],
      selectedVehicleKey: null,
      error: null,
    );
    _emit();
  }

  static String _normalizeAuthorizationToken(String raw) {
    var token = raw.trim();
    if (token.isEmpty) return '';
    // Users often paste `Authorization: Bearer xxx` or multi-line headers.
    final authLine = RegExp(
      r'authorization\s*:\s*(.+)$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(token);
    if (authLine != null) {
      token = authLine.group(1)!.trim();
    }
    token = token.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (token.toLowerCase().startsWith('bearer ')) {
      final value = token.substring(7).trim();
      return value.isEmpty ? '' : 'Bearer $value';
    }
    // Official login already stores the header value as-is; keep non-Bearer
    // tokens unchanged so they match server expectations.
    return token;
  }

  Future<void> logout() async {
    await _storage.clearCredentialsAndSelection();
    _clearRefreshCache();
    _inFlightRefreshes.clear();
    _state = _state.copyWith(
      token: '',
      phone: '',
      userId: '',
      userProfile: null,
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
      todayRideMileage: '',
      vehicleMessages: [],
      systemMessages: [],
      messagesLoading: false,
      messagesError: null,
    );
    _emit();
    // P1-4: tear down MQTT / BLE control sessions after cloud session is cleared.
    final sideEffects = List<Future<void> Function()>.of(
      afterLogoutSideEffects,
    );
    for (final effect in sideEffects) {
      try {
        await effect();
      } catch (e) {
        _log.operation(
          '退出登录后通道清理失败',
          detail: e.toString(),
          level: LogLevel.warning,
        );
      }
    }
    _log.operation('官方云已退出登录');
  }

  /// Fetch official user profile (`POST app/getUserProfile`).
  ///
  /// Decompiled [HomeViewModel] loads this with menu dict after login so the
  /// mine page can show nickName / avatar. Failures are soft when [silent].
  Future<void> refreshUserProfile({
    bool silent = false,
    bool force = false,
  }) async {
    final token = _state.token;
    if (token.isEmpty) return;
    const refreshKey = 'userProfile';
    await _coalesceRefresh(
      refreshKey: refreshKey,
      silent: silent,
      force: force,
      run: () => _refreshUserProfileNow(
        silent: silent,
        refreshKey: refreshKey,
        token: token,
      ),
    );
  }

  Future<void> _refreshUserProfileNow({
    required bool silent,
    required String refreshKey,
    required String token,
  }) async {
    try {
      final response = await _apiClient.request(
        'app/getUserProfile',
        method: 'POST',
        token: token,
        retryPolicy: OfficialCloudRetryPolicy.readRequest,
      );
      _ensureSuccess(response.body, fallback: '获取官方用户资料失败');
      if (!_isCurrentSession(token)) return;
      final profile = OfficialCloudDataParser.userProfile(
        response.body['data'],
      );
      _state = _state.copyWith(userProfile: profile);
      _emit();
      unawaited(_storage.saveUserProfile(profile));
      _log.operation(
        '官方用户资料已刷新',
        detail: profile == null
            ? 'empty'
            : 'nick=${SensitiveValueMasker.compact(profile.displayName)}',
      );
      _markRefreshSuccess(refreshKey);
    } catch (e) {
      if (!_isCurrentSession(token)) return;
      await _handleAuthFailureIfNeeded(e);
      if (!silent) rethrow;
      _log.operation(
        '官方用户资料刷新失败',
        detail: OfficialCloudRedactor.errorMessage(e),
        level: LogLevel.warning,
      );
    }
  }

  /// Update official profile nickname (`POST app/updateUserProfile`).
  ///
  /// Decompiled [TailgRepository.updUserDetailInfo] sends the full profile map;
  /// we reuse cached fields and only change [nickName].
  Future<void> updateUserNickname(String nickName) async {
    final token = _state.token;
    if (token.isEmpty) {
      throw const OfficialCloudApiException('请先登录官方账号');
    }
    final trimmed = nickName.trim();
    if (trimmed.isEmpty) {
      throw const OfficialCloudApiException('昵称不能为空');
    }
    if (trimmed.length > 20) {
      throw const OfficialCloudApiException('昵称请控制在 20 字以内');
    }

    final current = _state.userProfile;
    final body = <String, dynamic>{
      'nickName': trimmed,
      if (current != null) ...{
        if (current.obsAvatarId.isNotEmpty) 'obsAvatarId': current.obsAvatarId,
        if (current.gender.isNotEmpty) 'gender': current.gender,
        if (current.province.isNotEmpty) 'province': current.province,
        if (current.city.isNotEmpty) 'city': current.city,
        if (current.area.isNotEmpty) 'area': current.area,
        if (current.address.isNotEmpty) 'address': current.address,
        if (current.signature.isNotEmpty) 'signature': current.signature,
        if (current.birthday.isNotEmpty) 'birthDay': current.birthday,
      },
    };

    final response = await _apiClient.request(
      'app/updateUserProfile',
      method: 'POST',
      token: token,
      body: body,
    );
    _ensureSuccess(response.body, fallback: '更新昵称失败');
    if (!_isCurrentSession(token)) return;

    final next =
        (current ??
                const OfficialUserProfile(
                  id: '',
                  nickName: '',
                  name: '',
                  signature: '',
                  avatarName: '',
                  avatarPath: '',
                  gender: '',
                  birthday: '',
                ))
            .copyWith(nickName: trimmed);
    _state = _state.copyWith(userProfile: next);
    _emit();
    unawaited(_storage.saveUserProfile(next));
    _log.operation(
      '官方昵称已更新',
      detail: 'nick=${SensitiveValueMasker.compact(trimmed)}',
    );
    // Re-fetch so server-normalized fields win.
    unawaited(refreshUserProfile(silent: true, force: true));
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
    await _coalesceRefresh(
      refreshKey: refreshKey,
      silent: silent,
      force: force,
      run: () => _refreshVehiclesNow(
        silent: silent,
        refreshReplicaDetails: refreshReplicaDetails,
        refreshKey: refreshKey,
        token: token,
      ),
    );
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
        retryPolicy: OfficialCloudRetryPolicy.readRequest,
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
      await Future.wait([
        _storage.saveSelectedVehicleKey(selected),
        _storage.saveCarControlInfo(_vehicleByKey(vehicles, selected)),
      ]);
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
        final message = OfficialCloudRedactor.errorMessage(e);
        _state = _state.copyWith(error: message);
        _emit();
      }
      rethrow;
    } finally {
      if (!silent && _isCurrentSession(token)) _setLoading(false);
    }
  }

  Future<void> refreshMessages({
    bool silent = false,
    bool force = false,
    int pageSize = 20,
    int pageIndex = 1,
  }) async {
    final token = _state.token;
    if (token.isEmpty) {
      throw const OfficialCloudApiException(
        OfficialCloudMessages.signInRequired,
      );
    }
    const refreshKey = 'messages';
    await _coalesceRefresh(
      refreshKey: refreshKey,
      silent: silent,
      force: force,
      run: () => _refreshMessagesNow(
        silent: silent,
        refreshKey: refreshKey,
        token: token,
        pageSize: pageSize,
        pageIndex: pageIndex,
      ),
    );
  }

  Future<void> _refreshMessagesNow({
    required bool silent,
    required String refreshKey,
    required String token,
    required int pageSize,
    required int pageIndex,
  }) async {
    if (!silent) {
      _state = _state.copyWith(messagesLoading: true, messagesError: null);
      _emit();
    }
    try {
      final userId = _state.userId.trim();
      final vehicleBody = <String, Object?>{
        'pageSize': pageSize,
        'nowPageIndex': pageIndex,
      };
      if (userId.isNotEmpty) {
        vehicleBody['uid'] = userId;
      }
      final systemBody = <String, Object?>{
        'pageSize': pageSize,
        'nowPageIndex': pageIndex,
      };

      final responses = await Future.wait([
        _apiClient.request(
          'app/msg/pageOfCarMsg',
          method: 'POST',
          token: token,
          body: vehicleBody,
          retryPolicy: OfficialCloudRetryPolicy.readRequest,
        ),
        _apiClient.request(
          'app/msg/pageOfSysMsg',
          method: 'POST',
          token: token,
          body: systemBody,
          retryPolicy: OfficialCloudRetryPolicy.readRequest,
        ),
      ]);
      if (!_isCurrentSession(token)) return;

      final vehicleResponse = responses[0];
      final systemResponse = responses[1];
      _ensureSuccess(vehicleResponse.body, fallback: '获取车辆消息失败');
      _ensureSuccess(systemResponse.body, fallback: '获取系统消息失败');

      final vehicleMessages = OfficialCloudDataParser.vehicleMessages(
        vehicleResponse.body['data'],
      );
      final systemMessages = OfficialCloudDataParser.systemMessages(
        systemResponse.body['data'],
      );
      _state = _state.copyWith(
        vehicleMessages: vehicleMessages,
        systemMessages: systemMessages,
        messagesLoading: false,
        messagesError: null,
      );
      _emit();
      _log.operation(
        '官方消息已刷新',
        detail:
            'vehicle=${vehicleMessages.length} system=${systemMessages.length}',
      );
      _markRefreshSuccess(refreshKey);
    } catch (e) {
      if (!_isCurrentSession(token)) return;
      await _handleAuthFailureIfNeeded(e);
      if (_state.signedIn) {
        final message = OfficialCloudRedactor.errorMessage(e);
        _state = _state.copyWith(
          messagesLoading: false,
          messagesError: message,
        );
        _emit();
      }
      rethrow;
    } finally {
      if (!silent && _isCurrentSession(token) && _state.messagesLoading) {
        _state = _state.copyWith(messagesLoading: false);
        _emit();
      }
    }
  }

  Future<void> selectVehicle(OfficialVehicle vehicle) async {
    final override = selectVehicleOverride;
    if (override != null) {
      await override(vehicle);
      return;
    }
    final changed = _state.selectedVehicleKey != vehicle.key;
    await Future.wait([
      _storage.saveSelectedVehicleKey(vehicle.key),
      _storage.saveCarControlInfo(vehicle),
    ]);
    if (changed) {
      _state = _state.copyWith(
        selectedVehicleKey: vehicle.key,
        batteryInfo: null,
        batteryInfoError: null,
        vehicleLocation: null,
        vehicleLocationError: null,
        fenceData: null,
        fenceError: null,
        travelDays: const [],
        travelDetails: const {},
        travelError: null,
      );
    } else {
      _state = _state.copyWith(selectedVehicleKey: vehicle.key);
    }
    _emit();
    await _applySelectedVehicleToLocalProfile();
    if (changed) {
      _refreshVehicleDependents(refreshReplicaDetails: true);
    }
  }

  /// Apply MQTT status telemetry to the currently selected vehicle list entry.
  ///
  /// Mirrors ControlFragment messageArrived ACC/defenceStatus writes.
  void applyMqttVehicleStatus({int? acc, int? defenceStatus}) {
    if (_disposed) return;
    final current = _state.selectedVehicle;
    if (current == null) return;
    if (acc == null && defenceStatus == null) return;

    final nextAcc = acc ?? current.acc;
    final nextDefence = defenceStatus ?? current.defenceStatus;
    if (nextAcc == current.acc && nextDefence == current.defenceStatus) {
      return;
    }

    final updated = current.copyWith(acc: nextAcc, defenceStatus: nextDefence);
    final vehicles = _state.vehicles
        .map((vehicle) => vehicle.key == updated.key ? updated : vehicle)
        .toList(growable: false);
    _state = _state.copyWith(vehicles: vehicles);
    _emit();
    unawaited(_storage.saveCarControlInfo(updated));
    _log.operation(
      '官方 MQTT 状态已更新',
      detail: 'acc=$nextAcc defenceStatus=$nextDefence',
    );
  }

  Future<void> refreshBatteryInfo({
    bool silent = false,
    bool force = false,
  }) async {
    final token = _state.token;
    if (token.isEmpty) return;
    const refreshKey = 'batteryInfo';
    await _coalesceRefresh(
      refreshKey: refreshKey,
      silent: silent,
      force: force,
      run: () => _refreshBatteryInfoNow(
        silent: silent,
        refreshKey: refreshKey,
        token: token,
      ),
    );
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
        retryPolicy: OfficialCloudRetryPolicy.readRequest,
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
        final message = OfficialCloudRedactor.errorMessage(e);
        _state = _state.copyWith(
          batteryInfoLoading: false,
          batteryInfoError: message,
        );
        _emit();
      }
      if (!silent) rethrow;
      _log.operation(
        '官方电池信息刷新失败',
        detail: OfficialCloudRedactor.errorMessage(e),
        level: LogLevel.warning,
      );
    } finally {
      if (!silent && _isCurrentSession(token) && _state.batteryInfoLoading) {
        _state = _state.copyWith(batteryInfoLoading: false);
        _emit();
      }
    }
  }

  Future<void> refreshVehicleLocation({
    bool silent = false,
    bool force = false,
  }) async {
    final token = _state.token;
    final vehicle = _state.selectedVehicle;
    if (token.isEmpty || vehicle == null || vehicle.carId.isEmpty) {
      return;
    }
    final refreshKey = 'vehicleLocation:${vehicle.key}';
    await _coalesceRefresh(
      refreshKey: refreshKey,
      silent: silent,
      force: force,
      run: () => _refreshVehicleLocationNow(
        silent: silent,
        refreshKey: refreshKey,
        vehicle: vehicle,
        token: token,
      ),
    );
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
        retryPolicy: OfficialCloudRetryPolicy.readRequest,
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
          vehicleLocationError: OfficialCloudRedactor.errorMessage(e),
        );
        _emit();
      }
      if (!silent) rethrow;
      _log.operation(
        '官方停车位置刷新失败',
        detail: OfficialCloudRedactor.errorMessage(e),
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

  Future<void> refreshFenceData({
    bool silent = false,
    bool force = false,
  }) async {
    final token = _state.token;
    final vehicle = _state.selectedVehicle;
    if (token.isEmpty || vehicle == null || vehicle.carId.isEmpty) {
      return;
    }
    final refreshKey = 'fence:${vehicle.key}';
    await _coalesceRefresh(
      refreshKey: refreshKey,
      silent: silent,
      force: force,
      run: () => _refreshFenceDataNow(
        silent: silent,
        refreshKey: refreshKey,
        vehicle: vehicle,
        token: token,
      ),
    );
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
        retryPolicy: OfficialCloudRetryPolicy.readRequest,
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
          fenceError: OfficialCloudRedactor.errorMessage(e),
        );
        _emit();
      }
      if (!silent) rethrow;
      _log.operation(
        '官方电子围栏刷新失败',
        detail: OfficialCloudRedactor.errorMessage(e),
        level: LogLevel.warning,
      );
    } finally {
      if (!silent && _isCurrentSession(token) && _state.fenceLoading) {
        _state = _state.copyWith(fenceLoading: false);
        _emit();
      }
    }
  }

  Future<void> updateFenceData({
    required bool enabled,
    required int radiusValue,
    required String timeFrom,
    required String timeTo,
  }) async {
    final token = _state.token;
    final vehicle = _state.selectedVehicle;
    if (token.isEmpty || vehicle == null) return;
    _state = _state.copyWith(fenceLoading: true, fenceError: null);
    _emit();
    try {
      final response = await _apiClient.request(
        'app/device/updFenceData',
        method: 'POST',
        token: token,
        body: {
          'carId': vehicle.carId,
          'fenceSwitch': enabled ? '1' : '0',
          'fenceRadius': '$radiusValue',
          'fenceTimeFr': timeFrom,
          'fenceTimeTo': timeTo,
        },
        retryPolicy: OfficialCloudRetryPolicy.transportOnly,
      );
      _ensureSuccess(response.body, fallback: '围栏设置保存失败');
      if (!_isCurrentSession(token)) return;
      await refreshFenceData(silent: true, force: true);
      _log.operation('官方电子围栏已更新');
    } catch (e) {
      if (!_isCurrentSession(token)) return;
      await _handleAuthFailureIfNeeded(e);
      if (_state.signedIn) {
        _state = _state.copyWith(
          fenceLoading: false,
          fenceError: OfficialCloudRedactor.errorMessage(e),
        );
        _emit();
      }
      rethrow;
    } finally {
      if (_isCurrentSession(token) && _state.fenceLoading) {
        _state = _state.copyWith(fenceLoading: false);
        _emit();
      }
    }
  }

  /// Write vehicle nickname via official `app/car/updateCarInfo`.
  ///
  /// Evidence: decompiled `TailgService.updateCarInfo` + garage rename callers
  /// (`GarageV2ViewModel` / `MyGarageRevisionViewModel`). Body is
  /// `{ carId, carNickName }`; response is no-data success.
  Future<void> updateCarNickName({
    required String carId,
    required String carNickName,
  }) async {
    final token = _state.token;
    if (token.isEmpty) {
      throw Exception(OfficialCloudMessages.signInRequired);
    }
    final normalizedCarId = carId.trim();
    final nick = carNickName.trim();
    if (normalizedCarId.isEmpty) {
      throw Exception('车辆 ID 无效');
    }
    if (nick.isEmpty) {
      throw Exception('车辆昵称不能为空');
    }

    try {
      final response = await _apiClient.request(
        'app/car/updateCarInfo',
        method: 'POST',
        token: token,
        body: {'carId': normalizedCarId, 'carNickName': nick},
        retryPolicy: OfficialCloudRetryPolicy.transportOnly,
      );
      _ensureSuccess(response.body, fallback: '车辆昵称保存失败');
      if (!_isCurrentSession(token)) return;

      final vehicles = [
        for (final vehicle in _state.vehicles)
          if (vehicle.carId == normalizedCarId)
            OfficialVehicle.fromJson({...vehicle.toJson(), 'carNickName': nick})
          else
            vehicle,
      ];
      final selected = _vehicleByKey(vehicles, _state.selectedVehicleKey);
      await _storage.saveCarControlInfo(selected);
      _state = _state.copyWith(vehicles: vehicles, error: null);
      _emit();
      await _applySelectedVehicleToLocalProfile();
      _log.operation('官方车辆昵称已更新', detail: normalizedCarId);

      try {
        await refreshVehicles(silent: true, force: true);
      } catch (e) {
        // Keep optimistic local nick if status refresh fails.
        _log.operation(
          '官方车辆列表刷新失败（昵称已写回）',
          detail: OfficialCloudRedactor.errorMessage(e),
          level: LogLevel.warning,
        );
      }
    } catch (e) {
      if (!_isCurrentSession(token)) return;
      await _handleAuthFailureIfNeeded(e);
      rethrow;
    }
  }

  Future<Map<String, bool>> getMessageControl() async {
    final token = _state.token;
    if (token.isEmpty) return {};
    try {
      final override = getMessageControlOverride;
      if (override != null) return override();
      final response = await _apiClient.request(
        'app/msg/getMessageControl',
        method: 'POST',
        token: token,
        retryPolicy: OfficialCloudRetryPolicy.readRequest,
      );
      _ensureSuccess(response.body, fallback: '获取消息偏好失败');
      final data = response.body['data'];
      if (data is! Map) return {};
      return data.map(
        (k, v) => MapEntry(k.toString(), v == true || v == '1' || v == 1),
      );
    } catch (e) {
      await _handleAuthFailureIfNeeded(e);
      rethrow;
    }
  }

  Future<void> setMessagePushConfig(Map<String, bool> config) async {
    final token = _state.token;
    if (token.isEmpty) return;
    try {
      final override = setMessagePushConfigOverride;
      if (override != null) {
        await override(Map.unmodifiable(config));
      } else {
        final body = config.map((k, v) => MapEntry(k, v ? '1' : '0'));
        final response = await _apiClient.request(
          'app/msg/setMessagePushConfig',
          method: 'POST',
          token: token,
          body: body,
          retryPolicy: OfficialCloudRetryPolicy.transportOnly,
        );
        _ensureSuccess(response.body, fallback: '消息偏好保存失败');
      }
      _log.operation('消息推送偏好已更新');
    } catch (e) {
      await _handleAuthFailureIfNeeded(e);
      rethrow;
    }
  }

  Future<void> deleteMessages() async {
    final token = _state.token;
    if (token.isEmpty) return;
    try {
      final override = deleteMessagesOverride;
      if (override != null) {
        await override();
      } else {
        final response = await _apiClient.request(
          'app/msg/delMsg',
          method: 'POST',
          token: token,
          retryPolicy: OfficialCloudRetryPolicy.transportOnly,
        );
        _ensureSuccess(response.body, fallback: '清空消息失败');
      }
      if (!_isCurrentSession(token)) return;
      _state = _state.copyWith(
        vehicleMessages: const [],
        systemMessages: const [],
        messagesError: null,
      );
      _emit();
      _log.operation('官方消息已清空');
    } catch (e) {
      await _handleAuthFailureIfNeeded(e);
      rethrow;
    }
  }

  /// Official control-home "今日骑行" (`POST app/carTravel/records`).
  ///
  /// Decompiled [HomeViewModel.deviceTravel] actually calls carTravelRecords
  /// with `{frame, uid}` and stores the returned mileage string.
  Future<void> refreshTodayRideMileage({
    bool silent = false,
    bool force = false,
  }) async {
    final token = _state.token;
    final vehicle = _state.selectedVehicle;
    final userId = _state.userId.trim();
    final frame = vehicle?.frame.trim() ?? '';
    if (token.isEmpty || vehicle == null || frame.isEmpty || userId.isEmpty) {
      if (_state.todayRideMileage.isNotEmpty) {
        _state = _state.copyWith(todayRideMileage: '');
        _emit();
      }
      return;
    }
    final refreshKey = 'todayRide:${vehicle.key}';
    await _coalesceRefresh(
      refreshKey: refreshKey,
      silent: silent,
      force: force,
      run: () => _refreshTodayRideMileageNow(
        refreshKey: refreshKey,
        vehicle: vehicle,
        userId: userId,
        token: token,
      ),
    );
  }

  Future<void> _refreshTodayRideMileageNow({
    required String refreshKey,
    required OfficialVehicle vehicle,
    required String userId,
    required String token,
  }) async {
    try {
      final response = await _apiClient.request(
        'app/carTravel/records',
        method: 'POST',
        token: token,
        body: {'frame': vehicle.frame.trim(), 'uid': userId},
        retryPolicy: OfficialCloudRetryPolicy.readRequest,
      );
      _ensureSuccess(response.body, fallback: '获取今日骑行失败');
      if (!_isCurrentSession(token)) return;
      final data = response.body['data'];
      final raw = data == null ? '' : data.toString().trim();
      _state = _state.copyWith(todayRideMileage: raw);
      _emit();
      _log.operation('官方今日骑行已刷新', detail: raw.isEmpty ? 'empty' : 'value=$raw');
      _markRefreshSuccess(refreshKey);
    } catch (e) {
      if (!_isCurrentSession(token)) return;
      await _handleAuthFailureIfNeeded(e);
      _log.operation(
        '官方今日骑行刷新失败',
        detail: OfficialCloudRedactor.errorMessage(e),
        level: LogLevel.warning,
      );
    }
  }

  Future<void> refreshTravelHistory({
    String? month,
    bool silent = false,
    bool force = false,
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
    final queryMonth =
        month ??
        (_state.travelMonth.isEmpty ? _currentMonth() : _state.travelMonth);
    final override = refreshTravelHistoryOverride;
    if (override != null) {
      await override(queryMonth);
      return;
    }
    final refreshKey = 'travel:${vehicle.key}:$queryMonth';
    if (!force &&
        silent &&
        _state.travelMonth == queryMonth &&
        _shouldUseRecentRefresh(refreshKey)) {
      return;
    }
    await _coalesceRefresh(
      refreshKey: refreshKey,
      silent: silent,
      force: force,
      run: () => _refreshTravelHistoryNow(
        silent: silent,
        refreshKey: refreshKey,
        vehicle: vehicle,
        queryMonth: queryMonth,
        userId: userId,
        token: token,
      ),
    );
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
        retryPolicy: OfficialCloudRetryPolicy.readRequest,
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
          travelError: OfficialCloudRedactor.errorMessage(e),
        );
        _emit();
      }
      if (!silent) rethrow;
      _log.operation(
        '官方历史轨迹刷新失败',
        detail: OfficialCloudRedactor.errorMessage(e),
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
        retryPolicy: OfficialCloudRetryPolicy.readRequest,
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
          travelDetailError: OfficialCloudRedactor.errorMessage(e),
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
    if (mapEquals(links, _state.localVehicleLinks)) return;
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

    final linkedLocalVehicleId = decision.linkedLocalVehicleId;
    if (linkedLocalVehicleId != null) {
      await store.setDefault(linkedLocalVehicleId);
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
    final token = _state.token;
    final vehicle = _state.selectedVehicle;
    if (token.isEmpty || vehicle == null) {
      throw const OfficialCloudApiException(
        OfficialCloudMessages.signInAndSelectVehicleRequired,
      );
    }
    if (vehicle.commandImei.isEmpty) {
      throw const OfficialCloudApiException('当前车辆缺少官方 IMEI，无法云端自检');
    }

    try {
      _log.operation('发送官方云端自检');
      final response = await _apiClient.request(
        'app/device/cmd/status',
        method: 'POST',
        token: token,
        body: {'imei': vehicle.commandImei},
      );
      _ensureSuccess(response.body, fallback: '云端自检失败');
      _ensureCurrentSession(token);
      final result = OfficialVehicleSelfCheck.fromResponse(response.body);
      _log.operation(
        '官方云端自检已返回',
        detail:
            'code=${result.code?.toString() ?? 'none'}, data=${result.hasData}',
      );
      return result;
    } catch (e) {
      _ensureCurrentSession(token);
      await _handleAuthFailureIfNeeded(e);
      _log.operation(
        '官方云端自检失败',
        detail: OfficialCloudRedactor.errorMessage(e),
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
    final token = _state.token;
    final vehicle = _state.selectedVehicle;
    if (token.isEmpty || vehicle == null) {
      throw const OfficialCloudApiException(
        OfficialCloudMessages.signInAndSelectVehicleRequired,
      );
    }
    if (vehicle.commandImei.isEmpty) {
      throw const OfficialCloudApiException('当前车辆缺少官方 IMEI，无法云端控车');
    }

    // Test-only override: record the command and let the stub decide the
    // outcome instead of hitting the network.
    final override = sendCommandOverride;
    if (override != null) {
      sentCommands.add(command);
      return override(command);
    }

    try {
      _log.operation('发送官方云端指令: ${command.label}');
      final response = await _apiClient.request(
        'app/device/cmd/${cloudCommand.apiName}',
        method: 'POST',
        token: token,
        body: {'imei': vehicle.commandImei},
      );
      _ensureSuccess(response.body, fallback: '${command.label}失败');
      _ensureCurrentSession(token);
      final message = response.body['msg']?.toString();
      _log.operation('官方云端指令已返回: ${command.label}');
      _refreshVehiclesAfterCommand(command);
      return message == null || message.isEmpty ? 'success' : message;
    } catch (e) {
      _ensureCurrentSession(token);
      await _handleAuthFailureIfNeeded(e);
      rethrow;
    }
  }

  /// P3-1: bind vehicle by IMEI (`POST app/car/bikeBind`, decompiled bindCar1).
  Future<void> bindVehicleByImei(String imei) async {
    final token = _state.token;
    if (token.isEmpty) {
      throw const OfficialCloudApiException(
        OfficialCloudMessages.signInRequired,
      );
    }
    final cleaned = imei.trim();
    if (cleaned.isEmpty) {
      throw const OfficialCloudApiException('设备 IMEI 不能为空');
    }
    final override = bindVehicleByImeiOverride;
    if (override != null) {
      await override(cleaned);
      return;
    }
    try {
      _log.operation('官方 IMEI 绑车', detail: cleaned);
      final response = await _apiClient.request(
        'app/car/bikeBind',
        method: 'POST',
        token: token,
        body: {'imei': cleaned},
      );
      _ensureSuccess(response.body, fallback: '绑车失败');
      _ensureCurrentSession(token);
      await refreshVehicles(force: true, refreshReplicaDetails: true);
      _log.operation('官方 IMEI 绑车成功');
    } catch (e) {
      _ensureCurrentSession(token);
      await _handleAuthFailureIfNeeded(e);
      rethrow;
    }
  }

  /// P3-2: unbind selected or specified car (`POST app/car/bikeUnbind`).
  ///
  /// [unbindType] follows official garage/settings callers (commonly 1).
  Future<void> unbindVehicle({String? carId, int unbindType = 1}) async {
    final token = _state.token;
    if (token.isEmpty) {
      throw const OfficialCloudApiException(
        OfficialCloudMessages.signInRequired,
      );
    }
    final id = (carId ?? _state.selectedVehicle?.carId ?? '').trim();
    if (id.isEmpty) {
      throw const OfficialCloudApiException('缺少车辆 carId，无法解绑');
    }
    final override = unbindVehicleOverride;
    if (override != null) {
      await override(id, unbindType);
      return;
    }
    try {
      _log.operation('官方解绑车辆', detail: 'carId=$id type=$unbindType');
      final response = await _apiClient.request(
        'app/car/bikeUnbind',
        method: 'POST',
        token: token,
        body: {'carId': id, 'unbindType': unbindType},
      );
      _ensureSuccess(response.body, fallback: '解绑失败');
      _ensureCurrentSession(token);
      await refreshVehicles(force: true, refreshReplicaDetails: true);
      _log.operation('官方解绑成功', detail: id);
    } catch (e) {
      _ensureCurrentSession(token);
      await _handleAuthFailureIfNeeded(e);
      rethrow;
    }
  }

  /// P3-5: query official firm version for OTA (`getFirmVersion`).
  Future<Map<String, dynamic>> getFirmVersion({String? imei}) async {
    final token = _state.token;
    if (token.isEmpty) {
      throw const OfficialCloudApiException(
        OfficialCloudMessages.signInRequired,
      );
    }
    final id = (imei ?? _state.selectedVehicle?.commandImei ?? '').trim();
    if (id.isEmpty) {
      throw const OfficialCloudApiException('缺少 IMEI，无法查询固件');
    }
    final override = getFirmVersionOverride;
    if (override != null) return override(id);
    final response = await _apiClient.request(
      'app/firmVersionInfo/getFirmVersion',
      method: 'POST',
      token: token,
      body: {'imei': id},
    );
    final data = response.body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return Map<String, dynamic>.from(response.body);
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
    _runSilentRefresh(
      refreshTodayRideMileage(silent: true),
      failureMessage: '官方今日骑行静默刷新失败',
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
          detail: OfficialCloudRedactor.errorMessage(e),
          level: LogLevel.warning,
        );
      }),
    );
  }

  Future<void> _handleAuthFailureIfNeeded(Object e) async {
    if (!OfficialCloudAuthParser.looksLikeAuthError(e)) return;
    await logout();
    _state = _state.copyWith(error: '官方登录已失效，请重新登录');
    _emit();
  }

  bool _isCurrentSession(String token) {
    return token.isNotEmpty && _state.token == token;
  }

  void _ensureCurrentSession(String token) {
    if (!_isCurrentSession(token)) {
      throw const OfficialCloudApiException('官方登录状态已变化，请重试');
    }
  }

  void _ensureSuccess(Map<String, dynamic> body, {required String fallback}) {
    final msg = body['msg']?.toString();
    if (!OfficialCloudResponseCode.isSuccessBody(body)) {
      throw OfficialCloudApiException(
        OfficialCloudRedactor.text(msg == null || msg.isEmpty ? fallback : msg),
      );
    }
  }

  void _setLoading(bool loading) {
    _state = _state.copyWith(loading: loading);
    _emit();
  }

  Future<void> _saveLinks(Map<String, String> links) async {
    final normalized = OfficialCloudVehicleLinks.normalize(links);
    await _storage.saveLinks(normalized);
    _state = _state.copyWith(localVehicleLinks: normalized);
    _emit();
  }

  /// Coalesce silent refreshes that share a [refreshKey]: reuse in-flight
  /// work and skip when a successful refresh is still within TTL (unless
  /// [force] is true). Non-silent callers always wait for a fresh run.
  Future<void> _coalesceRefresh({
    required String refreshKey,
    required bool silent,
    required bool force,
    required Future<void> Function() run,
  }) async {
    if (!force && silent && _shouldUseRecentRefresh(refreshKey)) return;
    final inFlight = _inFlightRefreshes[refreshKey];
    if (silent && inFlight != null) return inFlight;

    final refresh = run();
    _inFlightRefreshes[refreshKey] = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_inFlightRefreshes[refreshKey], refresh)) {
        unawaited(_inFlightRefreshes.remove(refreshKey));
      }
    }
  }

  bool _shouldUseRecentRefresh(String key) {
    final refreshedAt = _lastSuccessfulRefresh[key];
    if (refreshedAt == null) return false;
    return _clock().difference(refreshedAt) < _silentRefreshTtl;
  }

  void _markRefreshSuccess(String key) {
    _lastSuccessfulRefresh[key] = _clock();
  }

  void _clearRefreshCache() {
    _lastSuccessfulRefresh.clear();
    _inFlightRefreshes.clear();
  }

  String? _selectVehicleKey(
    List<OfficialVehicle> vehicles,
    String? preferredKey,
  ) {
    if (vehicles.isEmpty) return null;
    final key = preferredKey?.trim();
    if (key != null &&
        key.isNotEmpty &&
        vehicles.any((vehicle) => vehicle.key == key)) {
      return key;
    }
    return vehicles.first.key;
  }

  OfficialVehicle? _vehicleByKey(
    List<OfficialVehicle> vehicles,
    String? selectedKey,
  ) {
    if (vehicles.isEmpty || selectedKey == null) return null;
    for (final vehicle in vehicles) {
      if (vehicle.key == selectedKey) return vehicle;
    }
    return null;
  }

  String _currentMonth() {
    return formatMonthText(_clock());
  }

  void _emit() {
    if (_disposed) return;
    _stateController.add(_state);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _apiClient.dispose();
    unawaited(_stateController.close());
  }

  /// Resets the service state so it can be re-used after [dispose()].
  /// Used by [AppServices.reset()] to support hot restart and testing.
  void resetForTest({
    DateTime Function()? clock,
    OfficialCloudApiConfig? apiConfig,
  }) {
    _apiClient.dispose();
    _apiClient = OfficialCloudApiClient(
      config: apiConfig ?? const OfficialCloudApiConfig(),
      log: _log,
    );
    _disposed = false;
    _initialized = false;
    _initializing = null;
    _clock = clock ?? DateTime.now;
    // Create a fresh state controller if the old one was closed
    if (_stateController.isClosed) {
      _stateController = StreamController<OfficialCloudState>.broadcast();
    }
    _state = OfficialCloudState.initial();
    _clearRefreshCache();
    sentCommands.clear();
    sendCommandOverride = null;
    bindVehicleByImeiOverride = null;
    unbindVehicleOverride = null;
    getFirmVersionOverride = null;
    getMessageControlOverride = null;
    setMessagePushConfigOverride = null;
    deleteMessagesOverride = null;
    refreshTravelHistoryOverride = null;
    selectVehicleOverride = null;
    afterLogoutSideEffects.clear();
  }

  @visibleForTesting
  void setStateForTest(OfficialCloudState state) {
    _state = state;
    _initialized = state.initialized;
    _emit();
  }

  /// Invoked after credentials/selection are cleared (P1-4).
  ///
  /// Host app registers MQTT disconnect + BLE disconnect here so this service
  /// does not import MQTT/BLE layers directly.
  final List<Future<void> Function()> afterLogoutSideEffects = [];

  /// Test-only: when set, [sendCommand] records the command into
  /// [sentCommands] and returns this stub's result instead of making a
  /// network request. Lets widget tests assert that a control command was
  /// actually dispatched (e.g. the right-slide power gesture).
  @visibleForTesting
  Future<String> Function(CommandCode)? sendCommandOverride;

  @visibleForTesting
  Future<void> Function(String imei)? bindVehicleByImeiOverride;

  @visibleForTesting
  Future<void> Function(String carId, int unbindType)? unbindVehicleOverride;

  @visibleForTesting
  Future<Map<String, dynamic>> Function(String imei)? getFirmVersionOverride;

  /// Test-only override for loading official notification preferences.
  @visibleForTesting
  Future<Map<String, bool>> Function()? getMessageControlOverride;

  /// Test-only override for saving official notification preferences.
  @visibleForTesting
  Future<void> Function(Map<String, bool>)? setMessagePushConfigOverride;

  /// Test-only override for the official server-side message deletion call.
  @visibleForTesting
  Future<void> Function()? deleteMessagesOverride;

  /// Test-only override for controlling travel-history request completion.
  @visibleForTesting
  Future<void> Function(String month)? refreshTravelHistoryOverride;

  /// Test-only override for controlling official vehicle selection.
  @visibleForTesting
  Future<void> Function(OfficialVehicle vehicle)? selectVehicleOverride;

  /// Test-only: records every command handed to [sendCommand] since the last
  /// [resetForTest]. Populated only while [sendCommandOverride] is set.
  @visibleForTesting
  final List<CommandCode> sentCommands = [];
}
