import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart';
import '../models/vehicle_profile.dart';
import '../services/control_channel_resolver.dart';
import '../services/control_command_confirmation.dart';
import '../services/control_command_executor.dart';
import '../services/control_command_policy.dart';
import '../services/control_command_result.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../services/replica_feature_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/slide_to_action.dart';
import 'battery_details_page.dart';
import 'device_info_page.dart';
import 'diagnostic_page.dart';
import 'garage_page.dart';
import 'location_page.dart';
import 'log_page.dart';
import 'official_cloud_page.dart';
import 'official_replica_pages.dart';
import 'ota_precheck_page.dart';
import 'vehicle_message_page.dart';
import 'vehicle_settings_page.dart';

part 'control_page_quick_controls.dart';
part 'control_page_visuals.dart';
part 'control_page_service_cards.dart';
part 'control_page_unbound_home.dart';
part 'control_page_home_overview.dart';
part 'control_page_home_header.dart';
part 'control_page_home_status.dart';
part 'control_page_vehicle_overview.dart';
part 'control_page_control_widgets.dart';
part 'control_page_main_controls.dart';
part 'control_page_mode_widgets.dart';

const _pageBg = AppColors.pageBg;
const _kmPerPercent = 0.65;
const _phoneControlItemBg = AppColors.surfaceContainerLow;
const _phoneControlPrimary = AppColors.primary;
const _phoneControlRadius = 16.0;
const _officialPressedBg = Color(0xFFE5E5E5);

// 服务卡片强调色（control_page_service_cards.dart 复用）
const _serviceAccentViolet = Color(0xFF7B61FF);
const _serviceAccentAmber = Color(0xFFFF8A00);
const _serviceMutedText = Color(0xFFAAA9B1);
const _serviceCardBorder = AppColors.outlineVariant;
const _controlConfirmTimeout = Duration(seconds: 8);
const _controlConfirmPollDelay = Duration(milliseconds: 800);
// M3: elevated card without border, soft dual-layer shadow
const _cardDecoration = BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
  boxShadow: AppShadows.elevation1,
);

int? _normalizePercent(int? value) {
  if (value == null) return null;
  return value.clamp(0, 100).toInt();
}

String _formatMetricNumber(num value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.05) return rounded.toInt().toString();
  return value.toStringAsFixed(1);
}

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// Pull-to-refresh: re-sync cloud vehicle data when signed in, otherwise just
  /// settle briefly so the indicator animation feels intentional.
  Future<void> _handleRefresh() async {
    if (officialCloudService.state.signedIn) {
      try {
        await officialCloudService.refreshVehicles(force: true);
      } catch (e) {
        logService.operation('首页下拉刷新失败', detail: '$e', level: LogLevel.warning);
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 静态外壳只构建一次；仅随数据变化的内容下沉到 [_HomeBody]，
    // 避免每次连接态/车辆/云态事件都重建 Scaffold/RefreshIndicator/滚动容器。
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: AppNav.contentBottomPadding),
            child: const _HomeBody(),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  late final Stream<List<dynamic>> _combinedStream;
  StreamSubscription<dynamic>? _subConn;
  StreamSubscription<dynamic>? _subVehicles;
  StreamSubscription<dynamic>? _subCloud;
  StreamController<List<dynamic>>? _controller;

  @override
  void initState() {
    super.initState();
    _combinedStream = _createCombinedStream();
  }

  Stream<List<dynamic>> _createCombinedStream() {
    final controller = StreamController<List<dynamic>>.broadcast();
    var latestConn = connectionManager.state;
    var latestVehicles = vehicleStore.vehicles;
    var latestCloud = officialCloudService.state;

    void emit() {
      if (!controller.isClosed) {
        controller.add([latestConn, latestVehicles, latestCloud]);
      }
    }

    // Emit initial values
    scheduleMicrotask(emit);

    _subConn = connectionManager.stateStream.listen((s) {
      latestConn = s;
      emit();
    });
    _subVehicles = vehicleStore.vehiclesStream.listen((v) {
      latestVehicles = v;
      emit();
    });
    _subCloud = officialCloudService.stateStream.listen((c) {
      latestCloud = c;
      emit();
    });

    _controller = controller;
    controller.onCancel = _cancelSubscriptions;

    return controller.stream;
  }

  Future<void> _cancelSubscriptions() async {
    await _subConn?.cancel();
    await _subVehicles?.cancel();
    await _subCloud?.cancel();
    _subConn = null;
    _subVehicles = null;
    _subCloud = null;
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
      stream: _combinedStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final connState = snapshot.data![0] as ble.ConnectionState;
        final vehicles = snapshot.data![1] as List<VehicleProfile>;
        final cloudState = snapshot.data![2] as OfficialCloudState;
        final hasLocalVehicle =
            vehicles.isNotEmpty || vehicleStore.defaultVehicle != null;
        final hasCloudVehicle =
            cloudState.signedIn && cloudState.selectedVehicle != null;
        final hasTransientDevice =
            connectionManager.device != null ||
            connState != ble.ConnectionState.disconnected;
        final showUnboundHome =
            !hasLocalVehicle && !hasCloudVehicle && !hasTransientDevice;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.018),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
          child: showUnboundHome
              ? const _UnboundVehicleHome()
              : Column(
                  key: const ValueKey('bound-home'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HomeTopSection(connState: connState),
                    const SizedBox(height: 14),
                    _ControlArea(connState: connState),
                    const SizedBox(height: 14),
                    const _HomeQuickSection(),
                    const SizedBox(height: 14),
                    _RidingModeSelector(connState: connState),
                    const SizedBox(height: 20),
                  ],
                ),
        );
      },
    );
  }
}

class _ControlArea extends StatefulWidget {
  final ble.ConnectionState connState;
  const _ControlArea({required this.connState});

  @override
  State<_ControlArea> createState() => _ControlAreaState();
}

class _ControlAreaViewModel {
  final OfficialControlChannel channel;
  final bool canUseBle;
  final bool canUseCloud;
  final bool enabled;
  final String disabledReason;
  final String? vehicleName;
  final bool isLocked;
  final bool isPowerOn;
  final bool seatActive;
  final bool powerLoading;
  final bool lockActive;
  final bool findActive;

  const _ControlAreaViewModel({
    required this.channel,
    required this.canUseBle,
    required this.canUseCloud,
    required this.enabled,
    required this.disabledReason,
    required this.vehicleName,
    required this.isLocked,
    required this.isPowerOn,
    required this.seatActive,
    required this.powerLoading,
    required this.lockActive,
    required this.findActive,
  });

  String? get visibleDisabledReason => enabled ? null : disabledReason;

  bool commandEnabled(CommandCode command) {
    return enabled &&
        ControlCommandPolicy.evaluate(
          command: command,
          isPowerOn: isPowerOn,
        ).allowed;
  }

  String commandDisabledReason(CommandCode command) {
    if (!enabled) return disabledReason;
    return ControlCommandPolicy.evaluate(
          command: command,
          isPowerOn: isPowerOn,
        ).disabledReason ??
        disabledReason;
  }

  bool get seatEnabled => commandEnabled(CommandCode.openSeat);

  String get seatDisabledReason => commandDisabledReason(CommandCode.openSeat);

  String get powerLabel => isPowerOn ? '熄火' : '启动';

  String get powerHint => isPowerOn ? '左滑关闭' : '右滑启动';

  String get powerLoadingLabel => isPowerOn ? '正在熄火' : '正在启动';

  IconData get powerIcon =>
      isPowerOn ? Icons.power_off : Icons.power_settings_new;

  Color get powerColor => isPowerOn ? AppColors.danger : _phoneControlPrimary;

  CommandCode get powerCommand =>
      isPowerOn ? CommandCode.powerOff : CommandCode.powerOn;

  String get lockLabel => isLocked ? '解锁' : '设防';

  IconData get lockIcon => isLocked ? Icons.lock_open : Icons.lock_outline;

  CommandCode get lockCommand =>
      isLocked ? CommandCode.unlock : CommandCode.lock;

  bool get findEnabled => commandEnabled(CommandCode.find);

  String get findDisabledReason => commandDisabledReason(CommandCode.find);
}

class _ControlAreaState extends State<_ControlArea> {
  final _commandExecutor = ControlCommandExecutor(
    sendBleCommand: connectionManager.sendCommand,
    sendCloudCommand: officialCloudService.sendCommand,
  );
  final _confirmationGuard = const ControlCommandConfirmationGuard();
  bool _busy = false;
  bool _disposed = false;
  String? _activeControlId;
  MainControlConfig _mainControlConfig = const MainControlConfig();
  late final Stream<List<dynamic>> _combinedStream;
  StreamSubscription<dynamic>? _subCloud;
  StreamSubscription<dynamic>? _subBike;
  StreamController<List<dynamic>>? _combinedController;

  @override
  void initState() {
    super.initState();
    _loadMainControlConfig();
    _combinedStream = _createCombinedStream();
  }

  Stream<List<dynamic>> _createCombinedStream() {
    final controller = StreamController<List<dynamic>>.broadcast();
    var latestCloud = officialCloudService.state;
    var latestBike = connectionManager.latestBikeState;

    void emit() {
      if (!controller.isClosed) {
        controller.add([latestCloud, latestBike]);
      }
    }

    scheduleMicrotask(emit);

    _subCloud = officialCloudService.stateStream.listen((c) {
      latestCloud = c;
      emit();
    });
    _subBike = connectionManager.bikeStateStream.listen((b) {
      latestBike = b;
      emit();
    });

    _combinedController = controller;
    controller.onCancel = _cancelCombinedSubscriptions;

    return controller.stream;
  }

  Future<void> _cancelCombinedSubscriptions() async {
    await _subCloud?.cancel();
    await _subBike?.cancel();
    _subCloud = null;
    _subBike = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelCombinedSubscriptions();
    _combinedController?.close();
    super.dispose();
  }

  Future<void> _loadMainControlConfig() async {
    final cfg = await ReplicaFeatureStore().loadMainControlConfig();
    if (!mounted) return;
    setState(() => _mainControlConfig = cfg);
  }

  /// Catalog entries ordered per saved config, with any catalog ids missing
  /// from the saved order appended so newly added controls still surface.
  List<_MainControlCatalogEntry> _orderedCatalog() {
    final byId = {for (final e in _mainControlCatalog) e.id: e};
    final result = <_MainControlCatalogEntry>[];
    for (final id in _mainControlConfig.order) {
      final entry = byId.remove(id);
      if (entry != null) result.add(entry);
    }
    for (final e in _mainControlCatalog) {
      if (byId.containsKey(e.id)) result.add(e);
    }
    return result;
  }

  List<_MainControlButtonData> _buildButtons(_ControlAreaViewModel model) {
    final catalog = _orderedCatalog();
    final buttonMap = <String, _MainControlButtonData>{
      'find': _MainControlButtonData(
        id: 'find',
        icon: Icons.volume_up,
        label: '寻车',
        accent: AppColors.accentTeal,
        loadingLabel: ControlLoadingLabel.find.text,
        enabled: model.findEnabled,
        active: model.findActive,
        disabledReason: model.findDisabledReason,
        onTap: () => _send(CommandCode.find, actionId: 'fixedFind'),
      ),
      'lock': _MainControlButtonData(
        id: 'lock',
        icon: model.lockIcon,
        label: model.lockLabel,
        accent: _serviceAccentAmber,
        loadingLabel: model.lockLabel == '解锁'
            ? ControlLoadingLabel.unlock.text
            : ControlLoadingLabel.lock.text,
        enabled: model.enabled,
        active: model.lockActive,
        disabledReason: model.disabledReason,
        onTap: () => _send(model.lockCommand, actionId: 'fixedLock'),
      ),
      'seat': _MainControlButtonData(
        id: 'seat',
        icon: Icons.inventory_2,
        label: '座桶',
        accent: const Color(0xFF8D6E63),
        loadingLabel: ControlLoadingLabel.execute.text,
        enabled: model.seatEnabled,
        active: model.seatActive,
        disabledReason: model.seatDisabledReason,
        onTap: () => _send(CommandCode.openSeat, actionId: 'fixedSeat'),
      ),
    };
    return [
      for (final entry in catalog)
        if (!_mainControlConfig.hidden.contains(entry.id) &&
            buttonMap.containsKey(entry.id))
          buttonMap[entry.id]!,
    ];
  }

  Future<void> _editMainControls() async {
    final updated = await Navigator.push<MainControlConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => _MainControlEditPage(
          entries: _orderedCatalog(),
          hidden: _mainControlConfig.hidden,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _mainControlConfig = updated);
    await ReplicaFeatureStore().saveMainControlConfig(updated);
  }

  Future<void> _send(CommandCode cmd, {required String actionId}) async {
    if (_busy) return;
    final cloudState = officialCloudService.state;
    final policy = ControlCommandPolicy.evaluate(
      command: cmd,
      isPowerOn: _currentIsPowerOn(cloudState),
    );
    if (!policy.allowed) {
      _showUnavailableSnack(policy.disabledReason ?? '${cmd.label}不可用');
      return;
    }
    setState(() {
      _busy = true;
      _activeControlId = actionId;
    });
    HapticFeedback.mediumImpact();
    try {
      final availability = _controlAvailability(cloudState);
      final pendingConfirmationContext = _captureConfirmationContext(
        cloudState,
      );
      final result = await _commandExecutor.send(
        command: cmd,
        availability: availability,
      );
      if (result.success) {
        _runBackgroundTask(
          locationService.recordDefaultVehicleLocation(),
          failureMessage: '控车后记录车辆位置失败',
        );
        final confirmed = await _waitForCommandConfirmation(
          cmd,
          pendingConfirmationContext.forTransport(result.transport),
        );
        if (!confirmed && mounted) {
          _showFailureSnack(_unconfirmedMessage(cmd));
        } else if (mounted && result.successMessage != null) {
          _showSuccessSnack(result.successMessage!);
        }
      }
      if (!result.success) {
        logService.operation(
          '控车失败: ${cmd.label}',
          detail:
              '渠道=${result.transport.name} 原因=${result.failureMessage ?? '未知'}',
          level: LogLevel.error,
        );
        if (mounted) {
          _showFailureSnack(result.failureMessage ?? '${cmd.label}失败');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activeControlId = null;
        });
      }
    }
  }

  bool _currentIsPowerOn(OfficialCloudState cloudState) {
    final availability = _controlAvailability(cloudState);
    final useBleState =
        availability.canUseBle &&
        cloudState.controlChannel != OfficialControlChannel.officialCloud;
    return useBleState
        ? connectionManager.latestBikeState?.isPowerOn ?? false
        : cloudState.selectedVehicle?.isPowerOn ?? false;
  }

  Future<bool> _waitForCommandConfirmation(
    CommandCode command,
    ControlCommandConfirmationContext context,
  ) async {
    if (!_needsStateConfirmation(command)) return true;

    final deadline = DateTime.now().add(_controlConfirmTimeout);
    while (mounted && !_disposed) {
      if (!_isConfirmationTargetActive(context)) return false;
      if (_isCommandConfirmed(command, context)) return true;
      if (DateTime.now().isAfter(deadline)) return false;

      await _refreshStateForConfirmation(command, context);
      if (!_isConfirmationTargetActive(context)) return false;
      if (_isCommandConfirmed(command, context)) return true;
      if (DateTime.now().isAfter(deadline)) return false;

      await Future<void>.delayed(_controlConfirmPollDelay);
    }
    return false;
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

  bool _isCommandConfirmed(
    CommandCode command,
    ControlCommandConfirmationContext context,
  ) {
    if (!_isConfirmationTargetActive(context)) return false;
    return switch (context.transport) {
      ControlCommandTransport.ble => _isBleCommandConfirmed(command),
      ControlCommandTransport.officialCloud => _isCloudCommandConfirmed(
        command,
      ),
      ControlCommandTransport.unavailable => false,
    };
  }

  bool _isBleCommandConfirmed(CommandCode command) {
    final state = connectionManager.latestBikeState;
    if (state == null) return false;
    return _matchesTargetState(
      command: command,
      isLocked: state.isLocked,
      isPowerOn: state.isPowerOn,
    );
  }

  bool _isCloudCommandConfirmed(CommandCode command) {
    final vehicle = officialCloudService.state.selectedVehicle;
    if (vehicle == null) return false;
    return _matchesTargetState(
      command: command,
      isLocked: vehicle.isLocked,
      isPowerOn: vehicle.isPowerOn,
    );
  }

  bool _matchesTargetState({
    required CommandCode command,
    required bool isLocked,
    required bool isPowerOn,
  }) {
    return switch (command) {
      CommandCode.lock => isLocked,
      CommandCode.unlock => !isLocked,
      CommandCode.powerOn => isPowerOn,
      CommandCode.powerOff => !isPowerOn,
      _ => true,
    };
  }

  Future<void> _refreshStateForConfirmation(
    CommandCode command,
    ControlCommandConfirmationContext context,
  ) async {
    try {
      if (!_isConfirmationTargetActive(context)) return;
      switch (context.transport) {
        case ControlCommandTransport.ble:
          await connectionManager.refreshBikeState();
        case ControlCommandTransport.officialCloud:
          await officialCloudService.refreshVehicles(
            silent: true,
            refreshReplicaDetails: false,
            force: true,
          );
        case ControlCommandTransport.unavailable:
          return;
      }
    } catch (e) {
      logService.operation(
        '控车后确认车辆状态失败: ${command.label}',
        detail: e.toString(),
        level: LogLevel.warning,
      );
    }
  }

  PendingControlCommandConfirmationContext _captureConfirmationContext(
    OfficialCloudState cloudState,
  ) {
    return PendingControlCommandConfirmationContext(
      defaultVehicleId: vehicleStore.defaultVehicleId,
      bleDeviceId: connectionManager.device?.remoteId.toString(),
      officialVehicleKey: cloudState.selectedVehicle?.key,
    );
  }

  bool _isConfirmationTargetActive(ControlCommandConfirmationContext context) {
    return _confirmationGuard.allows(
      context: context,
      currentDefaultVehicleId: vehicleStore.defaultVehicleId,
      currentBleDeviceId: connectionManager.device?.remoteId.toString(),
      currentOfficialVehicleKey:
          officialCloudService.state.selectedVehicle?.key,
    );
  }

  String _unconfirmedMessage(CommandCode command) {
    return switch (command) {
      CommandCode.powerOn => '已发送启动指令，但车辆未确认启动',
      CommandCode.powerOff => '已发送熄火指令，但车辆未确认关闭',
      CommandCode.lock => '已发送设防指令，但车辆未确认设防',
      CommandCode.unlock => '已发送解锁指令，但车辆未确认解锁',
      _ => '${command.label}已发送，但车辆状态未确认',
    };
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

  ControlChannelAvailability _controlAvailability(
    OfficialCloudState cloudState,
  ) {
    return ControlChannelResolver.resolve(
      cloudState: cloudState,
      bleReady: widget.connState == ble.ConnectionState.ready,
      defaultVehicleId: vehicleStore.defaultVehicleId,
      busy: _busy,
    );
  }

  void _showUnavailableSnack(String reason) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(reason), duration: const Duration(seconds: 2)),
    );
  }

  void _showSuccessSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _showFailureSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '查看日志',
          textColor: Colors.white,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LogPage()),
          ),
        ),
      ),
    );
  }

  _ControlAreaViewModel _createViewModel({
    required OfficialCloudState cloudState,
    required BikeState? bike,
  }) {
    final availability = _controlAvailability(cloudState);
    final cloudVehicle = cloudState.selectedVehicle;
    final useBleState =
        availability.canUseBle &&
        cloudState.controlChannel != OfficialControlChannel.officialCloud;
    final isLocked = useBleState
        ? bike?.isLocked ?? true
        : cloudVehicle?.isLocked ?? true;
    final isPowerOn = useBleState
        ? bike?.isPowerOn ?? false
        : cloudVehicle?.isPowerOn ?? false;
    return _ControlAreaViewModel(
      channel: availability.channel,
      canUseBle: availability.canUseBle,
      canUseCloud: availability.canUseCloud,
      enabled: availability.enabled,
      disabledReason: availability.disabledReason,
      vehicleName: cloudVehicle?.displayName,
      isLocked: isLocked,
      isPowerOn: isPowerOn,
      seatActive: _activeControlId == 'fixedSeat',
      powerLoading: _activeControlId == 'slidePower',
      lockActive: _activeControlId == 'fixedLock',
      findActive: _activeControlId == 'fixedFind',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
      stream: _combinedStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final cloudState = snapshot.data![0] as OfficialCloudState;
        final bike = snapshot.data![1] as BikeState?;
        final model = _createViewModel(cloudState: cloudState, bike: bike);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _ControlTipBar(
                enabled: model.enabled,
                isLocked: model.isLocked,
                isPowerOn: model.isPowerOn,
                channel: model.channel,
                canUseBle: model.canUseBle,
                canUseCloud: model.canUseCloud,
                vehicleName: model.vehicleName,
                disabledReason: model.visibleDisabledReason,
              ),
              const SizedBox(height: 12),
              _OfficialMainControlCard(
                powerLabel: model.powerLabel,
                powerHint: model.powerHint,
                powerIcon: model.powerIcon,
                reverseSlide: model.isPowerOn,
                powerLoading: model.powerLoading,
                powerLoadingLabel: model.powerLoadingLabel,
                powerColor: model.powerColor,
                enabled: model.enabled,
                disabledReason: model.disabledReason,
                onDisabledTap: () =>
                    _showUnavailableSnack(model.disabledReason),
                onPowerSlideComplete: () =>
                    _send(model.powerCommand, actionId: 'slidePower'),
                buttons: _buildButtons(model),
                onEditButtons: _editMainControls,
              ),
            ],
          ),
        );
      },
    );
  }
}
