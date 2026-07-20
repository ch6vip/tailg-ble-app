import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart' show BikeState;
import '../ble/official_ble_connection_context.dart';
import '../models/battery_snapshot.dart';
import '../models/command_types.dart';
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
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/cloud_vehicle_gate.dart';
import '../widgets/vehicle_control_gate.dart';
import '../widgets/vehicle_switch_sheet.dart';
import 'add_vehicle_page.dart';
import 'battery_details_page.dart';
import 'location_page.dart';
import 'login_page.dart';
import 'official_cloud_page.dart';
import 'vehicle_settings_page.dart';

/// 控车主页 · Tailg Aurora (Open Design `vehicle-control-home`).
///
/// 布局对齐 HTML 交付；状态与命令通道复用官方云端：
/// - 车辆 / 电量 / 位置：`officialCloudService.state`
/// - 控车：`ControlCommandExecutor` + `ControlCommandPolicy` + 状态确认
/// - 下拉刷新：`refreshVehicles` + 电池 / 位置
///
/// 作为爱车 Tab 主入口使用（见 `main.dart` IndexedStack）；底栏由 shell 提供，
/// 本页不再自带 TabBar。
class VehicleControlHomePage extends StatefulWidget {
  const VehicleControlHomePage({super.key});

  @override
  State<VehicleControlHomePage> createState() => _VehicleControlHomePageState();
}

// Align with official control debounce / confirm timings used by control_page.
const _controlConfirmTimeout = Duration(seconds: 8);
const _controlConfirmPollDelay = Duration(milliseconds: 800);
const _controlCommandDebounce = Duration(milliseconds: 1000);
const _controlCommandSendDelay = Duration(milliseconds: 500);

/// 城市电摩估算均速，用于「预计续航」小时数（官方无直接字段）。
const _urbanAvgSpeedKmh = 20.0;

class _VehicleControlHomePageState extends State<VehicleControlHomePage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _commandExecutor = ControlCommandExecutor(
    sendBleCommand: (command) => connectionManager.sendCommand(command),
    sendCloudCommand: (command) => officialMqttService.sendCommandPreferMqtt(
      command: command,
      cloud: officialCloudService,
    ),
  );
  final Stopwatch _controlDebounceWatch = Stopwatch();
  final List<_CommandEntry> _commands = <_CommandEntry>[];

  StreamSubscription<OfficialCloudState>? _cloudSub;
  StreamSubscription<ble.ConnectionState>? _bleStateSub;
  StreamSubscription<BikeState?>? _bleBikeStateSub;
  StreamSubscription<OfficialMqttLinkState>? _mqttLinkSub;
  bool _busy = false;
  bool _disposed = false;
  bool _nearFieldBusy = false;
  OfficialControlChannel _controlChannel = OfficialControlChannel.automatic;

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
    unawaited(_refreshBlePermission(request: false));
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // P1-2: back to foreground → refresh carStatus + preconnect as needed.
      unawaited(_onForegroundResume());
    }
  }

  Future<void> _onForegroundResume() async {
    if (_disposed) return;
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

  /// Official-like near-field path: open control home → auto link BLE by
  /// selected vehicle MAC when possible.
  ///
  /// **P0-A4:** if BLE is active on another vehicle, retarget via
  /// [AutoConnectService.linkOfficialTarget] (disconnect + clear pending).
  Future<void> _ensureNearFieldLink({required bool auto}) async {
    if (_disposed || _nearFieldBusy) return;
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
    if (autoConnectService.isLinkedTo(targetId)) {
      return;
    }

    // Auto path: check first so we don't spam the system dialog on every
    // resume; if denied, leave the near-field banner for an explicit request.
    // Manual path still goes through _manualNearFieldConnect which requests.
    if (auto) {
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
    AppSnack.info(context, '正在连接车辆蓝牙…');
    await _ensureNearFieldLink(auto: false);
    if (!mounted) return;
    if (connectionManager.isProtocolLoggedIn) {
      AppSnack.success(context, '蓝牙已连接');
    } else if (connectionManager.state == ble.ConnectionState.connecting ||
        connectionManager.state == ble.ConnectionState.connected) {
      AppSnack.info(context, '蓝牙连接中…');
    } else {
      AppSnack.error(context, '未找到车辆，请靠近车辆后重试');
    }
  }

  Future<void> _silentRefresh() async {
    if (!officialCloudService.state.signedIn) return;
    try {
      await officialCloudService.refreshVehicles(
        silent: true,
        refreshReplicaDetails: true,
      );
    } catch (e) {
      logService.operation(
        'Aurora 首页静默刷新失败',
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
      ]);
    } catch (e) {
      logService.operation(
        'Aurora 首页下拉刷新失败',
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

  Future<void> _sendPower() async {
    if (_busy) {
      AppSnack.error(context, '正在执行控车指令，请稍候');
      return;
    }
    if (!await _ensureKnownControlState(power: true)) return;
    if (!mounted) return;
    final isPowerOn = _currentPowerState();
    if (isPowerOn == null) return;
    final cmd = isPowerOn ? CommandCode.powerOff : CommandCode.powerOn;
    await _sendCommand(cmd);
  }

  Future<void> _sendArmToggle() async {
    if (!await _ensureKnownControlState(lock: true)) return;
    final locked = _currentLockState();
    if (locked == null) return;
    final cmd = locked ? CommandCode.unlock : CommandCode.lock;
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
    if (cmd == CommandCode.find &&
        !await _ensureKnownControlState(power: true)) {
      return;
    }
    final mqttStatus = officialMqttService.latestStatusPayload;
    final policy = ControlCommandPolicy.evaluate(
      command: cmd,
      isPowerOn: _currentPowerState() == true,
      isMoving: mqttStatus?.isMoving ?? false,
      keyStarted: mqttStatus?.isKeyStarted ?? false,
      notPoweredOff: mqttStatus?.isNotPoweredOff ?? false,
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

    setState(() => _busy = true);
    unawaited(HapticFeedback.mediumImpact());
    final vehicleKeyAtSend = officialCloudService.state.selectedVehicle?.key;
    final bleDeviceAtSend = availability.willUseBle
        ? connectionManager.device?.remoteId.toString()
        : null;
    final baseline = _vehicleStateSnapshot();
    _pushCommand(
      _CommandEntry(
        kind: _kindFor(cmd),
        title: '${cmd.label}中…',
        subtitle: '指令已发送，等待回执',
        time: '刚刚',
        status: _CommandStatus.pending,
      ),
    );

    try {
      await Future<void>.delayed(_controlCommandSendDelay);
      if (!mounted || _disposed) return;
      if (officialCloudService.state.selectedVehicle?.key != vehicleKeyAtSend ||
          (availability.willUseBle &&
              connectionManager.device?.remoteId.toString() !=
                  bleDeviceAtSend)) {
        AppSnack.error(context, '车辆或控车渠道已变化，本次指令已取消');
        _pushCommand(
          _CommandEntry(
            kind: _kindFor(cmd),
            title: '${cmd.label}已取消',
            subtitle: '目标车辆或连接已变化',
            time: '刚刚',
            status: _CommandStatus.pending,
          ),
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
          _pushCommand(
            _CommandEntry(
              kind: _kindFor(cmd),
              title: commandError == null
                  ? '${cmd.label}未确认'
                  : '${cmd.label}失败',
              subtitle: commandError ?? '请稍后重试',
              time: '刚刚',
              status: _CommandStatus.pending,
            ),
          );
        } else {
          AppSnack.info(context, result.successMessage ?? '${cmd.label}成功');
          _pushCommand(
            _CommandEntry(
              kind: _kindFor(cmd),
              title: _successTitle(cmd),
              subtitle: _successSubtitle(cmd),
              time: '刚刚',
              status: _CommandStatus.ok,
            ),
          );
        }
      } else {
        logService.operation(
          'Aurora 控车失败: ${cmd.label}',
          detail:
              '渠道=${result.transport.name} 原因=${result.failureMessage ?? '未知'}',
          level: LogLevel.error,
        );
        await _refreshStateForConfirmation();
        if (mounted) {
          AppSnack.error(context, _failureMessage(cmd, result.failureMessage));
          _pushCommand(
            _CommandEntry(
              kind: _kindFor(cmd),
              title: '${cmd.label}失败',
              subtitle: result.failureMessage?.trim().isNotEmpty == true
                  ? result.failureMessage!.trim()
                  : '请稍后重试',
              time: '刚刚',
              status: _CommandStatus.pending,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      } else {
        _busy = false;
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

  void _pushCommand(_CommandEntry entry) {
    setState(() {
      _commands.insert(0, entry);
      if (_commands.length > 4) {
        _commands.removeRange(4, _commands.length);
      }
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

  _CommandKind _kindFor(CommandCode command) {
    return switch (command) {
      CommandCode.powerOn || CommandCode.powerOff => _CommandKind.power,
      CommandCode.lock => _CommandKind.lock,
      CommandCode.unlock => _CommandKind.unlock,
      CommandCode.find => _CommandKind.find,
      CommandCode.openSeat => _CommandKind.seat,
      _ => _CommandKind.find,
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
        'Aurora 控车后确认车辆状态失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
    }
  }

  String _statusText(OfficialVehicle? cloudVehicle) {
    if (cloudVehicle == null) {
      if (!officialCloudService.state.signedIn) {
        return OfficialCloudMessages.signInRequired;
      }
      return '等待连接';
    }
    final online = cloudVehicle.onlineLabel;
    final channel = _topBarChannel().label;
    final sync = formatRelativeSyncText(
      officialCloudService.lastVehiclesRefreshAt,
    );
    final base = '$online · $channel · $sync';
    // P1: only when local BLE is still down and permission is the blocker.
    final needsBlePerm =
        !connectionManager.isProtocolLoggedIn &&
        connectionManager.state == ble.ConnectionState.disconnected &&
        cloudVehicle.normalizedDeviceMac.isNotEmpty &&
        _blePermission?.granted == false;
    if (needsBlePerm) {
      return '$base · 本地控车需授权蓝牙';
    }
    return base;
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

  bool _shouldShowNearFieldBanner(OfficialVehicle? vehicle) {
    if (vehicle == null) return false;
    if (vehicle.normalizedDeviceMac.isEmpty) return false;
    // Only when BLE is fully down — connecting/ready hides the banner.
    return connectionManager.state == ble.ConnectionState.disconnected &&
        !connectionManager.isProtocolLoggedIn;
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
      return perm.message ?? '请授予蓝牙和定位权限后再本地控车';
    }
    final reason = availability.disabledReason.trim();
    if (reason.isEmpty) return '当前不可控车，请检查蓝牙或网络';
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
    required OfficialVehicle? cloudVehicle,
    required bool signedIn,
    required bool hasVehicle,
  }) {
    final kind = VehicleControlHomeGate.resolve(
      signedIn: signedIn,
      hasVehicle: hasVehicle,
      loading: cloudState.loading,
      error: cloudState.error,
      showNearFieldHint: _shouldShowNearFieldBanner(cloudVehicle),
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
        return [_buildNearFieldBanner()];
      case VehicleControlHomeGateKind.none:
        return const [];
    }
  }

  Widget _buildNearFieldBanner() {
    final perm = _blePermission;
    if (_nearFieldBusy ||
        connectionManager.state == ble.ConnectionState.connecting) {
      return VehicleControlGateBanner(
        title: _nearFieldBusy ? '正在连接车辆蓝牙…' : '蓝牙连接中…',
        actionLabel: '连接中',
        busy: true,
        onAction: () {},
      );
    }
    if (perm != null && !perm.granted) {
      if (perm.openSettingsRecommended) {
        return VehicleControlGateBanner(
          title: '权限被关闭，请到系统设置开启蓝牙和定位',
          actionLabel: '去设置',
          onAction: () {
            unawaited(permissionService.openSystemSettings());
          },
        );
      }
      return VehicleControlGateBanner(
        title: '需要蓝牙和定位权限才能本地控车',
        actionLabel: '授权并连接',
        onAction: () => unawaited(_manualNearFieldConnect()),
      );
    }
    return VehicleControlGateBanner(
      title: '车辆在附近时可连接蓝牙本地控车',
      actionLabel: '连接蓝牙',
      onAction: () => unawaited(_manualNearFieldConnect()),
    );
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

  String _enduranceLabel(BatterySnapshot battery) {
    final km = battery.estimatedRangeKm;
    if (km == null || km <= 0) return '--';
    final hours = km / _urbanAvgSpeedKmh;
    if (hours < 0.1) return '<0.1 h';
    return '${formatCompactDecimal(hours)} h';
  }

  String _chargeCountLabel(BatterySnapshot battery) {
    final loop = battery.loopCount?.trim();
    if (loop == null || loop.isEmpty) return '--';
    return loop;
  }

  String _healthLabel(BatterySnapshot battery) {
    final score = battery.batteryScore?.trim();
    if (score != null && score.isNotEmpty) {
      final cleaned = score.replaceAll('%', '');
      return '健康 $cleaned%';
    }
    return '健康 ${battery.healthLabel}';
  }

  String _locationTitle(ResolvedVehicleLocation? location) {
    final address = location?.address.trim() ?? '';
    if (address.isNotEmpty) return address;
    final coords = location?.coordinateText ?? '';
    if (coords.isNotEmpty) return coords;
    return '暂无位置';
  }

  String _locationUpdated(ResolvedVehicleLocation? location) {
    final raw = location?.timeLabel.trim() ?? '';
    if (raw.isNotEmpty) return '更新于 $raw';
    final sync = formatRelativeSyncText(
      officialCloudService.lastVehiclesRefreshAt,
    );
    if (sync == '尚未同步') return '位置未同步';
    return sync.replaceFirst('同步', '更新');
  }

  String _locationWalk(ResolvedVehicleLocation? location) {
    if (location == null) return '待定位';
    if (location.source.isNotEmpty) return location.source;
    return '已定位';
  }

  void _openSettings() {
    if (!requireCloudVehicle(context)) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const VehicleSettingsPage()),
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
    super.build(context); // AutomaticKeepAliveClientMixin
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
    final controlChannelStatus = _topBarChannel(
      availability: controlAvailability,
    );
    final colors = AppColors.of(context);
    // Leave room for the shell bottom nav (see AppNav.contentBottomPadding).
    final bottomPad =
        AppNav.contentBottomPadding + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.pageBg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: 4, bottom: bottomPad),
            children: [
              ..._buildHomeGates(
                cloudState: cloudState,
                cloudVehicle: cloudVehicle,
                signedIn: signedIn,
                hasVehicle: hasVehicle,
              ),
              _TopBar(
                vehicleName: _vehicleName(cloudVehicle),
                statusText: _statusText(cloudVehicle),
                online: cloudVehicle?.online ?? false,
                channelActive: controlChannelStatus.isActive,
                powered: isPowerOn,
                onTitleTap: _openVehicleHeader,
                onSettings: _openSettings,
              ),
              const SizedBox(height: 10),
              _BatteryHeroCard(
                percent: percent,
                healthLabel: _healthLabel(battery),
                rangeKm: _rangeLabel(battery),
                enduranceHours: _enduranceLabel(battery),
                chargeCount: _chargeCountLabel(battery),
                todayKm: _todayRideLabel(cloudState),
                onTap: _openBattery,
              ),
              const SizedBox(height: 12),
              _LocationCard(
                title: _locationTitle(location),
                updated: _locationUpdated(location),
                walk: _locationWalk(location),
                onTap: _openLocation,
              ),
              const SizedBox(height: 12),
              _ControlChannelCard(
                selected: _controlChannel,
                availability: controlAvailability,
                status: controlChannelStatus,
                busy: _busy,
                onChanged: _selectControlChannel,
              ),
              const SizedBox(height: 12),
              _ShortcutsRow(
                armed: isArmed,
                powered: isPowerOn,
                // Dim when channel/session not ready, but keep taps so P0-A2
                // always surfaces a reason (never "点了没反应").
                dimmed:
                    _busy ||
                    !hasVehicle ||
                    !signedIn ||
                    !controlAvailability.enabled,
                onFind: () => _sendCommand(CommandCode.find),
                onArm: _sendArmToggle,
                onSeat: () => _sendCommand(CommandCode.openSeat),
                onPower: _sendPower,
              ),
              const SizedBox(height: 12),
              _RecentCommandsCard(commands: _commands),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Design tokens mapped onto theme/
// ═══════════════════════════════════════════════════════════════════════════
abstract final class _Aurora {
  static const cardMargin = EdgeInsets.symmetric(horizontal: 20);
  static const cardRadius = AppRadii.lg;
  static const cardShadow = AppShadows.elevation2;
  static const tabularNums = <FontFeature>[FontFeature.tabularFigures()];
  static const ringDuration = Duration(milliseconds: 850);
  static const ringCurve = Cubic(0.22, 1, 0.36, 1);
}

// ═══════════════════════════════════════════════════════════════════════════
// Top bar
// ═══════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.vehicleName,
    required this.statusText,
    required this.online,
    required this.channelActive,
    required this.powered,
    required this.onTitleTap,
    required this.onSettings,
  });

  final String vehicleName;
  final String statusText;
  final bool online;
  final bool channelActive;
  final bool? powered;
  final VoidCallback onTitleTap;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppPressable(
              onTap: onTitleTap,
              pressedScale: AppMotion.pressScale,
              semanticsLabel: '切换车辆 $vehicleName',
              semanticsButton: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicleName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      height: 1.2,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: channelActive
                              ? colors.primary
                              : (online
                                    ? colors.primary.withValues(alpha: 0.55)
                                    : colors.textTertiary),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PowerPill(powered: powered),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _IconButton(
            icon: Icons.settings_outlined,
            semanticsLabel: '设置',
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _PowerPill extends StatelessWidget {
  const _PowerPill({required this.powered});

  final bool? powered;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedContainer(
      duration: AppMotion.standard,
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: powered == true
            ? colors.primary.withValues(alpha: 0.12)
            : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        powered == null ? '电源未知' : (powered == true ? '通电中' : '已断电'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: powered == true ? colors.primary : colors.textTertiary,
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppPressable(
      onTap: onTap,
      pressedScale: AppMotion.pressScale,
      semanticsLabel: semanticsLabel,
      semanticsButton: true,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          boxShadow: dark ? const [] : _Aurora.cardShadow,
        ),
        child: Icon(icon, size: 18, color: colors.textSecondary),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Battery card
// ═══════════════════════════════════════════════════════════════════════════
class _BatteryHeroCard extends StatelessWidget {
  const _BatteryHeroCard({
    required this.percent,
    required this.healthLabel,
    required this.rangeKm,
    required this.enduranceHours,
    required this.chargeCount,
    required this.todayKm,
    required this.onTap,
  });

  final int percent;
  final String healthLabel;
  final String rangeKm;
  final String enduranceHours;
  final String chargeCount;
  final String todayKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < 360;
    final ringSize = compact ? 92.0 : 104.0;
    return Padding(
      padding: _Aurora.cardMargin,
      child: AppPressable(
        onTap: onTap,
        pressedScale: AppMotion.pressScale,
        borderRadius: BorderRadius.circular(_Aurora.cardRadius),
        background: colors.surface,
        boxShadow: dark ? const [] : _Aurora.cardShadow,
        semanticsLabel: '电池详情 电量 $percent%',
        semanticsButton: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '电池',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.textTertiary,
                    ),
                  ),
                  Text(
                    healthLabel,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: _BatteryRing(percent: percent, size: ringSize),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _MetricsGrid(
                      metrics: [
                        _Metric('预估里程', rangeKm),
                        _Metric('预计续航', enduranceHours),
                        _Metric('充电次数', chargeCount),
                        _Metric('今日骑行', todayKm),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatteryRing extends StatefulWidget {
  const _BatteryRing({required this.percent, required this.size});

  final int percent;
  final double size;

  @override
  State<_BatteryRing> createState() => _BatteryRingState();
}

class _BatteryRingState extends State<_BatteryRing> {
  double _target = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _target = widget.percent / 100.0);
    });
  }

  @override
  void didUpdateWidget(covariant _BatteryRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent != widget.percent) {
      _target = widget.percent / 100.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _target),
      duration: reduceMotion ? Duration.zero : _Aurora.ringDuration,
      curve: _Aurora.ringCurve,
      builder: (context, value, _) {
        return CustomPaint(
          painter: _BatteryRingPainter(
            progress: value,
            trackColor: colors.surfaceContainerHigh,
            valueColor: colors.primary,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.percent}%',
                  style: TextStyle(
                    fontSize: widget.size < 100 ? 22 : 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    height: 1,
                    color: colors.textPrimary,
                    fontFeatures: _Aurora.tabularNums,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '剩余',
                  style: TextStyle(fontSize: 11, color: colors.textTertiary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BatteryRingPainter extends CustomPainter {
  const _BatteryRingPainter({
    required this.progress,
    required this.trackColor,
    required this.valueColor,
  });

  final double progress;
  final Color trackColor;
  final Color valueColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 9.0;
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = valueColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      value,
    );
  }

  @override
  bool shouldRepaint(_BatteryRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.valueColor != valueColor;
}

class _Metric {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Widget cell(_Metric m) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          m.label,
          style: TextStyle(fontSize: 11, color: colors.textTertiary),
        ),
        const SizedBox(height: 3),
        Text(
          m.value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: colors.textPrimary,
            fontFeatures: _Aurora.tabularNums,
          ),
        ),
      ],
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cell(metrics[0])),
            const SizedBox(width: 10),
            Expanded(child: cell(metrics[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: cell(metrics[2])),
            const SizedBox(width: 10),
            Expanded(child: cell(metrics[3])),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Control channel
// ═══════════════════════════════════════════════════════════════════════════
class _ControlChannelCard extends StatelessWidget {
  const _ControlChannelCard({
    required this.selected,
    required this.availability,
    required this.status,
    required this.busy,
    required this.onChanged,
  });

  final OfficialControlChannel selected;
  final ControlChannelAvailability availability;
  final ControlTopBarChannel status;
  final bool busy;
  final ValueChanged<OfficialControlChannel> onChanged;

  String get _statusLabel {
    if (busy) return '指令执行中';
    if (availability.enabled ||
        status.kind == ControlTopBarChannelKind.bleConnecting ||
        status.kind == ControlTopBarChannelKind.mqttConnecting ||
        status.kind == ControlTopBarChannelKind.mqttRetry) {
      return status.label;
    }
    return '当前不可用';
  }

  String get _description {
    if (busy) return '当前指令执行中，暂不能切换控车渠道';
    if (!availability.enabled) {
      final reason = switch (selected) {
        OfficialControlChannel.automatic => availability.disabledReason,
        OfficialControlChannel.ble => availability.bleUnavailableReason,
        OfficialControlChannel.officialCloud =>
          availability.cloudUnavailableReason,
      };
      if (reason.trim().isNotEmpty) return reason.trim();
    }
    return switch (selected) {
      OfficialControlChannel.automatic => '根据车辆能力自动选择蓝牙或云端',
      OfficialControlChannel.ble => '仅使用附近车辆的蓝牙直连',
      OfficialControlChannel.officialCloud => '仅使用官方账号远程控车',
    };
  }

  Color _statusColor(AppColorsData colors) {
    if (busy) return colors.warning;
    return switch (status.kind) {
      ControlTopBarChannelKind.bleDirect ||
      ControlTopBarChannelKind.mqttRemote ||
      ControlTopBarChannelKind.cloudStandby => colors.success,
      ControlTopBarChannelKind.bleConnecting ||
      ControlTopBarChannelKind.mqttConnecting ||
      ControlTopBarChannelKind.mqttRetry => colors.warning,
      ControlTopBarChannelKind.unavailable => colors.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: _Aurora.cardMargin,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.all(
          Radius.circular(_Aurora.cardRadius),
        ),
        boxShadow: dark ? const [] : _Aurora.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route, size: 18, color: colors.textSecondary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '控车渠道',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _statusColor(colors),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<OfficialControlChannel>(
            segments: const [
              ButtonSegment(
                value: OfficialControlChannel.automatic,
                icon: Icon(Icons.alt_route, size: 16),
                label: Text('智能'),
              ),
              ButtonSegment(
                value: OfficialControlChannel.ble,
                icon: Icon(Icons.bluetooth, size: 16),
                label: Text('仅蓝牙'),
              ),
              ButtonSegment(
                value: OfficialControlChannel.officialCloud,
                icon: Icon(Icons.cloud_outlined, size: 16),
                label: Text('仅云端'),
              ),
            ],
            selected: {selected},
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
            onSelectionChanged: busy
                ? null
                : (selection) => onChanged(selection.first),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 6),
              ),
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? Colors.white
                    : colors.textSecondary;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? colors.primary
                    : colors.surfaceContainerHigh;
              }),
              side: WidgetStateProperty.resolveWith((states) {
                return BorderSide(
                  color: states.contains(WidgetState.selected)
                      ? colors.primary
                      : colors.outlineVariant,
                );
              }),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                _description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: availability.enabled
                      ? colors.textTertiary
                      : colors.danger,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shortcuts
// ═══════════════════════════════════════════════════════════════════════════
class _ShortcutsRow extends StatelessWidget {
  const _ShortcutsRow({
    required this.armed,
    required this.powered,
    required this.dimmed,
    required this.onFind,
    required this.onArm,
    required this.onSeat,
    required this.onPower,
  });

  final bool? armed;
  final bool? powered;
  final bool dimmed;
  final VoidCallback onFind;
  final VoidCallback onArm;
  final VoidCallback onSeat;
  final VoidCallback onPower;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: _Aurora.cardMargin,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.all(
          Radius.circular(_Aurora.cardRadius),
        ),
        boxShadow: dark ? const [] : _Aurora.cardShadow,
      ),
      child: Opacity(
        opacity: dimmed ? 0.55 : 1,
        child: Row(
          children: [
            Expanded(
              child: _Shortcut(
                icon: Icons.campaign_outlined,
                label: '寻车',
                sub: '鸣笛闪灯',
                style: _ShortcutStyle.neutral,
                onTap: onFind,
              ),
            ),
            Expanded(
              child: _Shortcut(
                icon: armed == null
                    ? Icons.help_outline
                    : (armed! ? Icons.lock_outline : Icons.lock_open),
                label: armed == null ? '设防未知' : (armed! ? '已设防' : '未设防'),
                sub: armed == null ? '刷新后重试' : (armed! ? '车锁已锁' : '点击设防'),
                style: armed == true
                    ? _ShortcutStyle.armed
                    : _ShortcutStyle.neutral,
                onTap: onArm,
              ),
            ),
            Expanded(
              child: _Shortcut(
                icon: Icons.event_seat_outlined,
                label: '开坐垫',
                sub: '解锁储物',
                style: _ShortcutStyle.neutral,
                onTap: onSeat,
              ),
            ),
            Expanded(
              child: _Shortcut(
                icon: Icons.power_settings_new,
                label: powered == null ? '电源未知' : (powered! ? '已通电' : '已断电'),
                sub: powered == null ? '刷新后重试' : (powered! ? '动力已开' : '点击通电'),
                style: powered == true
                    ? _ShortcutStyle.powerOn
                    : _ShortcutStyle.powerOff,
                onTap: onPower,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ShortcutStyle { neutral, armed, powerOn, powerOff }

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.sub,
    required this.style,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final _ShortcutStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (glyphBg, glyphFg, labelColor) = switch (style) {
      _ShortcutStyle.neutral => (
        colors.surfaceContainerHigh,
        colors.textSecondary,
        colors.textPrimary,
      ),
      _ShortcutStyle.armed => (
        colors.warning.withValues(alpha: 0.12),
        colors.warning,
        colors.warning,
      ),
      _ShortcutStyle.powerOn => (colors.primary, Colors.white, colors.primary),
      _ShortcutStyle.powerOff => (
        colors.surfaceContainerHigh,
        colors.textTertiary,
        colors.textTertiary,
      ),
    };

    return AppPressable(
      enabled: true,
      onTap: onTap,
      pressedScale: AppMotion.pressScale,
      semanticsLabel: '$label，$sub',
      semanticsButton: true,
      semanticsEnabled: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.standard,
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: glyphBg, shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: glyphFg),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Location card
// ═══════════════════════════════════════════════════════════════════════════
class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.title,
    required this.updated,
    required this.walk,
    required this.onTap,
  });

  final String title;
  final String updated;
  final String walk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: _Aurora.cardMargin,
      child: AppPressable(
        onTap: onTap,
        pressedScale: AppMotion.pressScale,
        borderRadius: BorderRadius.circular(_Aurora.cardRadius),
        background: colors.surface,
        boxShadow: dark ? const [] : _Aurora.cardShadow,
        semanticsLabel: '车辆位置 $title，$updated，$walk',
        semanticsButton: true,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const _MapThumb(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      updated,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  walk,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapThumb extends StatelessWidget {
  const _MapThumb();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.md),
        color: colors.surfaceContainerHigh,
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: Icon(Icons.location_on, size: 18, color: colors.primary),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Recent commands (session-local log of real cloud command outcomes)
// ═══════════════════════════════════════════════════════════════════════════
enum _CommandStatus { ok, pending }

enum _CommandKind { power, lock, unlock, find, seat }

class _CommandEntry {
  const _CommandEntry({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.status,
  });

  final _CommandKind kind;
  final String title;
  final String subtitle;
  final String time;
  final _CommandStatus status;

  IconData get icon => switch (kind) {
    _CommandKind.power => Icons.power_settings_new,
    _CommandKind.lock => Icons.lock_outline,
    _CommandKind.unlock => Icons.lock_open,
    _CommandKind.find => Icons.campaign_outlined,
    _CommandKind.seat => Icons.event_seat_outlined,
  };
}

class _RecentCommandsCard extends StatelessWidget {
  const _RecentCommandsCard({required this.commands});

  final List<_CommandEntry> commands;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: _Aurora.cardMargin,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.all(
          Radius.circular(_Aurora.cardRadius),
        ),
        boxShadow: dark ? const [] : _Aurora.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '最近命令',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  commands.isEmpty ? '暂无' : '${commands.length} 条',
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
              ],
            ),
          ),
          if (commands.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Text(
                '发送控车指令后会显示在这里',
                style: TextStyle(fontSize: 12, color: colors.textTertiary),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
              child: Column(
                children: [for (final c in commands) _CommandRow(entry: c)],
              ),
            ),
        ],
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({required this.entry});

  final _CommandEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ok = entry.status == _CommandStatus.ok;
    final iconBg = ok
        ? colors.primary.withValues(alpha: 0.12)
        : colors.warning.withValues(alpha: 0.12);
    final iconFg = ok ? colors.primary : colors.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(entry.icon, size: 15, color: iconFg),
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: colors.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            entry.time,
            style: TextStyle(
              fontSize: 11,
              color: colors.textTertiary,
              fontFeatures: _Aurora.tabularNums,
            ),
          ),
        ],
      ),
    );
  }
}
