part of 'control_page.dart';

/// v8 home top section: Hero + vehicle stage + status chips + working control
/// card + connection tip bar.
///
/// Owns all control execution (power on/off, seat, proximity toggle) that was
/// previously in the old [_ControlArea].  Replaces the old three-section
/// header/status/statusline + SlideToAction layout with the v8 Ninebot-inspired
/// design.
class _HomeTopSection extends StatefulWidget {
  final ble.ConnectionState connState;

  const _HomeTopSection({required this.connState});

  @override
  State<_HomeTopSection> createState() => _HomeTopSectionState();
}

class _HomeTopSectionState extends State<_HomeTopSection> {
  // ── Control execution pipeline (migrated from _ControlAreaState) ───

  final _commandExecutor = ControlCommandExecutor(
    sendBleCommand: connectionManager.sendCommand,
    sendCloudCommand: officialCloudService.sendCommand,
  );
  final _confirmationGuard = const ControlCommandConfirmationGuard();
  bool _busy = false;
  bool _disposed = false;

  // ── Proximity / manual-mode toggle state ──────────────────────────

  bool _proximityEnabled = false;
  StreamSubscription<bool>? _manualModeSub;

  // ── Lifecycle ──────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _proximityEnabled = manualModeService.enabled;
    _manualModeSub = manualModeService.enabledStream.listen((v) {
      if (mounted) setState(() => _proximityEnabled = v);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _manualModeSub?.cancel();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────

  bool get _isBleReady => widget.connState == ble.ConnectionState.ready;
  bool get _isReconnecting =>
      widget.connState == ble.ConnectionState.reconnecting;

  bool _currentIsPowerOn() {
    final availability = _controlAvailability();
    final useBleState =
        availability.canUseBle &&
        officialCloudService.state.controlChannel !=
            OfficialControlChannel.officialCloud;
    return useBleState
        ? connectionManager.latestBikeState?.isPowerOn ?? false
        : officialCloudService.state.selectedVehicle?.isPowerOn ?? false;
  }

  ControlChannelAvailability _controlAvailability() {
    return ControlChannelResolver.resolve(
      cloudState: officialCloudService.state,
      bleReady: _isBleReady,
      defaultVehicleId: vehicleStore.defaultVehicleId,
      busy: _busy,
    );
  }

  // ── Control execution ──────────────────────────────────────────────

  Future<void> _sendPower() async {
    final isPowerOn = _currentIsPowerOn();
    final cmd = isPowerOn ? CommandCode.powerOff : CommandCode.powerOn;
    await _sendCommand(cmd);
  }

  Future<void> _sendSeat() async {
    await _sendCommand(CommandCode.openSeat);
  }

  Future<void> _sendCommand(CommandCode cmd) async {
    if (_busy) return;
    final policy = ControlCommandPolicy.evaluate(
      command: cmd,
      isPowerOn: _currentIsPowerOn(),
    );
    if (!policy.allowed) {
      _showSnack(policy.disabledReason ?? '${cmd.label}不可用', isError: true);
      return;
    }
    setState(() {
      _busy = true;
    });
    HapticFeedback.mediumImpact();
    try {
      final availability = _controlAvailability();
      final pending = PendingControlCommandConfirmationContext(
        defaultVehicleId: vehicleStore.defaultVehicleId,
        bleDeviceId: connectionManager.device?.remoteId.toString(),
        officialVehicleKey: officialCloudService.state.selectedVehicle?.key,
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
          pending.forTransport(result.transport),
        );
        if (!confirmed && mounted) {
          _showSnack(_unconfirmedMessage(cmd), isError: true);
        } else if (mounted && result.successMessage != null) {
          _showSnack(result.successMessage!, isError: false);
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
          _showSnack(result.failureMessage ?? '${cmd.label}失败', isError: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
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

  void _showSnack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : null,
        duration: Duration(seconds: isError ? 3 : 2),
        action: isError
            ? SnackBarAction(
                label: '查看日志',
                textColor: Colors.white,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LogPage()),
                ),
              )
            : null,
      ),
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

  // ── Command confirmation ───────────────────────────────────────────

  bool _needsStateConfirmation(CommandCode command) {
    return switch (command) {
      CommandCode.lock ||
      CommandCode.unlock ||
      CommandCode.powerOn ||
      CommandCode.powerOff => true,
      _ => false,
    };
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

  bool _isConfirmationTargetActive(ControlCommandConfirmationContext context) {
    return _confirmationGuard.allows(
      context: context,
      currentDefaultVehicleId: vehicleStore.defaultVehicleId,
      currentBleDeviceId: connectionManager.device?.remoteId.toString(),
      currentOfficialVehicleKey:
          officialCloudService.state.selectedVehicle?.key,
    );
  }

  // ── Proximity toggle ───────────────────────────────────────────────

  void _toggleProximity(bool value) {
    HapticFeedback.selectionClick();
    manualModeService.setEnabled(value);
    // The _manualModeSub listener syncs _proximityEnabled automatically.
  }

  // ── Super Dashboard / Rider Management placeholders ────────────────

  void _openSuperDashboard() {
    HapticFeedback.selectionClick();
    // Navigate to a future dashboard page.
    _showSnack('超级仪表功能开发中', isError: false);
  }

  void _openRiderManagement() {
    HapticFeedback.selectionClick();
    // Navigate to ShareBikePage or a dedicated rider-management page.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShareBikePage()),
    );
  }

  // ── UI: _ControlTipBar helpers ─────────────────────────────────────

  String get _tipEffective {
    final availability = _controlAvailability();
    return switch (officialCloudService.state.controlChannel) {
      OfficialControlChannel.ble => 'BLE',
      OfficialControlChannel.officialCloud => '云端',
      OfficialControlChannel.automatic =>
        availability.canUseBle
            ? 'BLE'
            : availability.canUseCloud
            ? '云端'
            : '待连接',
    };
  }

  String get _tipStatus {
    final availability = _controlAvailability();
    if (!availability.enabled) {
      return availability.disabledReason.isNotEmpty
          ? availability.disabledReason
          : '请连接车辆后控车';
    }
    final isLocked = _currentIsPowerOn()
        ? (connectionManager.latestBikeState?.isLocked ??
              officialCloudService.state.selectedVehicle?.isLocked ??
              true)
        : true;
    final isPowerOn = _currentIsPowerOn();
    return '${isPowerOn ? '已启动' : '未启动'} · ${isLocked ? '已设防' : '未设防'}';
  }

  Color get _tipEffectiveColor {
    return switch (_tipEffective) {
      'BLE' => AppColors.success,
      '云端' => AppColors.primary,
      _ => AppColors.textTertiary,
    };
  }

  IconData get _tipEffectiveIcon {
    return switch (_tipEffective) {
      'BLE' => Icons.bluetooth_connected,
      '云端' => Icons.cloud_done_outlined,
      _ => Icons.link_off,
    };
  }

  String? get _tipVehicleName {
    final availability = _controlAvailability();
    return availability.canUseCloud
        ? officialCloudService.state.selectedVehicle?.displayName
        : null;
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      stream: connectionManager.bikeStateStream,
      initialData: connectionManager.latestBikeState,
      builder: (context, snapshot) {
        final bike = snapshot.data;
        final cloudVehicle = officialCloudService.state.selectedVehicle;
        // Prefer BLE battery, fallback to cloud electricQuantity
        final rawPercent =
            bike?.batteryPercent ?? cloudVehicle?.electricQuantity;
        final soc = _normalizePercent(rawPercent) ?? 0;
        // Prefer cloud mileage, fallback to estimated range
        final cloudMileage = cloudVehicle?.mileage;
        final range = cloudMileage != null
            ? cloudMileage.round()
            : (soc * _kmPerPercent).round();
        // Prefer BLE lock/power, fallback to cloud
        final isArmed = bike?.isLocked ?? cloudVehicle?.isLocked;
        final isPowerOn = bike?.isPowerOn ?? cloudVehicle?.isPowerOn ?? false;
        final vehicleName =
            connectionManager.device?.platformName ??
            vehicleStore.defaultVehicle?.displayName ??
            '我的车辆';
        final connectionLabel = _isBleReady
            ? '蓝牙已连接'
            : _isReconnecting
            ? '重连中'
            : null;

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment(0, 0.46),
              colors: [AppColors.pageBgTop, AppColors.pageBgBot],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // ── v8 Hero ──
              ControlPageHero(
                batteryLevel: soc,
                rangeKm: range,
                healthLabel: rawPercent != null
                    ? (soc >= 60
                          ? '健康良好'
                          : soc >= 30
                          ? '建议充电'
                          : '电量过低')
                    : '等待数据',
                vehicleName: cloudVehicle?.displayName ?? vehicleName,
                connectionLabel: connectionLabel,
                onBatteryTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BatteryDetailsPage()),
                ),
                onNotification: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VehicleMessagePage()),
                ),
              ),
              const SizedBox(height: 10),
              // ── v8 Vehicle stage SVG ──
              VehicleStage(batteryLevel: soc / 100.0, height: 180),
              // ── v8 Status chips row ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    StatusBadge(
                      type: isArmed == null
                          ? StatusBadgeType.idle
                          : isArmed!
                          ? StatusBadgeType.armed
                          : StatusBadgeType.idle,
                      label: isArmed == null ? '未知' : null,
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      type: isPowerOn
                          ? StatusBadgeType.online
                          : StatusBadgeType.idle,
                      label: isPowerOn ? '已通电' : '未通电',
                    ),
                    const SizedBox(width: 8),
                    if (_isBleReady)
                      const StatusBadge(type: StatusBadgeType.ble),
                    if (_isReconnecting)
                      const StatusBadge(
                        type: StatusBadgeType.offline,
                        label: '重连中',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // ── v8 Floating control card (wired!) ──
              ControlCard(
                powered: isPowerOn,
                proximityEnabled: _proximityEnabled,
                busy: _busy,
                onSeatOpen: _sendSeat,
                onPowerOn: _sendPower,
                onMore: () => showAllFunctionsSheet(
                  context,
                  onControlCommand: _sendCommand,
                ),
                onToggleProximity: _toggleProximity,
                onRiderManagement: _openRiderManagement,
                onSuperDashboard: _openSuperDashboard,
              ),
              const SizedBox(height: 14),
              // ── Connection tip bar (migrated from _ControlArea) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.cardShadow,
                      ),
                      child: const Icon(
                        Icons.smart_toy_outlined,
                        size: AppIconSizes.md,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(30),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OfficialCloudPage(),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: AppColors.surfaceContainerLow,
                              boxShadow: AppShadows.elevation1,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 24,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _tipEffectiveColor.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _tipEffectiveIcon,
                                        size: 13,
                                        color: _tipEffectiveColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        _tipEffective,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: _tipEffectiveColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _tipStatus,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.sectionLabelStrong,
                                  ),
                                ),
                                if (_tipVehicleName != null) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _tipVehicleName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.caption,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ManualModePill(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
