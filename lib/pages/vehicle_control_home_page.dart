import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../models/battery_snapshot.dart';
import '../models/command_types.dart';
import '../models/official_vehicle.dart';
import '../services/control_channel_resolver.dart';
import '../services/control_command_executor.dart';
import '../services/control_command_policy.dart';
import '../services/display_number_formatter.dart';
import '../services/display_time_formatter.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../services/official_mqtt_service.dart';
import '../services/vehicle_location_resolver.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/cloud_vehicle_gate.dart';
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
    with AutomaticKeepAliveClientMixin {
  final _commandExecutor = ControlCommandExecutor(
    sendBleCommand: (command) => connectionManager.sendCommand(command),
    sendCloudCommand: (command) => OfficialMqttService().sendCommandPreferMqtt(
      command: command,
      cloud: officialCloudService,
    ),
  );
  final Stopwatch _controlDebounceWatch = Stopwatch();
  final List<_CommandEntry> _commands = <_CommandEntry>[];

  StreamSubscription<OfficialCloudState>? _cloudSub;
  StreamSubscription<ble.ConnectionState>? _bleStateSub;
  bool _busy = false;
  bool _disposed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cloudSub = officialCloudService.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _bleStateSub = connectionManager.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
    unawaited(_silentRefresh());
  }

  @override
  void dispose() {
    _disposed = true;
    final cloudSub = _cloudSub;
    if (cloudSub != null) unawaited(cloudSub.cancel());
    final bleSub = _bleStateSub;
    if (bleSub != null) unawaited(bleSub.cancel());
    super.dispose();
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

  bool _currentIsPowerOn() {
    return officialCloudService.state.selectedVehicle?.isPowerOn ?? false;
  }

  ControlChannelAvailability _controlAvailability() {
    return ControlChannelResolver.resolve(
      cloudState: officialCloudService.state,
      bleReady: connectionManager.state == ble.ConnectionState.ready,
      defaultVehicleId: vehicleStore.defaultVehicle?.id,
      busy: _busy,
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
    final isPowerOn = _currentIsPowerOn();
    final cmd = isPowerOn ? CommandCode.powerOff : CommandCode.powerOn;
    await _sendCommand(cmd);
  }

  Future<void> _sendArmToggle() async {
    final locked =
        officialCloudService.state.selectedVehicle?.isLocked ?? false;
    final cmd = locked ? CommandCode.unlock : CommandCode.lock;
    await _sendCommand(cmd);
  }

  Future<void> _sendCommand(CommandCode cmd) async {
    if (_busy) return;
    if (_isControlDebounced()) {
      if (mounted) AppSnack.error(context, '请勿频繁操作');
      return;
    }
    final policy = ControlCommandPolicy.evaluate(
      command: cmd,
      isPowerOn: _currentIsPowerOn(),
    );
    if (!policy.allowed) {
      if (mounted) {
        AppSnack.error(context, policy.disabledReason ?? '${cmd.label}不可用');
      }
      return;
    }
    final availability = _controlAvailability();
    if (!availability.enabled) {
      if (mounted) AppSnack.error(context, availability.disabledReason);
      return;
    }

    setState(() => _busy = true);
    unawaited(HapticFeedback.mediumImpact());
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

      final result = await _commandExecutor.send(
        command: cmd,
        availability: availability,
      );
      if (result.success) {
        _runBackgroundTask(
          locationService.recordDefaultVehicleLocation(),
          failureMessage: '控车后记录车辆位置失败',
        );
        final confirmed = await _waitForCommandConfirmation(cmd);
        if (!mounted) return;
        if (!confirmed) {
          await _refreshStateForConfirmation();
          if (!mounted) return;
          AppSnack.error(context, _unconfirmedMessage(cmd));
          _pushCommand(
            _CommandEntry(
              kind: _kindFor(cmd),
              title: '${cmd.label}未确认',
              subtitle: '请稍后重试',
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
    return switch (command) {
      CommandCode.lock ||
      CommandCode.unlock ||
      CommandCode.powerOn ||
      CommandCode.powerOff => true,
      _ => false,
    };
  }

  Future<bool> _waitForCommandConfirmation(CommandCode command) async {
    if (!_needsStateConfirmation(command)) return true;

    final confirmationTimer = Stopwatch()..start();
    while (mounted && !_disposed) {
      if (_isCommandConfirmed(command)) return true;
      if (confirmationTimer.elapsed > _controlConfirmTimeout) return false;

      await _refreshStateForConfirmation();
      if (_isCommandConfirmed(command)) return true;
      if (confirmationTimer.elapsed > _controlConfirmTimeout) return false;

      await Future<void>.delayed(_controlConfirmPollDelay);
    }
    return false;
  }

  bool _isCommandConfirmed(CommandCode command) {
    final vehicle = officialCloudService.state.selectedVehicle;
    if (vehicle == null) return false;
    return switch (command) {
      CommandCode.lock => vehicle.isLocked,
      CommandCode.unlock => !vehicle.isLocked,
      CommandCode.powerOn => vehicle.isPowerOn,
      CommandCode.powerOff => !vehicle.isPowerOn,
      _ => true,
    };
  }

  Future<void> _refreshStateForConfirmation() async {
    try {
      await officialCloudService.refreshVehicles(
        silent: true,
        refreshReplicaDetails: false,
        force: true,
      );
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
    final sync = formatRelativeSyncText(
      officialCloudService.lastVehiclesRefreshAt,
    );
    return '$online · $sync';
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
    final todayKey = formatDateText(DateTime.now());
    for (final day in cloudState.travelDays) {
      if (normalizeOfficialDateKey(day.travelDate) != todayKey) continue;
      final total = day.totalMileage.trim();
      if (total.isNotEmpty) {
        return '${formatCompactDecimalText(total)} km';
      }
      final km = sumTravelMileageKm(day.records);
      if (km > 0) return '${formatCompactDecimal(km)} km';
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
    final isPowerOn = cloudVehicle?.isPowerOn ?? false;
    final isArmed = cloudVehicle?.isLocked ?? false;
    final percent = battery.percent ?? 0;
    final signedIn = cloudState.signedIn;
    final hasVehicle = cloudVehicle != null;
    // Leave room for the shell bottom nav (see AppNav.contentBottomPadding).
    final bottomPad =
        AppNav.contentBottomPadding + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _Aurora.pageBg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: 4, bottom: bottomPad),
            children: [
              if (!signedIn)
                _GateBanner(
                  title: '请先登录官方账号',
                  actionLabel: '去登录',
                  onAction: () => unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginPage(),
                      ),
                    ),
                  ),
                )
              else if (!hasVehicle)
                _GateBanner(
                  title: '暂无车辆，请先同步官方车辆',
                  actionLabel: '添加车辆',
                  onAction: () => unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AddVehiclePage(),
                      ),
                    ),
                  ),
                ),
              _TopBar(
                vehicleName: _vehicleName(cloudVehicle),
                statusText: _statusText(cloudVehicle),
                online: cloudVehicle?.online ?? false,
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
              _ShortcutsRow(
                armed: isArmed,
                powered: isPowerOn,
                busy: _busy || !hasVehicle || !signedIn,
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
// Gate banner (login / no vehicle)
// ═══════════════════════════════════════════════════════════════════════════
class _GateBanner extends StatelessWidget {
  const _GateBanner({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _Aurora.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _Aurora.accentDeep,
              ),
            ),
          ),
          AppPressable(
            onTap: onAction,
            pressedScale: AppMotion.pressScale,
            semanticsLabel: actionLabel,
            semanticsButton: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _Aurora.accent,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
// Design tokens mapped onto theme/
// ═══════════════════════════════════════════════════════════════════════════
abstract final class _Aurora {
  static const accent = AppColors.primary;
  static const accentDeep = AppColors.primaryDark;
  static const accentSoft = AppColors.energySoft;
  static const warning = AppColors.warning;
  static const pageBg = AppColors.pageBg;
  static const surface = AppColors.surface;
  static const surfaceSoft = AppColors.surfaceContainerHigh;
  static const fg = AppColors.textPrimary;
  static const fgSecondary = AppColors.textSecondary;
  static const muted = AppColors.textTertiary;

  static const warningInk = Color(0xFFC56A10);
  static const ringTrack = Color(0xFFEEF0F2);

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
    required this.powered,
    required this.onTitleTap,
    required this.onSettings,
  });

  final String vehicleName;
  final String statusText;
  final bool online;
  final bool powered;
  final VoidCallback onTitleTap;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
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
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      height: 1.2,
                      color: _Aurora.fg,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: online ? _Aurora.accent : _Aurora.muted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _Aurora.fgSecondary,
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

  final bool powered;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.standard,
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: powered ? _Aurora.accentSoft : _Aurora.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        powered ? '通电中' : '已断电',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: powered ? _Aurora.accentDeep : _Aurora.muted,
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
    return AppPressable(
      onTap: onTap,
      pressedScale: AppMotion.pressScale,
      semanticsLabel: semanticsLabel,
      semanticsButton: true,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: _Aurora.surface,
          shape: BoxShape.circle,
          boxShadow: _Aurora.cardShadow,
        ),
        child: Icon(icon, size: 18, color: _Aurora.fgSecondary),
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
    final compact = MediaQuery.sizeOf(context).width < 360;
    final ringSize = compact ? 92.0 : 104.0;
    return Padding(
      padding: _Aurora.cardMargin,
      child: AppPressable(
        onTap: onTap,
        pressedScale: AppMotion.pressScale,
        borderRadius: BorderRadius.circular(_Aurora.cardRadius),
        background: _Aurora.surface,
        boxShadow: _Aurora.cardShadow,
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
                  const Text(
                    '电池',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _Aurora.muted,
                    ),
                  ),
                  Text(
                    healthLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _Aurora.fgSecondary,
                    ),
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
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _target),
      duration: reduceMotion ? Duration.zero : _Aurora.ringDuration,
      curve: _Aurora.ringCurve,
      builder: (context, value, _) {
        return CustomPaint(
          painter: _BatteryRingPainter(progress: value),
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
                    color: _Aurora.fg,
                    fontFeatures: _Aurora.tabularNums,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '剩余',
                  style: TextStyle(fontSize: 11, color: _Aurora.muted),
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
  const _BatteryRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 9.0;
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = _Aurora.ringTrack;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = _Aurora.accent;
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
      oldDelegate.progress != progress;
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
    Widget cell(_Metric m) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          m.label,
          style: const TextStyle(fontSize: 11, color: _Aurora.muted),
        ),
        const SizedBox(height: 3),
        Text(
          m.value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: _Aurora.fg,
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
// Shortcuts
// ═══════════════════════════════════════════════════════════════════════════
class _ShortcutsRow extends StatelessWidget {
  const _ShortcutsRow({
    required this.armed,
    required this.powered,
    required this.busy,
    required this.onFind,
    required this.onArm,
    required this.onSeat,
    required this.onPower,
  });

  final bool armed;
  final bool powered;
  final bool busy;
  final VoidCallback onFind;
  final VoidCallback onArm;
  final VoidCallback onSeat;
  final VoidCallback onPower;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: _Aurora.cardMargin,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
      decoration: const BoxDecoration(
        color: _Aurora.surface,
        borderRadius: BorderRadius.all(Radius.circular(_Aurora.cardRadius)),
        boxShadow: _Aurora.cardShadow,
      ),
      child: Opacity(
        opacity: busy ? 0.55 : 1,
        child: Row(
          children: [
            Expanded(
              child: _Shortcut(
                icon: Icons.campaign_outlined,
                label: '寻车',
                sub: '鸣笛闪灯',
                style: _ShortcutStyle.neutral,
                enabled: !busy,
                onTap: onFind,
              ),
            ),
            Expanded(
              child: _Shortcut(
                icon: armed ? Icons.lock_outline : Icons.lock_open,
                label: armed ? '已设防' : '未设防',
                sub: armed ? '车锁已锁' : '点击设防',
                style: armed ? _ShortcutStyle.armed : _ShortcutStyle.neutral,
                enabled: !busy,
                onTap: onArm,
              ),
            ),
            Expanded(
              child: _Shortcut(
                icon: Icons.event_seat_outlined,
                label: '开坐垫',
                sub: '解锁储物',
                style: _ShortcutStyle.neutral,
                enabled: !busy,
                onTap: onSeat,
              ),
            ),
            Expanded(
              child: _Shortcut(
                icon: Icons.power_settings_new,
                label: powered ? '已通电' : '已断电',
                sub: powered ? '动力已开' : '点击通电',
                style: powered
                    ? _ShortcutStyle.powerOn
                    : _ShortcutStyle.powerOff,
                enabled: !busy,
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
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final _ShortcutStyle style;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (glyphBg, glyphFg, labelColor) = switch (style) {
      _ShortcutStyle.neutral => (
        _Aurora.surfaceSoft,
        _Aurora.fgSecondary,
        _Aurora.fg,
      ),
      _ShortcutStyle.armed => (
        _Aurora.warning.withValues(alpha: 0.12),
        _Aurora.warning,
        _Aurora.warningInk,
      ),
      _ShortcutStyle.powerOn => (
        _Aurora.accent,
        Colors.white,
        _Aurora.accentDeep,
      ),
      _ShortcutStyle.powerOff => (
        _Aurora.surfaceSoft,
        _Aurora.muted,
        _Aurora.muted,
      ),
    };

    return AppPressable(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      pressedScale: AppMotion.pressScale,
      semanticsLabel: '$label，$sub',
      semanticsButton: true,
      semanticsEnabled: enabled,
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
              style: const TextStyle(
                fontSize: 11,
                height: 1.2,
                color: _Aurora.muted,
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
    return Padding(
      padding: _Aurora.cardMargin,
      child: AppPressable(
        onTap: onTap,
        pressedScale: AppMotion.pressScale,
        borderRadius: BorderRadius.circular(_Aurora.cardRadius),
        background: _Aurora.surface,
        boxShadow: _Aurora.cardShadow,
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _Aurora.fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      updated,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _Aurora.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: _Aurora.surfaceSoft,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  walk,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _Aurora.fgSecondary,
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
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.md),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE6F7F1), Color(0xFFEEF2F6)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Center(
        child: Icon(Icons.location_on, size: 18, color: _Aurora.accent),
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
    return Container(
      margin: _Aurora.cardMargin,
      decoration: const BoxDecoration(
        color: _Aurora.surface,
        borderRadius: BorderRadius.all(Radius.circular(_Aurora.cardRadius)),
        boxShadow: _Aurora.cardShadow,
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
                const Text(
                  '最近命令',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _Aurora.fg,
                  ),
                ),
                Text(
                  commands.isEmpty ? '暂无' : '${commands.length} 条',
                  style: const TextStyle(fontSize: 12, color: _Aurora.muted),
                ),
              ],
            ),
          ),
          if (commands.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Text(
                '发送控车指令后会显示在这里',
                style: TextStyle(fontSize: 12, color: _Aurora.muted),
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
    final ok = entry.status == _CommandStatus.ok;
    final iconBg = ok
        ? _Aurora.accentSoft
        : _Aurora.warning.withValues(alpha: 0.12);
    final iconFg = ok ? _Aurora.accentDeep : _Aurora.warning;
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _Aurora.fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _Aurora.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            entry.time,
            style: const TextStyle(
              fontSize: 11,
              color: _Aurora.muted,
              fontFeatures: _Aurora.tabularNums,
            ),
          ),
        ],
      ),
    );
  }
}
