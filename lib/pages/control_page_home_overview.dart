part of 'control_page.dart';

/// Official home top section: hero, vehicle stage, status tip, and control
/// card.
///
/// Owns the homepage control execution surface: power, find, lock, and the
/// official mode toggle.
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

  // ── Manual-mode toggle state ──────────────────────────────────────

  bool _manualModeEnabled = false;
  StreamSubscription<bool>? _manualModeSub;

  // ── Lifecycle ──────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _manualModeEnabled = manualModeService.enabled;
    _manualModeSub = manualModeService.enabledStream.listen((v) {
      if (mounted) setState(() => _manualModeEnabled = v);
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
    if (isError) {
      AppSnack.error(
        context,
        message,
        actionLabel: '查看日志',
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const LogPage()),
        ),
      );
      return;
    }
    AppSnack.info(context, message);
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

  void _toggleManualMode() {
    manualModeService.setEnabled(!_manualModeEnabled);
    HapticFeedback.selectionClick();
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BikeState?>(
      stream: connectionManager.bikeStateStream,
      initialData: connectionManager.latestBikeState,
      builder: (context, snapshot) {
        final BikeState? bike = snapshot.data;
        final cloudVehicle = officialCloudService.state.selectedVehicle;
        // Prefer BLE battery, fallback to cloud electricQuantity
        final int? rawPercent =
            bike?.batteryPercent ?? cloudVehicle?.electricQuantity;
        final soc = _normalizePercent(rawPercent) ?? 0;
        // Prefer cloud mileage, fallback to estimated range
        final cloudMileage = cloudVehicle?.mileage;
        final range = cloudMileage != null
            ? cloudMileage.round()
            : (soc * _kmPerPercent).round();
        // Prefer BLE lock/power, fallback to cloud
        final bool? isArmed = bike?.isLocked ?? cloudVehicle?.isLocked;
        final bool isPowerOn =
            bike?.isPowerOn ?? cloudVehicle?.isPowerOn ?? false;
        final vehicleName =
            connectionManager.device?.platformName ??
            vehicleStore.defaultVehicle?.displayName ??
            '我的车辆';
        final connectionLabel = _isBleReady
            ? '蓝牙已连接'
            : _isReconnecting
            ? '重连中'
            : null;
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.officialPageBg,
            image: DecorationImage(
              image: AssetImage('assets/official_tailg/iv_bg_control.png'),
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
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
                  MaterialPageRoute<void>(
                    builder: (_) => const BatteryDetailsPage(),
                  ),
                ),
                onNotification: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const VehicleMessagePage(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              VehicleStage(batteryLevel: soc / 100.0, height: 225),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _OfficialControlTip(
                  isArmed: isArmed,
                  isPowerOn: isPowerOn,
                  bleReady: _isBleReady,
                  reconnecting: _isReconnecting,
                  manualModeEnabled: _manualModeEnabled,
                  onToggleManualMode: _toggleManualMode,
                ),
              ),
              const SizedBox(height: 14),
              ControlCard(
                powered: isPowerOn,
                busy: _busy,
                onPowerOn: _sendPower,
                onFind: () => _sendCommand(CommandCode.find),
                onLock: () => _sendCommand(CommandCode.lock),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _OfficialControlTip extends StatelessWidget {
  const _OfficialControlTip({
    required this.isArmed,
    required this.isPowerOn,
    required this.bleReady,
    required this.reconnecting,
    required this.manualModeEnabled,
    required this.onToggleManualMode,
  });

  final bool? isArmed;
  final bool isPowerOn;
  final bool bleReady;
  final bool reconnecting;
  final bool manualModeEnabled;
  final VoidCallback onToggleManualMode;

  @override
  Widget build(BuildContext context) {
    final statusText = [
      isPowerOn ? '已启动' : '未启动',
      isArmed == null
          ? '设防未知'
          : isArmed!
          ? '已设防'
          : '未设防',
      if (reconnecting) '重连中' else if (bleReady) '蓝牙已连接',
    ].join('  ');

    return SizedBox(
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 40,
            right: 54,
            top: 10,
            child: Container(
              height: 38,
              padding: const EdgeInsets.only(left: 42, right: 12),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.officialTextMuted,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: -10,
            child: Image.asset(
              'assets/official_tailg/ic_control_tip_mascot.png',
              width: 60,
              height: 60,
              errorBuilder: (_, __, ___) => const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Icon(Icons.smart_toy_outlined),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 8,
            child: Tooltip(
              message: manualModeEnabled
                  ? '已开启手动模式：点按关闭'
                  : '开启手动模式：禁用感应解锁/自动连接',
              child: AppPressable(
                onTap: onToggleManualMode,
                haptic: false,
                semanticsLabel: '手动模式',
                semanticsButton: true,
                semanticsEnabled: true,
                semanticsToggled: manualModeEnabled,
                child: SizedBox(
                  width: 66,
                  height: 44,
                  child: Center(
                    child: Image.asset(
                      manualModeEnabled || !bleReady
                          ? 'assets/official_tailg/ic_control_mode_hand.png'
                          : 'assets/official_tailg/ic_control_mode_induction.png',
                      width: 54,
                      height: 42,
                      errorBuilder: (_, __, ___) => Container(
                        width: 54,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(21),
                        ),
                        child: Icon(
                          manualModeEnabled || !bleReady
                              ? Icons.touch_app
                              : Icons.bluetooth_connected,
                          size: 20,
                          color: AppColors.brandRed,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
