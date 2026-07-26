import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart' show BikeState;
import '../ble/official_ble_connection_context.dart';
import '../config/map_tile_config.dart';
import '../models/battery_snapshot.dart';
import '../models/command_types.dart';
import '../models/control_command_activity.dart';
import '../models/official_vehicle.dart';
import '../services/control_channel_resolver.dart';
import '../services/control_channel_status.dart';
import '../services/control_command_route.dart';
import '../services/control_command_confirmation.dart';
import '../services/control_command_executor.dart';
import '../services/control_command_policy.dart';
import '../services/control_command_result.dart';
import '../services/display_number_formatter.dart';
import '../services/display_time_formatter.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../services/official_mqtt_service.dart';
import '../services/permission_service.dart';
import '../services/vehicle_location_resolver.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../widgets/animated_value_text.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/cached_tile_provider.dart';
import '../widgets/cloud_vehicle_gate.dart';
// Channel UI lives in-page; ControlAndUnlockCard parity retained via _CyberChannelStrip.
import '../widgets/lucide_icon.dart';
import '../widgets/slide_power_button.dart';
import '../widgets/vehicle_control_gate.dart';
import '../widgets/vehicle_stage.dart';
import '../widgets/vehicle_switch_sheet.dart';
import 'add_vehicle_page.dart';
import 'battery_details_page.dart';
import 'induction_settings_page.dart';
import 'location_page.dart';
import 'login_page.dart';
import 'official_cloud_page.dart';
import 'official_replica_pages.dart';
import 'ride_stats_page.dart';
import 'vehicle_message_page.dart';
import 'vehicle_settings_page.dart';

/// 控车主页 · Cyber UI 入口（能力与旧 `VehicleControlHomePage` 对齐）。
///
/// 状态与命令通道：
/// - 车辆 / 电量 / 位置：`officialCloudService.state`
/// - 控车：`ControlCommandExecutor` + `ControlCommandPolicy` + 状态确认
/// - 近场 BLE：自动 link + 右上 chip / 横幅
/// - 下拉刷新：`refreshVehicles` + 电池 / 位置
///
/// 底栏仍为 shell 的 3 Tab（服务 / 爱车 / 我的），不扩展 5 Tab。
class CyberVehicleControlPageV2 extends StatefulWidget {
  const CyberVehicleControlPageV2({super.key});

  @override
  State<CyberVehicleControlPageV2> createState() =>
      _CyberVehicleControlPageV2State();
}

// Align with official control debounce / confirm timings used by control_page.
const _controlConfirmTimeout = Duration(seconds: 8);
const _controlConfirmPollDelay = Duration(milliseconds: 800);
const _controlCommandDebounce = Duration(milliseconds: 1000);
const _controlCommandSendDelay = Duration(milliseconds: 500);

class _CyberVehicleControlPageV2State extends State<CyberVehicleControlPageV2>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _commandExecutor = ControlCommandExecutor(
    sendBleCommand: (command) => connectionManager.sendCommand(command),
    beforeBleCommand: (command) async {
      if (command != CommandCode.openSeat ||
          connectionManager.protocol != ble.ProtocolType.qgj) {
        return null;
      }
      final supported = await connectionManager.checkQgjSeatSupport();
      if (supported == true) return null;
      if (supported == false) return '当前车辆固件不支持开坐垫';
      return '无法确认座桶锁能力，请检查蓝牙后重试';
    },
    sendCloudCommand: (command) => officialMqttService.sendCommandPreferMqtt(
      command: command,
      cloud: officialCloudService,
    ),
  );
  final Stopwatch _controlDebounceWatch = Stopwatch();
  final ControlCommandActivityLog _commandLog = ControlCommandActivityLog();

  StreamSubscription<OfficialCloudState>? _cloudSub;
  StreamSubscription<ble.ConnectionState>? _bleStateSub;
  StreamSubscription<BikeState?>? _bleBikeStateSub;
  StreamSubscription<OfficialMqttLinkState>? _mqttLinkSub;
  StreamSubscription<bool>? _networkSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  bool _busy = false;
  bool _disposed = false;
  bool _nearFieldBusy = false;
  bool _disconnecting = false;
  bool _networkReady = true;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  OfficialControlChannel _controlChannel = OfficialControlChannel.automatic;
  CommandCode? _activeCommand;

  /// Cached BLE/location permission probe for near-field banner + six-key copy.
  PermissionCheckResult? _blePermission;
  BikeState? _bleBikeState;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cloudSub = officialCloudService.stateStream.listen((_) {
      if (mounted) setState(() {});
      _bindInductionVehicle();
      unawaited(_ensureNearFieldLink(auto: true));
    });
    _bleStateSub = connectionManager.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _bleBikeState = connectionManager.latestBikeState;
    _bleBikeStateSub = connectionManager.bikeStateStream.listen((state) {
      _bleBikeState = state;
      if (mounted) setState(() {});
    });
    _mqttLinkSub = officialMqttService.linkStateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _networkSub = networkAvailabilityService.changes.listen((available) {
      if (_networkReady == available) return;
      _networkReady = available;
      if (mounted) setState(() {});
    });
    // Desktop/widget tests have no BLE platform channel; keep unknown there.
    // Accessing FlutterBluePlus.adapterState on Windows throws
    // "unsupported on this platform" (sync or via stream errors).
    final isMobileBleHost =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (isMobileBleHost) {
      try {
        _adapterSub = FlutterBluePlus.adapterState.listen(
          (state) {
            _adapterState = state;
            if (mounted) setState(() {});
          },
          onError: (_) {
            _adapterState = BluetoothAdapterState.unknown;
            if (mounted) setState(() {});
          },
        );
      } on Object {
        _adapterState = BluetoothAdapterState.unknown;
        _adapterSub = null;
      }
    }
    // Keep induction service bound for settings page / auto-connect side effects.
    unawaited(manualModeService.init());
    _bindInductionVehicle();
    unawaited(_refreshBlePermission(request: false));
    unawaited(_refreshNetworkAvailability());
    unawaited(_silentRefresh());
    unawaited(officialMqttService.preconnectForCloud(officialCloudService));
    unawaited(_ensureNearFieldLink(auto: true));
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    final cloudSub = _cloudSub;
    if (cloudSub != null) unawaited(cloudSub.cancel());
    final bleSub = _bleStateSub;
    if (bleSub != null) unawaited(bleSub.cancel());
    final bleBikeStateSub = _bleBikeStateSub;
    if (bleBikeStateSub != null) unawaited(bleBikeStateSub.cancel());
    final mqttSub = _mqttLinkSub;
    if (mqttSub != null) unawaited(mqttSub.cancel());
    final networkSub = _networkSub;
    if (networkSub != null) unawaited(networkSub.cancel());
    final adapterSub = _adapterSub;
    if (adapterSub != null) unawaited(adapterSub.cancel());
    super.dispose();
  }

  void _bindInductionVehicle() {
    final vehicle = officialCloudService.state.selectedVehicle;
    inductionModeService.bindVehicle(
      modelType: vehicle?.modelType,
      carId: vehicle?.carId,
      vehicleRaw: vehicle?.raw,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // RSSI polling is paused/resumed inside InductionModeService observer;
    // home page still refreshes cloud status when returning to foreground.
    if (state == AppLifecycleState.resumed) {
      unawaited(_onForegroundResume());
    }
  }

  Future<void> _onForegroundResume() async {
    if (_disposed) return;
    await _refreshNetworkAvailability();
    unawaited(_refreshBlePermission(request: false));
    unawaited(_ensureNearFieldLink(auto: true));
    if (!officialCloudService.state.signedIn) return;
    try {
      await officialCloudService.refreshVehicles(
        silent: true,
        refreshReplicaDetails: true,
      );
    } catch (e) {
      logService.operation(
        '回前台刷新车辆状态失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
    }
    final mqtt = officialMqttService;
    if (mqtt.lastPreconnectError != null || !mqtt.isConnected) {
      unawaited(mqtt.retryPreconnect(officialCloudService));
    } else {
      unawaited(mqtt.preconnectForCloud(officialCloudService));
    }
  }

  Future<void> _refreshBlePermission({required bool request}) async {
    final result = await permissionService.requestBleScanPermissions(
      request: request,
    );
    if (_disposed || !mounted) return;
    setState(() => _blePermission = result);
  }

  Future<void> _refreshNetworkAvailability() async {
    final available = await networkAvailabilityService.checkNow(
      fallback: _networkReady,
    );
    if (_disposed || !mounted || available == _networkReady) return;
    setState(() => _networkReady = available);
  }

  /// Official-like near-field path: open control home → auto link BLE by
  /// selected vehicle MAC when possible.
  ///
  /// **P0-A4:** if BLE is active on another vehicle, retarget via
  /// [AutoConnectService.linkOfficialTarget] (disconnect + clear pending).
  ///
  /// [forceUserAction] is true for the right-top chip / banner tap so we still
  /// connect even when 手动模式 is enabled (official chip is always explicit).
  Future<void> _ensureNearFieldLink({
    required bool auto,
    bool forceUserAction = false,
  }) async {
    if (_disposed || _nearFieldBusy || _disconnecting) return;
    if (!officialCloudService.state.signedIn) return;
    final vehicle = officialCloudService.state.selectedVehicle;
    if (vehicle == null) return;
    final bleContext = OfficialBleConnectionContext.fromVehicle(
      vehicle,
      userId: officialCloudService.state.userId,
    );
    if (bleContext.stack == OfficialBleStack.unsupported) {
      logService.operation(
        '爱车近场跳过: 不支持的 BLE 机型',
        detail: 'modelType=${vehicle.modelType}',
        level: LogLevel.warning,
      );
      return;
    }
    final targetId = bleContext.targetMacCompact;
    if (targetId.isEmpty) {
      logService.operation(
        '爱车近场跳过: 车辆无 MAC',
        detail: 'btmac=${vehicle.btmac} mac=${vehicle.raw['mac']}',
        level: LogLevel.warning,
      );
      if (!auto && mounted) {
        AppSnack.error(context, '车辆未返回蓝牙地址，无法近场连接');
      }
      return;
    }
    if ((bleContext.stack == OfficialBleStack.tlink &&
            !bleContext.hasTLinkCredentials) ||
        (bleContext.stack == OfficialBleStack.qgj &&
            !bleContext.hasQgjCredentials)) {
      logService.operation(
        '爱车近场: 登录凭据可能不完整',
        detail:
            'stack=${bleContext.stack.name} uidEmpty=${bleContext.userId.isEmpty} '
            'passwordMissing=${bleContext.selectedPassword == null}',
        level: LogLevel.warning,
      );
    }

    // Already linked to this car — do not restart connection.
    if (autoConnectService.isLinkedTo(targetId) &&
        connectionManager.isProtocolLoggedIn) {
      return;
    }

    // Auto path: check first so we don't spam the system dialog on every
    // resume; if denied, leave the near-field banner for an explicit request.
    // Manual path still goes through _manualNearFieldConnect which requests.
    if (auto && !forceUserAction) {
      final permission = await permissionService.requestBleScanPermissions(
        request: false,
      );
      if (!mounted || _disposed) return;
      setState(() => _blePermission = permission);
      if (!permission.granted) {
        logService.operation(
          '爱车自动近场跳过: 无蓝牙/定位权限',
          detail: permission.message ?? 'denied',
          level: LogLevel.info,
        );
        return;
      }
    }

    _nearFieldBusy = true;
    if (mounted) setState(() {});
    try {
      await autoConnectService.linkOfficialTarget(
        deviceId: targetId,
        displayName: vehicle.displayName,
        context: bleContext,
        enable: true,
        connectNow: true,
        ignoreManualMode: forceUserAction || !auto,
      );
    } catch (e) {
      logService.operation(
        '爱车近场连接失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (!auto && mounted) {
        AppSnack.error(context, '蓝牙连接失败，请确认车辆在附近并已开机');
      }
    } finally {
      _nearFieldBusy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _manualNearFieldConnect() async {
    final permission = await permissionService.requestBleScanPermissions();
    if (!mounted || _disposed) return;
    setState(() => _blePermission = permission);
    if (!permission.granted) {
      if (permission.openSettingsRecommended) {
        AppSnack.error(
          context,
          permission.message ?? '请到系统设置开启蓝牙和定位权限',
          actionLabel: '去设置',
          onAction: () {
            unawaited(permissionService.openSystemSettings());
          },
        );
      } else {
        AppSnack.error(context, permission.message ?? '请授予蓝牙和定位权限');
      }
      return;
    }
    if (_adapterState == BluetoothAdapterState.off ||
        _adapterState == BluetoothAdapterState.turningOff) {
      AppSnack.error(context, '请先打开手机蓝牙');
      return;
    }
    AppSnack.info(context, '正在连接车辆蓝牙…');
    await _ensureNearFieldLink(auto: false, forceUserAction: true);
    if (!mounted) return;
    if (connectionManager.isProtocolLoggedIn) {
      AppSnack.success(context, '蓝牙已连接');
    } else if (connectionManager.state == ble.ConnectionState.connecting ||
        connectionManager.state == ble.ConnectionState.connected ||
        connectionManager.state == ble.ConnectionState.reconnecting) {
      AppSnack.info(context, '蓝牙连接中…');
    } else {
      AppSnack.error(context, '未找到车辆，请靠近车辆后重试');
    }
  }

  /// Official ControlFragment right-top BLE chip: connect / disconnect toggle.
  Future<void> _onOfficialBleChipTap() async {
    if (_nearFieldBusy || _disconnecting) return;
    final vehicle = officialCloudService.state.selectedVehicle;
    if (vehicle == null) {
      AppSnack.info(context, '请先选择车辆');
      return;
    }

    final chip = _officialBleChipState(vehicle);
    // Connecting again: ignore (official keeps showing 连接中).
    if (chip == _OfficialBleChipState.connecting ||
        chip == _OfficialBleChipState.disconnecting) {
      return;
    }

    // Only LOGIN shows 已连接 and offers disconnect confirmation.
    if (chip == _OfficialBleChipState.connected) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: CyberHomeColors.card,
          surfaceTintColor: CyberHomeColors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.tile),
          ),
          title: const Text(
            '提示',
            style: TextStyle(
              color: CyberHomeColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            '确定断开车辆蓝牙连接？',
            style: TextStyle(color: CyberHomeColors.inkMuted),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: CyberHomeColors.inkMuted,
              ),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: CyberHomeColors.primary,
                foregroundColor: CyberHomeColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('断开'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || _disposed) return;
      _disconnecting = true;
      if (mounted) setState(() {});
      try {
        await connectionManager.disconnect();
        if (mounted) AppSnack.info(context, '蓝牙已断开');
      } catch (e) {
        logService.operation(
          '爱车断开蓝牙失败',
          detail: e.toString(),
          level: LogLevel.warning,
        );
        if (mounted) AppSnack.error(context, '断开蓝牙失败，请重试');
      } finally {
        _disconnecting = false;
        if (mounted) setState(() {});
      }
      return;
    }

    if (chip == _OfficialBleChipState.noBle) {
      if (_adapterState == BluetoothAdapterState.off ||
          _adapterState == BluetoothAdapterState.turningOff) {
        AppSnack.error(context, '请先打开手机蓝牙');
        return;
      }
      // Permission path.
      await _manualNearFieldConnect();
      return;
    }

    // No BLE identity → same hard stop as official initBleTLinkQgj.
    final bleContext = OfficialBleConnectionContext.fromVehicle(
      vehicle,
      userId: officialCloudService.state.userId,
    );
    if (bleContext.stack == OfficialBleStack.unsupported) {
      AppSnack.error(context, '当前机型不支持近场蓝牙连接');
      return;
    }
    if (bleContext.targetMacCompact.isEmpty) {
      AppSnack.error(context, '车辆未返回蓝牙地址，无法近场连接');
      return;
    }
    if ((bleContext.stack == OfficialBleStack.tlink &&
            !bleContext.hasTLinkCredentials) ||
        (bleContext.stack == OfficialBleStack.qgj &&
            !bleContext.hasQgjCredentials)) {
      AppSnack.error(context, '车辆未返回蓝牙登录密码，无法近场连接');
      return;
    }

    await _manualNearFieldConnect();
  }

  /// Official ViewAdapter.setQgjControlBleText / setBbLLControlBle states.
  _OfficialBleChipState _officialBleChipState(OfficialVehicle? vehicle) {
    if (vehicle == null) return _OfficialBleChipState.hidden;
    final bleContext = OfficialBleConnectionContext.fromVehicle(
      vehicle,
      userId: officialCloudService.state.userId,
    );
    if (bleContext.stack == OfficialBleStack.unsupported) {
      return _OfficialBleChipState.hidden;
    }

    // Official BLE_STATE_OFF → 无蓝牙 (radio off), distinct from permission deny.
    if (_adapterState == BluetoothAdapterState.off ||
        _adapterState == BluetoothAdapterState.turningOff ||
        _adapterState == BluetoothAdapterState.unavailable) {
      return _OfficialBleChipState.noBle;
    }

    if (_disconnecting) {
      return _OfficialBleChipState.disconnecting;
    }

    // Protocol LOGIN only (not mere GATT connected).
    if (connectionManager.isProtocolLoggedIn) {
      return _OfficialBleChipState.connected;
    }

    if (_nearFieldBusy ||
        connectionManager.state == ble.ConnectionState.connecting ||
        connectionManager.state == ble.ConnectionState.connected ||
        connectionManager.state == ble.ConnectionState.reconnecting) {
      return _OfficialBleChipState.connecting;
    }

    // Permission missing still shows 点击连接 so tap can request auth
    // (official only shows 无蓝牙 for radio-off). Keep 无蓝牙 only when
    // permanently denied after a probe.
    final perm = _blePermission;
    if (perm != null && !perm.granted && perm.openSettingsRecommended) {
      return _OfficialBleChipState.noBle;
    }

    return _OfficialBleChipState.clickToConnect;
  }

  Future<void> _silentRefresh() async {
    if (!officialCloudService.state.signedIn) return;
    try {
      await officialCloudService.refreshVehicles(
        silent: true,
        refreshReplicaDetails: true,
      );
      await officialCloudService.refreshMessages(silent: true);
    } catch (e) {
      logService.operation(
        'Cyber 首页静默刷新失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
    }
  }

  Future<void> _handleRefresh() async {
    if (!officialCloudService.state.signedIn) {
      AppSnack.info(context, OfficialCloudMessages.signInRequired);
      return;
    }
    try {
      await Future.wait<void>([
        officialCloudService.refreshVehicles(
          force: true,
          refreshReplicaDetails: true,
        ),
        officialCloudService.refreshBatteryInfo(force: true, silent: true),
        officialCloudService.refreshVehicleLocation(force: true, silent: true),
        officialCloudService.refreshTodayRideMileage(force: true, silent: true),
        officialCloudService.refreshMessages(force: true, silent: true),
      ]);
    } catch (e) {
      logService.operation(
        'Cyber 首页下拉刷新失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (mounted) {
        AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
      }
    }
  }

  BikeState? _activeBleState() {
    final availability = _controlAvailability(ignoreBusy: true);
    if (!availability.willUseBle || !connectionManager.isProtocolLoggedIn) {
      return null;
    }
    return _bleBikeState ?? connectionManager.latestBikeState;
  }

  bool? _currentPowerState() {
    final bleState = _activeBleState();
    if (bleState != null) return bleState.isPowerOn;
    final vehicle = officialCloudService.state.selectedVehicle;
    final acc = vehicle?.acc;
    return acc == null ? null : acc == 1;
  }

  bool? _currentLockState() {
    final bleState = _activeBleState();
    if (bleState != null) return bleState.isLocked;
    final vehicle = officialCloudService.state.selectedVehicle;
    final defence = vehicle?.defenceStatus;
    return defence == null ? null : defence == 1;
  }

  ControlChannelAvailability _controlAvailability({bool ignoreBusy = false}) {
    return ControlChannelResolver.resolve(
      cloudState: officialCloudService.state,
      // Official LoginStatus.LOGIN — not mere GATT connected / raw ready.
      bleReady: connectionManager.isProtocolLoggedIn,
      bleNotReadyReason: connectionManager.protocolLoginUnavailableReason,
      defaultVehicleId: vehicleStore.defaultVehicle?.id,
      channel: _controlChannel,
      busy: ignoreBusy ? false : _busy,
      networkReady: _networkReady,
    );
  }

  void _selectControlChannel(OfficialControlChannel channel) {
    if (_busy || _controlChannel == channel) return;
    setState(() => _controlChannel = channel);
    unawaited(HapticFeedback.selectionClick());

    if (channel == OfficialControlChannel.ble) {
      // Selecting local-only mode should start the existing silent BLE path;
      // permission prompts remain an explicit user action in the banner.
      unawaited(_ensureNearFieldLink(auto: true));
    } else if (channel == OfficialControlChannel.officialCloud &&
        officialCloudService.state.signedIn) {
      unawaited(officialMqttService.preconnectForCloud(officialCloudService));
    }
  }

  ControlChannelAvailability _commandAvailability(CommandCode command) {
    return ControlCommandRoute.resolve(
      base: _controlAvailability(),
      command: command,
      vehicle: officialCloudService.state.selectedVehicle,
    );
  }

  bool _isControlDebounced() {
    if (_controlDebounceWatch.isRunning &&
        _controlDebounceWatch.elapsed < _controlCommandDebounce) {
      return true;
    }
    _controlDebounceWatch
      ..reset()
      ..start();
    return false;
  }

  Future<void> _sendArmToggle() async {
    if (!await _ensureKnownControlState(lock: true)) return;
    final locked = _currentLockState();
    if (locked == null) return;
    final cmd = locked ? CommandCode.unlock : CommandCode.lock;
    await _sendCommand(cmd);
  }

  Future<void> _sendPowerToggle() async {
    if (!await _ensureKnownControlState(power: true)) return;
    final powered = _currentPowerState();
    if (powered == null) return;
    final cmd = powered ? CommandCode.powerOff : CommandCode.powerOn;
    await _sendCommand(cmd);
  }

  Future<bool> _ensureKnownControlState({
    bool power = false,
    bool lock = false,
  }) async {
    bool isKnown() {
      final powerKnown = !power || _currentPowerState() != null;
      final lockKnown = !lock || _currentLockState() != null;
      return powerKnown && lockKnown;
    }

    if (isKnown()) return true;
    await _refreshStateForConfirmation(
      preferBle: _controlAvailability().willUseBle,
    );
    if (isKnown()) return true;
    if (mounted) {
      AppSnack.error(context, '车辆状态未知，请刷新后重试');
    }
    return false;
  }

  Future<void> _sendCommand(CommandCode cmd) async {
    if (_busy) {
      if (mounted) AppSnack.error(context, '正在执行控车指令，请稍候');
      return;
    }
    if (_isControlDebounced()) {
      if (mounted) AppSnack.error(context, '请勿频繁操作');
      return;
    }
    await _refreshNetworkAvailability();
    if (!mounted || _disposed) return;
    if (cmd == CommandCode.find &&
        !await _ensureKnownControlState(power: true)) {
      return;
    }
    final policy = ControlCommandPolicy.evaluate(
      command: cmd,
      isPowerOn: _currentPowerState() == true,
    );
    if (!policy.allowed) {
      if (mounted) {
        AppSnack.error(context, policy.disabledReason ?? '${cmd.label}不可用');
      }
      return;
    }
    final availability = _commandAvailability(cmd);
    if (!availability.enabled) {
      // P0-A2: never silent — surface BLE off / connecting / not LOGIN / cloud.
      // Prefer permission-specific copy when BLE is the missing piece.
      if (mounted) {
        final reason = _controlDisabledMessage(availability);
        AppSnack.error(context, reason);
      }
      return;
    }

    setState(() {
      _busy = true;
      _activeCommand = cmd;
    });
    unawaited(HapticFeedback.mediumImpact());
    final vehicleKeyAtSend = officialCloudService.state.selectedVehicle?.key;
    final bleDeviceAtSend = availability.willUseBle
        ? connectionManager.device?.remoteId.toString()
        : null;
    final baseline = _vehicleStateSnapshot();
    final activityId = _startCommandActivity(
      command: cmd,
      title: '${cmd.label}中…',
      subtitle: '指令已发送，等待回执',
    );

    try {
      await Future<void>.delayed(_controlCommandSendDelay);
      if (!mounted || _disposed) return;
      if (officialCloudService.state.selectedVehicle?.key != vehicleKeyAtSend ||
          (availability.willUseBle &&
              connectionManager.device?.remoteId.toString() !=
                  bleDeviceAtSend)) {
        AppSnack.error(context, '车辆或控车渠道已变化，本次指令已取消');
        _finishCommandActivity(
          id: activityId,
          title: '${cmd.label}已取消',
          subtitle: '目标车辆或连接已变化',
          status: ControlCommandActivityStatus.cancelled,
        );
        return;
      }

      final result = await _commandExecutor.send(
        command: cmd,
        availability: availability,
      );
      if (result.success) {
        if (result.shouldRefreshBikeState) {
          await _refreshStateForConfirmation(preferBle: true);
        }
        _runBackgroundTask(
          locationService.recordDefaultVehicleLocation(),
          failureMessage: '控车后记录车辆位置失败',
        );
        // Capture pending name set by MQTT publish (if cloud path used MQTT).
        final mqtt = officialMqttService;
        final String? mqttPendingForConfirm;
        if (result.transport == ControlCommandTransport.officialCloud &&
            mqtt.lastSendPath == OfficialRemoteSendPath.mqtt) {
          mqttPendingForConfirm =
              mqtt.pendingCommandApiName ??
              OfficialCloudCommand.fromCommandCode(cmd)?.apiName;
        } else {
          mqttPendingForConfirm = null;
        }
        final confirmed = await _waitForCommandConfirmation(
          command: cmd,
          transport: result.transport,
          expectedOfficialVehicleKey: vehicleKeyAtSend,
          baseline: baseline,
          mqttPendingAtSend: mqttPendingForConfirm,
        );
        if (!mounted) return;
        if (!confirmed) {
          await _refreshStateForConfirmation();
          if (!mounted) return;
          final commandError = officialMqttService.pendingCommandError;
          AppSnack.error(context, commandError ?? _unconfirmedMessage(cmd));
          _finishCommandActivity(
            id: activityId,
            title: commandError == null ? '${cmd.label}未确认' : '${cmd.label}失败',
            subtitle: commandError ?? '请稍后重试',
            status: ControlCommandActivityStatus.failed,
          );
        } else {
          AppSnack.info(context, result.successMessage ?? '${cmd.label}成功');
          _finishCommandActivity(
            id: activityId,
            title: _successTitle(cmd),
            subtitle: _successSubtitle(cmd),
            status: ControlCommandActivityStatus.succeeded,
          );
        }
      } else {
        logService.operation(
          'Cyber 控车失败: ${cmd.label}',
          detail:
              '渠道=${result.transport.name} 原因=${result.failureMessage ?? '未知'}',
          level: LogLevel.error,
        );
        await _refreshStateForConfirmation();
        if (mounted) {
          AppSnack.error(context, _failureMessage(cmd, result.failureMessage));
          _finishCommandActivity(
            id: activityId,
            title: '${cmd.label}失败',
            subtitle: result.failureMessage?.trim().isNotEmpty == true
                ? result.failureMessage!.trim()
                : '请稍后重试',
            status: ControlCommandActivityStatus.failed,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activeCommand = null;
        });
      } else {
        _busy = false;
        _activeCommand = null;
      }
    }
  }

  void _runBackgroundTask(
    Future<Object?> future, {
    required String failureMessage,
  }) {
    unawaited(
      future.catchError((Object e) {
        logService.operation(
          failureMessage,
          detail: e.toString(),
          level: LogLevel.warning,
        );
        return null;
      }),
    );
  }

  int _startCommandActivity({
    required CommandCode command,
    required String title,
    required String subtitle,
  }) {
    late int id;
    setState(() {
      id = _commandLog.start(
        command: command,
        title: title,
        subtitle: subtitle,
      );
    });
    return id;
  }

  void _finishCommandActivity({
    required int id,
    required String title,
    required String subtitle,
    required ControlCommandActivityStatus status,
  }) {
    setState(() {
      _commandLog.finish(
        id: id,
        title: title,
        subtitle: subtitle,
        status: status,
      );
    });
  }

  String _unconfirmedMessage(CommandCode command) {
    return switch (command) {
      CommandCode.powerOn => '上电未确认，请稍后重试',
      CommandCode.powerOff => '断电未确认，请稍后重试',
      CommandCode.lock => '设防未确认，请稍后重试',
      CommandCode.unlock => '解防未确认，请稍后重试',
      _ => '${command.label}未确认，请稍后重试',
    };
  }

  String _failureMessage(CommandCode command, String? detail) {
    final text = detail?.trim() ?? '';
    if (text.isEmpty) return '${command.label}失败，请稍后重试';
    if (text.contains(command.label)) return text;
    return '${command.label}失败：$text';
  }

  String _successTitle(CommandCode command) {
    return switch (command) {
      CommandCode.powerOn => '通电成功',
      CommandCode.powerOff => '断电完成',
      CommandCode.lock => '设防完成',
      CommandCode.unlock => '解防成功',
      CommandCode.find => '寻车完成',
      CommandCode.openSeat => '开坐垫',
      _ => '${command.label}完成',
    };
  }

  String _successSubtitle(CommandCode command) {
    return switch (command) {
      CommandCode.powerOn => '控制系统已就绪',
      CommandCode.powerOff => '动力输出已切断',
      CommandCode.lock => '车锁与报警器已激活',
      CommandCode.unlock => '车锁已打开',
      CommandCode.find => '车辆已响应',
      CommandCode.openSeat => '坐垫锁已释放',
      _ => command.label,
    };
  }

  bool _needsStateConfirmation(CommandCode command) {
    return ControlCommandConfirmation.needsVehicleStateConfirmation(command);
  }

  ControlCommandVehicleStateSnapshot _vehicleStateSnapshot() {
    final vehicle = officialCloudService.state.selectedVehicle;
    return ControlCommandVehicleStateSnapshot(
      isLocked: vehicle?.isLocked,
      isPowerOn: vehicle?.isPowerOn,
    );
  }

  Future<bool> _waitForCommandConfirmation({
    required CommandCode command,
    required ControlCommandTransport transport,
    required String? expectedOfficialVehicleKey,
    required ControlCommandVehicleStateSnapshot baseline,
    required String? mqttPendingAtSend,
  }) async {
    // BLE device ACK already means executed; cloud publish does not.
    if (transport == ControlCommandTransport.ble) {
      return ControlCommandConfirmation.isConfirmed(
        command: command,
        transport: transport,
        expectedOfficialVehicleKey: expectedOfficialVehicleKey,
        currentOfficialVehicleKey:
            officialCloudService.state.selectedVehicle?.key,
        baseline: baseline,
        current: _vehicleStateSnapshot(),
        mqttAcked: false,
      );
    }

    if (!_needsStateConfirmation(command)) {
      return ControlCommandConfirmation.isConfirmed(
        command: command,
        transport: transport,
        expectedOfficialVehicleKey: expectedOfficialVehicleKey,
        currentOfficialVehicleKey:
            officialCloudService.state.selectedVehicle?.key,
        baseline: baseline,
        current: _vehicleStateSnapshot(),
        mqttAcked: false,
      );
    }

    final confirmationTimer = Stopwatch()..start();
    while (mounted && !_disposed) {
      if (officialMqttService.pendingCommandError != null) return false;
      final mqttAcked = ControlCommandConfirmation.mqttPendingAcknowledged(
        pendingAtSend: mqttPendingAtSend,
        pendingNow: officialMqttService.pendingCommandApiName,
      );
      final confirmed = ControlCommandConfirmation.isConfirmed(
        command: command,
        transport: transport,
        expectedOfficialVehicleKey: expectedOfficialVehicleKey,
        currentOfficialVehicleKey:
            officialCloudService.state.selectedVehicle?.key,
        baseline: baseline,
        current: _vehicleStateSnapshot(),
        mqttAcked: mqttAcked,
      );
      if (confirmed) return true;
      if (confirmationTimer.elapsed > _controlConfirmTimeout) return false;

      await _refreshStateForConfirmation();
      if (officialMqttService.pendingCommandError != null) return false;
      final mqttAckedAfterRefresh =
          ControlCommandConfirmation.mqttPendingAcknowledged(
            pendingAtSend: mqttPendingAtSend,
            pendingNow: officialMqttService.pendingCommandApiName,
          );
      final confirmedAfterRefresh = ControlCommandConfirmation.isConfirmed(
        command: command,
        transport: transport,
        expectedOfficialVehicleKey: expectedOfficialVehicleKey,
        currentOfficialVehicleKey:
            officialCloudService.state.selectedVehicle?.key,
        baseline: baseline,
        current: _vehicleStateSnapshot(),
        mqttAcked: mqttAckedAfterRefresh,
      );
      if (confirmedAfterRefresh) return true;
      if (confirmationTimer.elapsed > _controlConfirmTimeout) return false;

      await Future<void>.delayed(_controlConfirmPollDelay);
    }
    return false;
  }

  Future<void> _refreshStateForConfirmation({bool preferBle = false}) async {
    try {
      if (preferBle) {
        await connectionManager.refreshBikeState();
      } else {
        await officialCloudService.refreshVehicles(
          silent: true,
          refreshReplicaDetails: false,
          force: true,
        );
      }
    } catch (e) {
      logService.operation(
        'Cyber 控车后确认车辆状态失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
    }
  }

  /// P0-C3 / P0-A3: single truth for 爱车 top-bar channel四态 (+ BLE 连接中 / 待重连).
  ControlTopBarChannel _topBarChannel({
    ControlChannelAvailability? availability,
  }) {
    final mqtt = officialMqttService;
    return ControlTopBarChannel.resolve(
      availability: availability ?? _controlAvailability(),
      bleState: connectionManager.state,
      bleProtocolLoggedIn: connectionManager.isProtocolLoggedIn,
      mqttLinkState: mqtt.linkState,
      mqttPreconnectInFlight: mqtt.preconnectInFlight,
      mqttLastPreconnectError: mqtt.lastPreconnectError,
    );
  }

  /// Six-key / disabled path copy: surface permission before generic BLE text.
  String _controlDisabledMessage(ControlChannelAvailability availability) {
    final perm = _blePermission;
    if (perm != null &&
        !perm.granted &&
        !availability.canUseBle &&
        !availability.canUseCloud) {
      if (perm.openSettingsRecommended) {
        return perm.message ?? '请到系统设置开启蓝牙和定位权限';
      }
      return perm.message ?? '本地控车需授权蓝牙';
    }
    final reason = availability.disabledReason.trim();
    if (reason.isEmpty) return '当前不可控车，请检查蓝牙或网络';
    // Keep stable copy for near-field permission banner tests.
    // 本地控车需授权蓝牙
    // When BLE is the only missing piece and permission is denied, override
    // generic "蓝牙未连接" with the permission message.
    if (perm != null &&
        !perm.granted &&
        !availability.canUseBle &&
        (reason.contains('蓝牙') || reason.contains('协议登录'))) {
      return perm.message ?? reason;
    }
    return reason;
  }

  List<Widget> _buildHomeGates({
    required OfficialCloudState cloudState,
    required bool signedIn,
    required bool hasVehicle,
  }) {
    final kind = VehicleControlHomeGate.resolve(
      signedIn: signedIn,
      hasVehicle: hasVehicle,
      loading: cloudState.loading,
      error: cloudState.error,
      // BLE entry and state already live in the vehicle header. Keeping the
      // near-field hint disabled avoids a second full-width BLE surface.
      showNearFieldHint: false,
    );
    switch (kind) {
      case VehicleControlHomeGateKind.signedOut:
        return [
          VehicleControlGateBanner(
            title: '请先登录官方账号',
            actionLabel: '去登录',
            onAction: () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LoginPage()),
              ),
            ),
          ),
        ];
      case VehicleControlHomeGateKind.loading:
        return [
          VehicleControlGateBanner(
            title: '正在同步官方车辆…',
            actionLabel: '刷新中',
            busy: true,
            onAction: () {},
          ),
        ];
      case VehicleControlHomeGateKind.error:
        return [
          VehicleControlGateBanner(
            title: cloudState.error?.trim().isNotEmpty == true
                ? cloudState.error!.trim()
                : '车辆同步失败，请重试',
            actionLabel: '重试',
            onAction: () => unawaited(_handleRefresh()),
          ),
        ];
      case VehicleControlHomeGateKind.noVehicle:
        return [
          VehicleControlGateBanner(
            title: '暂无车辆，请先同步官方车辆',
            actionLabel: '添加车辆',
            onAction: () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AddVehiclePage()),
              ),
            ),
          ),
        ];
      case VehicleControlHomeGateKind.nearField:
        return const [];
      case VehicleControlHomeGateKind.none:
        return const [];
    }
  }

  String _vehicleName(OfficialVehicle? cloudVehicle) {
    return cloudVehicle?.displayName ??
        vehicleStore.defaultVehicle?.displayName ??
        '我的车辆';
  }

  BatterySnapshot _batterySnapshot(OfficialCloudState cloudState) {
    return BatterySnapshot.fromSources(
      officialVehicle: cloudState.signedIn ? cloudState.selectedVehicle : null,
      officialBatteryInfo: cloudState.batteryInfo,
    );
  }

  ResolvedVehicleLocation? _location(OfficialCloudState cloudState) {
    return resolveVehicleLocation(
      cloudState: cloudState,
      localVehicle: vehicleStore.defaultVehicle,
      allowCloudMetadataWithoutCoordinate: true,
    );
  }

  String _todayRideLabel(OfficialCloudState cloudState) {
    // Official control home uses app/carTravel/records → todayRideMileage.
    final direct = cloudState.todayRideMileage.trim();
    if (direct.isNotEmpty) {
      final cleaned = direct.replaceAll(RegExp(r'[^\d.]'), '');
      final parsed = double.tryParse(cleaned);
      if (parsed != null) return '${formatCompactDecimal(parsed)} km';
      return direct.toLowerCase().contains('km') ? direct : '$direct km';
    }
    // Fallback if monthly travel history already loaded for today.
    // deviceTravel totalMileage / record.mileage are meters.
    final todayKey = formatDateText(DateTime.now());
    for (final day in cloudState.travelDays) {
      if (normalizeOfficialDateKey(day.travelDate) != todayKey) continue;
      final total = day.totalMileage.trim();
      if (total.isNotEmpty) {
        final label = formatTravelMileageMetersText(total, alwaysKm: true);
        if (label.isEmpty) continue;
        // Keep home-card spacing style: "12.5 km".
        return label.endsWith('km')
            ? '${label.substring(0, label.length - 2)} km'
            : label;
      }
      final km = sumTravelMileageKm(day.records);
      if (km > 0) {
        return '${formatDecimalDown(km, fractionDigits: 2)} km';
      }
    }
    return '--';
  }

  String _rangeLabel(BatterySnapshot battery) {
    final remaining = battery.remainingMileage?.trim();
    if (remaining != null && remaining.isNotEmpty) {
      final cleaned = remaining.replaceAll(RegExp(r'[^\d.]'), '');
      final parsed = double.tryParse(cleaned);
      if (parsed != null) return '${formatCompactDecimal(parsed)} km';
      return remaining.contains('km') ? remaining : '$remaining km';
    }
    final estimated = battery.estimatedRangeKm;
    if (estimated != null) return '${formatCompactDecimal(estimated)} km';
    return '--';
  }

  String _locationTitle(ResolvedVehicleLocation? location) {
    final address = location?.address.trim() ?? '';
    if (address.isNotEmpty) return address;
    final coords = location?.coordinateText ?? '';
    if (coords.isNotEmpty) return coords;
    return '暂无位置';
  }

  void _openMessages() {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const VehicleMessagePage()),
      ),
    );
  }

  void _openShare() {
    if (!requireCloudVehicle(context)) return;
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ShareBikePage())),
    );
  }

  void _openNfc() {
    if (!requireCloudVehicle(context)) return;
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const NfcKeyPage())),
    );
  }

  void _openControlOptions(ControlTopBarChannel status) {
    var selected = _controlChannel;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: CyberHomeColors.pageBg,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '控车渠道',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: CyberHomeColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CyberChannelStrip(
                    selected: selected,
                    status: status,
                    busy: _busy,
                    onChanged: (value) {
                      selected = value;
                      _selectControlChannel(value);
                      setSheetState(() {});
                    },
                    onInduction: () {
                      Navigator.of(sheetContext).pop();
                      _openProximitySettings();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    if (!requireCloudVehicle(context)) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const VehicleSettingsPage()),
      ),
    );
  }

  void _openProximitySettings() {
    if (!requireCloudVehicle(context)) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const InductionSettingsPage()),
      ),
    );
  }

  void _openBattery() {
    if (!requireCloudVehicle(context)) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const BatteryDetailsPage()),
      ),
    );
  }

  void _openRideStats() {
    if (!requireCloudVehicle(context)) return;
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const RideStatsPage())),
    );
  }

  void _openLocation() {
    if (!requireCloudVehicle(context)) return;
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const LocationPage())),
    );
  }

  void _openVehicleHeader() {
    if (_busy) {
      AppSnack.error(context, '正在执行控车指令，请稍候');
      return;
    }
    final vehicles = officialCloudService.state.vehicles;
    if (vehicles.length > 1) {
      unawaited(showVehicleSwitchSheet(context));
      return;
    }
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const OfficialCloudPage()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cloudState = officialCloudService.state;
    final cloudVehicle = cloudState.selectedVehicle;
    final battery = _batterySnapshot(cloudState);
    final location = _location(cloudState);
    final isPowerOn = _currentPowerState();
    final isArmed = _currentLockState();
    final percent = battery.percent ?? 0;
    final signedIn = cloudState.signedIn;
    final hasVehicle = cloudVehicle != null;
    final controlAvailability = _controlAvailability();
    final visualControlAvailability = _controlAvailability(ignoreBusy: true);
    final controlChannelStatus = _topBarChannel(
      availability: controlAvailability,
    );
    final mediaPadding = MediaQuery.paddingOf(context);
    final bottomPad = AppNav.contentBottomPadding + mediaPadding.bottom;
    final lastRide = _lastRideVisuals(cloudState);
    final commandActivities = _commandLog.entries;

    return Scaffold(
      backgroundColor: _Cyber.pageBg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _Cyber.primary,
          backgroundColor: _Cyber.card,
          onRefresh: _handleRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: _buildHomeGates(
                    cloudState: cloudState,
                    signedIn: signedIn,
                    hasVehicle: hasVehicle,
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _CyberVehicleHeaderDelegate(
                  expandedExtent: 424,
                  vehicleName: _vehicleName(cloudVehicle),
                  rangeText: _rangeLabel(battery).replaceAll(' ', ''),
                  carPhoto: cloudVehicle?.carPhoto ?? '',
                  batteryPercent: percent,
                  batteryKnown: battery.percent != null,
                  online: cloudVehicle?.online ?? false,
                  bluetoothConnected: connectionManager.isProtocolLoggedIn,
                  isLocked: isArmed ?? true,
                  powered: isPowerOn,
                  bleChip: _officialBleChipState(cloudVehicle),
                  channelStatus: controlChannelStatus,
                  onTitleTap: _openVehicleHeader,
                  onBatteryTap: _openBattery,
                  onBleChipTap: () => unawaited(_onOfficialBleChipTap()),
                  onMessages: _openMessages,
                  onChannelTap: () => _openControlOptions(controlChannelStatus),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    _CyberControlGrid(
                      powered: isPowerOn,
                      armed: isArmed,
                      busy: _busy,
                      activeCommand: _activeCommand,
                      controlsEnabled:
                          signedIn &&
                          hasVehicle &&
                          visualControlAvailability.enabled,
                      dimmed:
                          !hasVehicle ||
                          !signedIn ||
                          !visualControlAvailability.enabled,
                      onFind: () => unawaited(_sendCommand(CommandCode.find)),
                      onPowerToggle: _sendPowerToggle,
                      onArmToggle: () => unawaited(_sendArmToggle()),
                      onSettings: _openSettings,
                      onSeat: () =>
                          unawaited(_sendCommand(CommandCode.openSeat)),
                      onShare: _openShare,
                      onNfc: _openNfc,
                    ),
                    const SizedBox(height: 32),
                    _CyberMapStatsRow(
                      location: location,
                      address: _locationTitle(location),
                      todayKm: _todayRideLabel(cloudState),
                      totalKm: _totalMileageLabel(cloudVehicle),
                      lastDistance: lastRide.$1,
                      lastDuration: lastRide.$2,
                      distanceSeries: lastRide.$3,
                      durationSeries: lastRide.$4,
                      onMapTap: _openLocation,
                      onRideStatsTap: _openRideStats,
                    ),
                    if (commandActivities.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _CyberRecentCommands(commands: commandActivities),
                    ],
                    SizedBox(height: bottomPad),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, String, List<double>, List<double>) _lastRideVisuals(
    OfficialCloudState cloudState,
  ) {
    OfficialTravelRecord? latest;
    for (final day in cloudState.travelDays) {
      for (final record in day.records) {
        if (latest == null ||
            record.startTime.compareTo(latest.startTime) > 0) {
          latest = record;
        }
      }
    }
    if (latest == null) {
      return (
        '--',
        '--',
        const [0.25, 0.45, 0.35, 0.6, 0.5, 0.75, 0.55],
        const [0.3, 0.5, 0.4, 0.55, 0.45, 0.65, 0.5],
      );
    }
    final distKm = latest.mileageKm;
    final mins = (latest.durationSeconds / 60).round();
    final seed = (distKm * 100).round().clamp(1, 9999);
    final rnd = math.Random(seed);
    final distSeries = List<double>.generate(
      8,
      (_) => 0.25 + rnd.nextDouble() * 0.7,
    );
    final durSeries = List<double>.generate(
      8,
      (_) => 0.2 + rnd.nextDouble() * 0.75,
    );
    return (
      '${formatDecimalDown(distKm, fractionDigits: 1)} km',
      mins > 0 ? '$mins min' : latest.durationLabel,
      distSeries,
      durSeries,
    );
  }

  String _totalMileageLabel(OfficialVehicle? vehicle) {
    final m = vehicle?.mileage;
    if (m != null && m > 0) return '${formatCompactDecimal(m)} km';
    return '--';
  }
}

IconData _commandActivityIcon(CommandCode command) {
  return switch (command) {
    CommandCode.powerOn || CommandCode.powerOff => Lucide.power,
    CommandCode.lock => Lucide.lock,
    CommandCode.unlock => Lucide.unlock,
    CommandCode.find => Lucide.find,
    CommandCode.openSeat => Lucide.seat,
    _ => Lucide.find,
  };
}

abstract final class _Cyber {
  static const pageBg = CyberHomeColors.pageBg;
  static const card = CyberHomeColors.card;
  static const primary = CyberHomeColors.primary;
  static const ink = CyberHomeColors.ink;
  static const ink2 = CyberHomeColors.inkSecondary;
  static const muted = CyberHomeColors.inkMuted;
  static const faint = CyberHomeColors.inkFaint;
  static const line = CyberHomeColors.line;
  static const soft = CyberHomeColors.control;
  static const online = CyberHomeColors.success;
  static const pink = CyberHomeColors.rideAccent;
  static const screenX = 20.0;
  static const cardMargin = EdgeInsets.symmetric(horizontal: screenX);
  static const tabular = <FontFeature>[FontFeature.tabularFigures()];
  static const cardShadow = AppShadows.cyberCardShadow;
}

enum _OfficialBleChipState {
  hidden,
  noBle,
  clickToConnect,
  connecting,
  disconnecting,
  connected,
}

class _CyberVehicleHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _CyberVehicleHeaderDelegate({
    required this.expandedExtent,
    required this.vehicleName,
    required this.rangeText,
    required this.carPhoto,
    required this.batteryPercent,
    required this.batteryKnown,
    required this.online,
    required this.bluetoothConnected,
    required this.isLocked,
    required this.powered,
    required this.bleChip,
    required this.channelStatus,
    required this.onTitleTap,
    required this.onBatteryTap,
    required this.onBleChipTap,
    required this.onMessages,
    required this.onChannelTap,
  });

  final double expandedExtent;
  final String vehicleName;
  final String rangeText;
  final String carPhoto;
  final int batteryPercent;
  final bool batteryKnown;
  final bool online;
  final bool bluetoothConnected;
  final bool isLocked;
  final bool? powered;
  final _OfficialBleChipState bleChip;
  final ControlTopBarChannel channelStatus;
  final VoidCallback onTitleTap;
  final VoidCallback onBatteryTap;
  final VoidCallback onBleChipTap;
  final VoidCallback onMessages;
  final VoidCallback onChannelTap;

  @override
  double get minExtent => 142;

  @override
  double get maxExtent => expandedExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final expandedOpacity = (1 - progress * 1.8).clamp(0.0, 1.0);
    final compactOpacity = ((progress - 0.42) / 0.58).clamp(0.0, 1.0);
    return DecoratedBox(
      key: const ValueKey('cyber-collapsing-header'),
      decoration: BoxDecoration(
        color: CyberHomeColors.pageBg,
        boxShadow: overlapsContent || progress > 0.95
            ? const [
                BoxShadow(
                  color: CyberHomeColors.actionShadow,
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ]
            : const [],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: expandedOpacity < 0.5,
            child: Opacity(
              key: const ValueKey('cyber-expanded-header-opacity'),
              opacity: expandedOpacity,
              child: _CyberHeroHeader(
                vehicleName: vehicleName,
                rangeText: rangeText,
                carPhoto: carPhoto,
                batteryPercent: batteryPercent,
                batteryKnown: batteryKnown,
                online: online,
                bluetoothConnected: bluetoothConnected,
                isLocked: isLocked,
                powered: powered,
                channelStatus: channelStatus,
                onTitleTap: onTitleTap,
                onBatteryTap: onBatteryTap,
                onBleChipTap: onBleChipTap,
                onMessages: onMessages,
                onChannelTap: onChannelTap,
              ),
            ),
          ),
          IgnorePointer(
            ignoring: compactOpacity < 0.5,
            child: Opacity(
              key: const ValueKey('cyber-compact-header-opacity'),
              opacity: compactOpacity,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _CyberTopBar(
                  vehicleName: vehicleName,
                  rangeText: rangeText,
                  carPhoto: carPhoto,
                  batteryPercent: batteryPercent,
                  online: online,
                  bluetoothConnected: bluetoothConnected,
                  isLocked: isLocked,
                  powered: powered,
                  bleChip: bleChip,
                  channelStatus: channelStatus,
                  onTitleTap: onTitleTap,
                  onBatteryTap: onBatteryTap,
                  onBleChipTap: onBleChipTap,
                  onMessages: onMessages,
                  onChannelTap: onChannelTap,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CyberVehicleHeaderDelegate oldDelegate) {
    return expandedExtent != oldDelegate.expandedExtent ||
        vehicleName != oldDelegate.vehicleName ||
        rangeText != oldDelegate.rangeText ||
        carPhoto != oldDelegate.carPhoto ||
        batteryPercent != oldDelegate.batteryPercent ||
        batteryKnown != oldDelegate.batteryKnown ||
        online != oldDelegate.online ||
        bluetoothConnected != oldDelegate.bluetoothConnected ||
        isLocked != oldDelegate.isLocked ||
        powered != oldDelegate.powered ||
        bleChip != oldDelegate.bleChip ||
        channelStatus != oldDelegate.channelStatus;
  }
}

class _CyberHeroHeader extends StatelessWidget {
  const _CyberHeroHeader({
    required this.vehicleName,
    required this.rangeText,
    required this.carPhoto,
    required this.batteryPercent,
    required this.batteryKnown,
    required this.online,
    required this.bluetoothConnected,
    required this.isLocked,
    required this.powered,
    required this.channelStatus,
    required this.onTitleTap,
    required this.onBatteryTap,
    required this.onBleChipTap,
    required this.onMessages,
    required this.onChannelTap,
  });

  final String vehicleName;
  final String rangeText;
  final String carPhoto;
  final int batteryPercent;
  final bool batteryKnown;
  final bool online;
  final bool bluetoothConnected;
  final bool isLocked;
  final bool? powered;
  final ControlTopBarChannel channelStatus;
  final VoidCallback onTitleTap;
  final VoidCallback onBatteryTap;
  final VoidCallback onBleChipTap;
  final VoidCallback onMessages;
  final VoidCallback onChannelTap;

  @override
  Widget build(BuildContext context) {
    final level = (batteryPercent / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 94,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  right: 116,
                  child: AppPressable(
                    onTap: onTitleTap,
                    semanticsLabel: '切换车辆 $vehicleName',
                    semanticsButton: true,
                    child: Text(
                      vehicleName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        color: _Cyber.ink,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: AppPressable(
                    key: const ValueKey('cyber-hero-battery-entry'),
                    onTap: onBatteryTap,
                    semanticsLabel:
                        '查看电池信息，续航 $rangeText，电量 ${batteryKnown ? '$batteryPercent%' : '未知'}',
                    semanticsButton: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AnimatedValueText(
                          rangeText.replaceAll('km', '').trim(),
                          style: const TextStyle(
                            fontSize: 48,
                            height: 0.94,
                            fontWeight: FontWeight.w700,
                            color: _Cyber.ink,
                            fontFeatures: _Cyber.tabular,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 3),
                          child: Text(
                            'km',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _Cyber.ink,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 10, bottom: 3),
                          child: AnimatedValueText(
                            batteryKnown ? '$batteryPercent%' : '--%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: _Cyber.muted,
                              fontFeatures: _Cyber.tabular,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Row(
                    children: [
                      _HeroAction(
                        key: const ValueKey('cyber-hero-bluetooth'),
                        icon: bluetoothConnected
                            ? Lucide.bluetooth
                            : Lucide.bluetoothSearching,
                        label: bluetoothConnected ? '蓝牙已连接' : '连接车辆蓝牙',
                        primary: true,
                        onTap: onBleChipTap,
                      ),
                      const SizedBox(width: 10),
                      _HeroAction(
                        key: const ValueKey('cyber-hero-messages'),
                        icon: Lucide.message,
                        label: '车辆消息',
                        onTap: onMessages,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 116,
            height: 4,
            decoration: BoxDecoration(
              color: _Cyber.ink,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          const SizedBox(height: 10),
          _CyberStatusLine(
            key: const ValueKey('cyber-hero-status'),
            online: online,
            bluetoothConnected: bluetoothConnected,
            isLocked: isLocked,
            powered: powered,
            channelStatus: channelStatus,
            onTap: onChannelTap,
          ),
          Expanded(
            child: Center(
              child: VehicleStage(
                key: const ValueKey('cyber-hero-vehicle'),
                batteryLevel: level,
                height: 200,
                imageUrl: carPhoto.trim().isEmpty ? null : carPhoto.trim(),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticsLabel: label,
      semanticsButton: true,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: primary ? _Cyber.primary : _Cyber.card,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: AppShadows.cyberActionShadow,
        ),
        alignment: Alignment.center,
        child: LucideIcon(
          icon,
          size: 25,
          color: primary ? CyberHomeColors.white : _Cyber.ink,
          strokeWidth: 1.8,
        ),
      ),
    );
  }
}

class _CyberTopBar extends StatelessWidget {
  const _CyberTopBar({
    required this.vehicleName,
    required this.rangeText,
    required this.carPhoto,
    required this.batteryPercent,
    required this.online,
    required this.bluetoothConnected,
    required this.isLocked,
    required this.powered,
    required this.bleChip,
    required this.channelStatus,
    required this.onTitleTap,
    required this.onBatteryTap,
    required this.onBleChipTap,
    required this.onMessages,
    required this.onChannelTap,
  });

  final String vehicleName;
  final String rangeText;
  final String carPhoto;
  final int batteryPercent;
  final bool online;
  final bool bluetoothConnected;
  final bool isLocked;
  final bool? powered;
  final _OfficialBleChipState bleChip;
  final ControlTopBarChannel channelStatus;
  final VoidCallback onTitleTap;
  final VoidCallback onBatteryTap;
  final VoidCallback onBleChipTap;
  final VoidCallback onMessages;
  final VoidCallback onChannelTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_Cyber.screenX, 8, _Cyber.screenX, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppPressable(
                  onTap: onTitleTap,
                  semanticsLabel: '切换车辆 $vehicleName',
                  semanticsButton: true,
                  child: Text(
                    vehicleName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: _Cyber.ink,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                AppPressable(
                  key: const ValueKey('cyber-compact-battery-entry'),
                  onTap: onBatteryTap,
                  semanticsLabel: '查看电池信息，续航 $rangeText，电量 $batteryPercent%',
                  semanticsButton: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppTouchTargets.min,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedValueText(
                        rangeText,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: _Cyber.ink2,
                          fontFeatures: _Cyber.tabular,
                        ),
                      ),
                    ),
                  ),
                ),
                _CyberStatusLine(
                  key: const ValueKey('cyber-compact-status'),
                  online: online,
                  bluetoothConnected: bluetoothConnected,
                  isLocked: isLocked,
                  powered: powered,
                  channelStatus: channelStatus,
                  onTap: onChannelTap,
                  compact: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              _VehicleThumb(
                carPhoto: carPhoto,
                percent: batteryPercent,
                width: 112,
                height: 70,
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (bleChip != _OfficialBleChipState.hidden)
                    _CyberBleChip(state: bleChip, onTap: onBleChipTap),
                  const SizedBox(width: 5),
                  _RoundIconBtn(
                    icon: Lucide.message,
                    label: '车辆消息',
                    onTap: onMessages,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CyberStatusLine extends StatelessWidget {
  const _CyberStatusLine({
    super.key,
    required this.online,
    required this.bluetoothConnected,
    required this.isLocked,
    required this.powered,
    required this.channelStatus,
    required this.onTap,
    this.compact = false,
  });

  final bool online;
  final bool bluetoothConnected;
  final bool isLocked;
  final bool? powered;
  final ControlTopBarChannel channelStatus;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final stateLabel = [
      online ? '车辆在线' : '车辆离线',
      bluetoothConnected ? '蓝牙已连接' : '蓝牙未连接',
      isLocked ? '已关锁' : '已开锁',
      if (powered != null) powered! ? '已通电' : '已断电',
      channelStatus.label,
    ].join('，');
    final iconSize = compact ? 15.0 : 18.0;
    final textSize = compact ? 11.0 : 13.0;
    return AppPressable(
      onTap: onTap,
      semanticsLabel: '控车状态：$stateLabel。点击选择控车渠道',
      semanticsButton: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: compact ? 5 : 7,
        runSpacing: 3,
        children: [
          _AnimatedStatusIcon(
            Lucide.circleDot,
            size: iconSize,
            color: online ? _Cyber.online : _Cyber.faint,
          ),
          _AnimatedStatusIcon(
            bluetoothConnected ? Lucide.bluetooth : Lucide.bluetoothOff,
            size: iconSize,
            color: bluetoothConnected ? _Cyber.primary : _Cyber.faint,
          ),
          _AnimatedStatusIcon(
            Lucide.radioTower,
            size: iconSize,
            color: online ? _Cyber.ink : _Cyber.faint,
          ),
          AnimatedSwitcher(
            duration: AppMotion.status,
            child: Text(
              isLocked ? '已关锁' : '已开锁',
              key: ValueKey(isLocked),
              style: TextStyle(
                fontSize: textSize,
                color: _Cyber.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AnimatedContainer(
            duration: AppMotion.status,
            curve: AppMotion.pressCurve,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: compact ? 2 : 3,
            ),
            decoration: BoxDecoration(
              color: _Cyber.soft,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.status,
              child: Text(
                channelStatus.label,
                key: ValueKey(channelStatus.label),
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  color: _Cyber.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedStatusIcon extends StatelessWidget {
  const _AnimatedStatusIcon(
    this.icon, {
    required this.size,
    required this.color,
  });

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.status,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: LucideIcon(
        icon,
        key: ValueKey((icon.codePoint, color)),
        size: size,
        color: color,
      ),
    );
  }
}

class _VehicleThumb extends StatelessWidget {
  const _VehicleThumb({
    required this.carPhoto,
    required this.percent,
    this.width = 132,
    this.height = 86,
  });
  final String carPhoto;
  final int percent;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = carPhoto.trim();
    final level = (percent / 100).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        width: width,
        height: height,
        color: CyberHomeColors.mapPlaceholder,
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => _fallback(level),
                errorWidget: (_, __, ___) => _fallback(level),
              )
            : _fallback(level),
      ),
    );
  }

  Widget _fallback(double level) {
    return Image.asset(
      VehicleStage.fallbackAsset,
      fit: BoxFit.contain,
      semanticLabel: '台铃车辆',
      errorBuilder: (_, __, ___) =>
          CustomPaint(painter: VehicleStagePainter(batteryLevel: level)),
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticsLabel: label,
      semanticsButton: true,
      child: Container(
        width: AppTouchTargets.min,
        height: AppTouchTargets.min,
        decoration: const BoxDecoration(
          color: _Cyber.soft,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: LucideIcon(icon, size: 19, color: _Cyber.muted),
      ),
    );
  }
}

class _CyberBleChip extends StatelessWidget {
  const _CyberBleChip({required this.state, required this.onTap});
  final _OfficialBleChipState state;
  final VoidCallback onTap;

  String get _label => switch (state) {
    _OfficialBleChipState.hidden => '',
    _OfficialBleChipState.noBle => '无蓝牙',
    _OfficialBleChipState.clickToConnect => '点击连接',
    _OfficialBleChipState.connecting => '连接中',
    _OfficialBleChipState.disconnecting => '断开中',
    _OfficialBleChipState.connected => '已连接',
  };

  @override
  Widget build(BuildContext context) {
    final connected = state == _OfficialBleChipState.connected;
    final connecting =
        state == _OfficialBleChipState.connecting ||
        state == _OfficialBleChipState.disconnecting;
    return AppPressable(
      onTap: onTap,
      semanticsLabel: '蓝牙 $_label',
      semanticsButton: true,
      child: AnimatedContainer(
        duration: AppMotion.status,
        curve: AppMotion.pressCurve,
        height: AppTouchTargets.min,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: connected
              ? _Cyber.primary.withValues(alpha: 0.12)
              : _Cyber.soft,
          borderRadius: BorderRadius.circular(AppRadii.sheet),
          border: Border.all(
            color: connected
                ? _Cyber.primary.withValues(alpha: 0.35)
                : _Cyber.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: AppMotion.status,
              child: connecting
                  ? const SizedBox(
                      key: ValueKey('ble-progress'),
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: _Cyber.primary,
                      ),
                    )
                  : LucideIcon(
                      connected ? Lucide.bluetooth : Lucide.bluetoothSearching,
                      key: ValueKey(state),
                      size: 14,
                      color: connected ? _Cyber.primary : _Cyber.muted,
                    ),
            ),
            const SizedBox(width: 4),
            AnimatedSwitcher(
              duration: AppMotion.status,
              child: Text(
                _label,
                key: ValueKey(_label),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: connected ? _Cyber.primary : _Cyber.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CyberControlGrid extends StatelessWidget {
  const _CyberControlGrid({
    required this.powered,
    required this.armed,
    required this.busy,
    required this.activeCommand,
    required this.controlsEnabled,
    required this.dimmed,
    required this.onFind,
    required this.onPowerToggle,
    required this.onArmToggle,
    required this.onSettings,
    required this.onSeat,
    required this.onShare,
    required this.onNfc,
  });

  final bool? powered;
  final bool? armed;
  final bool busy;
  final CommandCode? activeCommand;
  final bool controlsEnabled;
  final bool dimmed;
  final VoidCallback onFind;
  final Future<void> Function() onPowerToggle;
  final VoidCallback onArmToggle;
  final VoidCallback onSettings;
  final VoidCallback onSeat;
  final VoidCallback onShare;
  final VoidCallback onNfc;

  @override
  Widget build(BuildContext context) {
    final armLabel = armed == null ? '设防/解防' : (armed! ? '解防' : '设防');
    bool active(CommandCode command) => activeCommand == command;
    bool subdued(CommandCode command) =>
        busy && activeCommand != null && !active(command);
    final armActive = active(CommandCode.lock) || active(CommandCode.unlock);
    final armSubdued = busy && activeCommand != null && !armActive;
    return AnimatedOpacity(
      key: const ValueKey('cyber-control-grid'),
      duration: AppMotion.status,
      opacity: dimmed ? 0.55 : 1,
      child: Padding(
        padding: _Cyber.cardMargin,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleKey(
                  icon: Lucide.find,
                  label: '寻车',
                  busy: active(CommandCode.find),
                  subdued: subdued(CommandCode.find),
                  onTap: onFind,
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SlidePowerButton(
                      isPowered: powered,
                      enabled: controlsEnabled,
                      busy: busy,
                      onSlide: onPowerToggle,
                    ),
                  ),
                ),
                _CircleKey(
                  icon: armed == true ? Lucide.unlock : Lucide.lock,
                  label: armLabel,
                  busy: armActive,
                  subdued: armSubdued,
                  onTap: onArmToggle,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleKey(
                  icon: Lucide.settings,
                  label: '车辆设置',
                  onTap: onSettings,
                ),
                _CircleKey(
                  icon: Lucide.seat,
                  label: '打开坐垫',
                  busy: active(CommandCode.openSeat),
                  subdued: subdued(CommandCode.openSeat),
                  onTap: onSeat,
                ),
                _CircleKey(icon: Lucide.share, label: '车辆分享', onTap: onShare),
                _CircleKey(icon: Lucide.nfc, label: 'NFC钥匙', onTap: onNfc),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleKey extends StatelessWidget {
  const _CircleKey({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.subdued = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      // Stay tappable while dimmed so unavailable reason snacks can still fire.
      enabled: true,
      onTap: onTap,
      semanticsLabel: label,
      semanticsButton: true,
      child: AnimatedOpacity(
        duration: AppMotion.status,
        opacity: subdued ? 0.48 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: _Cyber.card,
                shape: BoxShape.circle,
                boxShadow: AppShadows.cyberActionShadow,
              ),
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: AppMotion.status,
                child: busy
                    ? const SizedBox(
                        key: ValueKey('command-progress'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _Cyber.primary,
                        ),
                      )
                    : LucideIcon(
                        icon,
                        key: ValueKey(icon),
                        size: 25,
                        color: _Cyber.ink2,
                        strokeWidth: 1.8,
                      ),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: AppMotion.status,
              child: Text(
                busy ? '$label中' : label,
                key: ValueKey((label, busy)),
                style: const TextStyle(
                  fontSize: 12,
                  color: _Cyber.muted,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CyberChannelStrip extends StatelessWidget {
  const _CyberChannelStrip({
    required this.selected,
    required this.status,
    required this.busy,
    required this.onChanged,
    required this.onInduction,
  });

  final OfficialControlChannel selected;
  final ControlTopBarChannel status;
  final bool busy;
  final ValueChanged<OfficialControlChannel> onChanged;
  final VoidCallback onInduction;

  @override
  Widget build(BuildContext context) {
    Widget chip(OfficialControlChannel ch, String label) {
      final on = selected == ch;
      return Expanded(
        child: AppPressable(
          onTap: busy ? () {} : () => onChanged(ch),
          semanticsLabel: label,
          semanticsButton: true,
          child: Container(
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? _Cyber.primary : _Cyber.soft,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: on ? CyberHomeColors.white : _Cyber.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: _Cyber.cardMargin,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _Cyber.card,
          borderRadius: BorderRadius.circular(AppRadii.sheet),
          boxShadow: _Cyber.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '控车渠道',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _Cyber.ink,
                  ),
                ),
                const Spacer(),
                Text(
                  busy ? '指令执行中' : status.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: busy ? CyberHomeColors.warning : _Cyber.muted,
                  ),
                ),
                const SizedBox(width: 8),
                AppPressable(
                  onTap: onInduction,
                  semanticsLabel: '感应设置',
                  semanticsButton: true,
                  child: const Text(
                    '感应',
                    style: TextStyle(
                      fontSize: 12,
                      color: _Cyber.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                chip(OfficialControlChannel.automatic, '智能'),
                const SizedBox(width: 8),
                chip(OfficialControlChannel.ble, '仅蓝牙'),
                const SizedBox(width: 8),
                chip(OfficialControlChannel.officialCloud, '仅云端'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CyberMapStatsRow extends StatelessWidget {
  const _CyberMapStatsRow({
    required this.location,
    required this.address,
    required this.todayKm,
    required this.totalKm,
    required this.lastDistance,
    required this.lastDuration,
    required this.distanceSeries,
    required this.durationSeries,
    required this.onMapTap,
    required this.onRideStatsTap,
  });

  final ResolvedVehicleLocation? location;
  final String address;
  final String todayKm;
  final String totalKm;
  final String lastDistance;
  final String lastDuration;
  final List<double> distanceSeries;
  final List<double> durationSeries;
  final VoidCallback onMapTap;
  final VoidCallback onRideStatsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('cyber-map-stats-row'),
      padding: _Cyber.cardMargin,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppPressable(
              onTap: onMapTap,
              borderRadius: BorderRadius.circular(AppRadii.sheet),
              semanticsLabel: '车辆位置 $address',
              semanticsButton: true,
              child: _MiniMap(location: location, address: address),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppPressable(
              key: const ValueKey('cyber-ride-stats-entry'),
              onTap: onRideStatsTap,
              borderRadius: BorderRadius.circular(AppRadii.sheet),
              semanticsLabel: '查看骑行统计',
              semanticsButton: true,
              child: _RideCard(
                todayKm: todayKm,
                totalKm: totalKm,
                lastDistance: lastDistance,
                lastDuration: lastDuration,
                distanceSeries: distanceSeries,
                durationSeries: durationSeries,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.location, required this.address});
  final ResolvedVehicleLocation? location;
  final String address;

  @override
  Widget build(BuildContext context) {
    final hasPin = location?.hasCoordinate == true;
    final lat = location?.latitude ?? 30.2741;
    final lng = location?.longitude ?? 120.1551;
    final center = LatLng(lat, lng);

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: _Cyber.card,
        borderRadius: BorderRadius.circular(AppRadii.sheet),
        boxShadow: _Cyber.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (hasPin)
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: MapTileConfig.baseUrlTemplate,
                  subdomains: MapTileConfig.subdomains,
                  userAgentPackageName: 'tailg_ble_app',
                  tileProvider: CachedTileProvider(),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 26,
                      height: 26,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _Cyber.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CyberHomeColors.white,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            const ColoredBox(
              color: CyberHomeColors.mapPlaceholder,
              child: Center(
                child: LucideIcon(Lucide.map, size: 36, color: _Cyber.faint),
              ),
            ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: CyberHomeColors.white96,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '车辆位置',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _Cyber.ink,
                    ),
                  ),
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: _Cyber.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({
    required this.todayKm,
    required this.totalKm,
    required this.lastDistance,
    required this.lastDuration,
    required this.distanceSeries,
    required this.durationSeries,
  });

  final String todayKm;
  final String totalKm;
  final String lastDistance;
  final String lastDuration;
  final List<double> distanceSeries;
  final List<double> durationSeries;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Cyber.card,
        borderRadius: BorderRadius.circular(AppRadii.sheet),
        boxShadow: _Cyber.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '骑行记录',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _Cyber.ink,
            ),
          ),
          const SizedBox(height: 12),
          _Spark(
            value: lastDistance,
            label: '最近骑行',
            color: _Cyber.pink,
            series: distanceSeries,
          ),
          const SizedBox(height: 10),
          _Spark(
            value: lastDuration,
            label: '耗时',
            color: _Cyber.primary,
            series: durationSeries,
          ),
          const Spacer(),
          Container(height: 1, color: _Cyber.line),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Metric(value: todayKm, label: '今日'),
              ),
              Container(width: 1, height: 32, color: _Cyber.line),
              Expanded(
                child: _Metric(value: totalKm, label: '总里程'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Spark extends StatelessWidget {
  const _Spark({
    required this.value,
    required this.label,
    required this.color,
    required this.series,
  });

  final String value;
  final String label;
  final Color color;
  final List<double> series;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedValueText(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _Cyber.ink,
                  fontFeatures: _Cyber.tabular,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: _Cyber.faint),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 64,
          height: 32,
          child: CustomPaint(
            painter: _SparkPainter(values: series, color: color),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedValueText(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _Cyber.ink,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: _Cyber.faint)),
      ],
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    final n = values.length;
    for (var i = 0; i < n; i++) {
      final x = n == 1 ? 0.0 : size.width * i / (n - 1);
      final y = size.height * (1 - values[i].clamp(0.05, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values || old.color != color;
}

class _CyberRecentCommands extends StatelessWidget {
  const _CyberRecentCommands({required this.commands});
  final List<ControlCommandActivity> commands;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _Cyber.cardMargin,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(
          color: _Cyber.card,
          borderRadius: BorderRadius.circular(AppRadii.sheet),
          boxShadow: _Cyber.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '最近命令',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _Cyber.ink,
                  ),
                ),
                const Spacer(),
                Text(
                  commands.isEmpty ? '暂无' : '${commands.length} 条',
                  style: const TextStyle(fontSize: 12, color: _Cyber.faint),
                ),
              ],
            ),
            if (commands.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '发送控车指令后会显示在这里',
                  style: TextStyle(fontSize: 12, color: _Cyber.faint),
                ),
              )
            else
              for (final c in commands)
                _AnimatedCmdRow(key: ValueKey(c.id), entry: c),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCmdRow extends StatefulWidget {
  const _AnimatedCmdRow({super.key, required this.entry});

  final ControlCommandActivity entry;

  @override
  State<_AnimatedCmdRow> createState() => _AnimatedCmdRowState();
}

class _AnimatedCmdRowState extends State<_AnimatedCmdRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.dataChange,
    );
    _curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.entranceCurve,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(_curved);
    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _curved,
        child: SlideTransition(
          position: _slide,
          child: _CmdRow(entry: widget.entry),
        ),
      ),
    );
  }
}

class _CmdRow extends StatelessWidget {
  const _CmdRow({required this.entry});
  final ControlCommandActivity entry;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (entry.status) {
      ControlCommandActivityStatus.succeeded => _Cyber.primary,
      ControlCommandActivityStatus.pending => CyberHomeColors.warning,
      ControlCommandActivityStatus.failed => CyberHomeColors.danger,
      ControlCommandActivityStatus.cancelled => _Cyber.faint,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: LucideIcon(
              _commandActivityIcon(entry.command),
              size: 14,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _Cyber.ink,
                  ),
                ),
                Text(
                  entry.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _Cyber.faint),
                ),
              ],
            ),
          ),
          Text('刚刚', style: const TextStyle(fontSize: 11, color: _Cyber.faint)),
        ],
      ),
    );
  }
}
