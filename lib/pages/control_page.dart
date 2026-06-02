import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart';
import '../models/official_vehicle.dart';
import '../models/vehicle_profile.dart';
import '../services/control_channel_resolver.dart';
import '../services/control_command_executor.dart';
import '../services/control_command_policy.dart';
import '../services/control_command_result.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../services/replica_feature_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/slide_to_action.dart';
import 'garage_page.dart';
import 'location_page.dart';
import 'log_page.dart';
import 'official_cloud_page.dart';
import 'official_replica_pages.dart';
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

const _pageBg = ReplicaColors.pageBg;
const _kmPerPercent = 0.65;
const _phoneControlItemBg = Color(0xFFF7F8FA);
const _phoneControlPrimary = ReplicaColors.blue;
const _phoneControlPrimaryPressed = Color(0x225596FF);
const _phoneControlRadius = 8.0;
const _officialPressedBg = Color(0xFFE5E5E5);
const _controlConfirmTimeout = Duration(seconds: 8);
const _controlConfirmPollDelay = Duration(milliseconds: 800);
const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(ReplicaRadii.card)),
  boxShadow: AppShadows.cardShadow,
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<ble.ConnectionState>(
      stream: connectionManager.stateStream,
      initialData: connectionManager.state,
      builder: (context, snapshot) {
        final connState = snapshot.data ?? ble.ConnectionState.disconnected;
        return StreamBuilder<List<VehicleProfile>>(
          stream: vehicleStore.vehiclesStream,
          initialData: vehicleStore.vehicles,
          builder: (context, vehicleSnapshot) {
            final vehicles = vehicleSnapshot.data ?? const <VehicleProfile>[];
            return StreamBuilder<OfficialCloudState>(
              stream: officialCloudService.stateStream,
              initialData: officialCloudService.state,
              builder: (context, cloudSnapshot) {
                final cloudState =
                    cloudSnapshot.data ?? officialCloudService.state;
                final hasLocalVehicle =
                    vehicles.isNotEmpty || vehicleStore.defaultVehicle != null;
                final hasCloudVehicle =
                    cloudState.signedIn && cloudState.selectedVehicle != null;
                final hasTransientDevice =
                    connectionManager.device != null ||
                    connState != ble.ConnectionState.disconnected;
                final showUnboundHome =
                    !hasLocalVehicle && !hasCloudVehicle && !hasTransientDevice;

                return Scaffold(
                  backgroundColor: _pageBg,
                  body: SafeArea(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(
                        bottom: AppNav.contentBottomPadding,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
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
                      ),
                    ),
                  ),
                );
              },
            );
          },
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
  final _QuickControlSpec firstQuick;
  final _QuickControlSpec secondQuick;
  final bool firstQuickActive;
  final bool secondQuickActive;
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
    required this.firstQuick,
    required this.secondQuick,
    required this.firstQuickActive,
    required this.secondQuickActive,
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

  bool quickEnabled(_QuickControlSpec spec) {
    final command = spec.command;
    if (command == null) return true;
    return commandEnabled(command);
  }

  String quickDisabledReason(_QuickControlSpec spec) {
    final command = spec.command;
    if (command == null) return disabledReason;
    return commandDisabledReason(command);
  }

  String get powerLabel => isPowerOn ? '熄火' : '启动';

  String get powerHint => isPowerOn ? '左滑关闭' : '右滑启动';

  String get powerLoadingLabel => isPowerOn ? '正在熄火' : '正在启动';

  IconData get powerIcon =>
      isPowerOn ? Icons.power_off : Icons.power_settings_new;

  Color get powerColor => isPowerOn ? AppColors.danger : _phoneControlPrimary;

  CommandCode get powerCommand =>
      isPowerOn ? CommandCode.powerOff : CommandCode.powerOn;

  String get lockLabel => isLocked ? '解锁' : '设防';

  String get lockStatus => isLocked ? '当前设防' : '当前解锁';

  IconData get lockIcon => isLocked ? Icons.lock_open : Icons.lock_outline;

  CommandCode get lockCommand =>
      isLocked ? CommandCode.unlock : CommandCode.lock;

  bool get findEnabled => commandEnabled(CommandCode.find);

  String get findDisabledReason => commandDisabledReason(CommandCode.find);
}

class _ControlAreaState extends State<_ControlArea> {
  final _replicaStore = ReplicaFeatureStore();
  final _commandExecutor = ControlCommandExecutor(
    sendBleCommand: connectionManager.sendCommand,
    sendCloudCommand: officialCloudService.sendCommand,
  );
  QuickControlConfig _quickConfig = const QuickControlConfig();
  bool _busy = false;
  String? _activeControlId;

  @override
  void initState() {
    super.initState();
    _loadQuickConfig();
  }

  Future<void> _loadQuickConfig() async {
    final config = await _replicaStore.loadQuickControlConfig();
    if (!mounted) return;
    setState(() => _quickConfig = config);
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
          result.transport,
        );
        if (!confirmed && mounted) {
          _showFailureSnack(_unconfirmedMessage(cmd));
        } else if (mounted && result.successMessage != null) {
          _showSuccessSnack(result.successMessage!);
        }
      }
      if (!result.success && mounted) {
        _showFailureSnack(result.failureMessage ?? '${cmd.label}失败');
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
    ControlCommandTransport transport,
  ) async {
    if (!_needsStateConfirmation(command)) return true;

    final deadline = DateTime.now().add(_controlConfirmTimeout);
    while (mounted) {
      if (_isCommandConfirmed(command, transport)) return true;
      if (DateTime.now().isAfter(deadline)) return false;

      await _refreshStateForConfirmation(command, transport);
      if (_isCommandConfirmed(command, transport)) return true;
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
    ControlCommandTransport transport,
  ) {
    return switch (transport) {
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
    ControlCommandTransport transport,
  ) async {
    try {
      switch (transport) {
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

  Future<void> _runQuickAction(
    _QuickControlSpec spec,
    _ControlAreaViewModel model,
  ) async {
    if (spec.command != null) {
      final disabledReason = model.quickEnabled(spec)
          ? null
          : model.quickDisabledReason(spec);
      if (disabledReason != null) {
        _showUnavailableSnack(disabledReason);
        return;
      }
      await _send(spec.command!, actionId: 'quick:${spec.id}');
      return;
    }
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => spec.pageBuilder!(context)),
    );
  }

  Future<void> _editQuickControls() async {
    final next = await Navigator.push<QuickControlConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => QuickControlEditPage(initialConfig: _quickConfig),
      ),
    );
    if (next == null) return;
    await _replicaStore.saveQuickControlConfig(next);
    if (!mounted) return;
    setState(() => _quickConfig = next);
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
    final firstQuick = _quickControlSpec(_quickConfig.firstActionId);
    final secondQuick = _quickControlSpec(_quickConfig.secondActionId);

    return _ControlAreaViewModel(
      channel: availability.channel,
      canUseBle: availability.canUseBle,
      canUseCloud: availability.canUseCloud,
      enabled: availability.enabled,
      disabledReason: availability.disabledReason,
      vehicleName: cloudVehicle?.displayName,
      isLocked: isLocked,
      isPowerOn: isPowerOn,
      firstQuick: firstQuick,
      secondQuick: secondQuick,
      firstQuickActive: _activeControlId == 'quick:${firstQuick.id}',
      secondQuickActive: _activeControlId == 'quick:${secondQuick.id}',
      powerLoading: _activeControlId == 'slidePower',
      lockActive: _activeControlId == 'fixedLock',
      findActive: _activeControlId == 'fixedFind',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OfficialCloudState>(
      stream: officialCloudService.stateStream,
      initialData: officialCloudService.state,
      builder: (context, cloudSnapshot) {
        final cloudState = cloudSnapshot.data ?? officialCloudService.state;

        return StreamBuilder<BikeState?>(
          stream: connectionManager.bikeStateStream,
          initialData: connectionManager.latestBikeState,
          builder: (context, snapshot) {
            final model = _createViewModel(
              cloudState: cloudState,
              bike: snapshot.data,
            );
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final extraHeight = ((textScale - 1.0).clamp(0.0, 0.3) * 80)
                .toDouble();
            final compactWidth = MediaQuery.sizeOf(context).width < 360;

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
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 204 + extraHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: compactWidth ? 82 : 90,
                          child: _OfficialQuickControlCard(
                            firstQuick: model.firstQuick,
                            secondQuick: model.secondQuick,
                            firstActive: model.firstQuickActive,
                            secondActive: model.secondQuickActive,
                            firstEnabled: model.quickEnabled(model.firstQuick),
                            firstDisabledReason: model.quickDisabledReason(
                              model.firstQuick,
                            ),
                            secondEnabled: model.quickEnabled(
                              model.secondQuick,
                            ),
                            secondDisabledReason: model.quickDisabledReason(
                              model.secondQuick,
                            ),
                            onFirstTap: () =>
                                _runQuickAction(model.firstQuick, model),
                            onSecondTap: () =>
                                _runQuickAction(model.secondQuick, model),
                            onEditTap: _editQuickControls,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _OfficialMainControlCard(
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
                            onPowerSlideComplete: () => _send(
                              model.powerCommand,
                              actionId: 'slidePower',
                            ),
                            lockIcon: model.lockIcon,
                            lockLabel: model.lockLabel,
                            lockStatus: model.lockStatus,
                            lockActive: model.lockActive,
                            onLockTap: () =>
                                _send(model.lockCommand, actionId: 'fixedLock'),
                            findActive: model.findActive,
                            findEnabled: model.findEnabled,
                            findDisabledReason: model.findDisabledReason,
                            onFindTap: () =>
                                _send(CommandCode.find, actionId: 'fixedFind'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
