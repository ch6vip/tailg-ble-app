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
      AppSnack.error(context, message);
      return;
    }
    AppSnack.info(context, message);
  }

  String _unconfirmedMessage(CommandCode command) {
    return switch (command) {
      CommandCode.powerOn => '车辆未响应，请稍后重试',
      CommandCode.powerOff => '车辆未响应，请稍后重试',
      CommandCode.lock => '设防未完成，请稍后重试',
      CommandCode.unlock => '解防未完成，请稍后重试',
      _ => '车辆未响应，请稍后重试',
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

  Future<void> _enableProximityUnlock() async {
    if (_busy) return;
    final targetId =
        connectionManager.device?.remoteId.toString() ??
        vehicleStore.defaultVehicleId;
    if (targetId != null && targetId.trim().isNotEmpty) {
      proximityService.setTargetDevice(targetId);
    }
    if (manualModeService.enabled) {
      await manualModeService.setEnabled(false);
    }
    await proximityService.setEnabled(true);
    if (mounted) {
      _showSnack('感应解锁已开启', isError: false);
    }
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
        final connectionLabel = widget.connState.label;
        final connectionProtocol = _connectionProtocolLabel();
        final statusText = _officialTipText(
          connState: widget.connState,
          cloudVehicle: cloudVehicle,
          manualModeEnabled: _manualModeEnabled,
        );
        final topPadding = MediaQuery.paddingOf(context).top + 18;
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
              SizedBox(height: topPadding),
              ControlPageHero(
                batteryLevel: soc,
                rangeKm: range,
                vehicleName: cloudVehicle?.displayName ?? vehicleName,
                online: cloudVehicle?.online ?? true,
                connectionLabel: connectionLabel,
                connectionVariant: connectionProtocol,
                onVehicleSwitch: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OfficialCloudPage(),
                  ),
                ),
                onConnect: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AddVehiclePage(),
                  ),
                ),
                onDetail: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OfficialCloudPage(),
                  ),
                ),
                onMessage: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const VehicleMessagePage(),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              VehicleStage(
                batteryLevel: soc / 100.0,
                height: 200,
                imageUrl: cloudVehicle?.carPhoto,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _OfficialControlTip(
                  bleReady: _isBleReady,
                  statusText: statusText,
                  manualModeEnabled: _manualModeEnabled,
                  onToggleManualMode: _toggleManualMode,
                ),
              ),
              const SizedBox(height: 14),
              ControlCard(
                powered: isPowerOn,
                locked: isArmed,
                busy: _busy,
                onPowerOn: _sendPower,
                onFind: () => _sendCommand(CommandCode.find),
                onLock: () => _sendCommand(CommandCode.lock),
                onUnlock: () => _sendCommand(CommandCode.unlock),
                onOpenSeat: () => _sendCommand(CommandCode.openSeat),
                onProximityUnlock: () => unawaited(_enableProximityUnlock()),
                onQuickEdit: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const VehicleSettingsPage(),
                  ),
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

String _connectionProtocolLabel() {
  final protocol = connectionManager.protocol != ble.ProtocolType.unknown
      ? connectionManager.protocol
      : connectionManager.lastKnownProtocol;
  return switch (protocol) {
    ble.ProtocolType.qgj => 'QGJ',
    ble.ProtocolType.standard => 'BLE',
    ble.ProtocolType.unknown => '',
  };
}

String _officialTipText({
  required ble.ConnectionState connState,
  required OfficialVehicle? cloudVehicle,
  required bool manualModeEnabled,
}) {
  return switch (connState) {
    ble.ConnectionState.ready when manualModeEnabled => '手动模式控车',
    ble.ConnectionState.ready => '蓝牙已连接',
    ble.ConnectionState.connected => '蓝牙加载中',
    ble.ConnectionState.connecting => '蓝牙连接中',
    ble.ConnectionState.reconnecting => '蓝牙重连中',
    ble.ConnectionState.disconnected => cloudVehicle?.onlineLabel ?? '等待连接',
  };
}

class _OfficialControlTip extends StatelessWidget {
  const _OfficialControlTip({
    required this.bleReady,
    required this.statusText,
    required this.manualModeEnabled,
    required this.onToggleManualMode,
  });

  final bool bleReady;
  final String statusText;
  final bool manualModeEnabled;
  final VoidCallback onToggleManualMode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pillWidth = (constraints.maxWidth * 0.43).clamp(154.0, 184.0);
        return SizedBox(
          height: 60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 48,
                top: 10,
                child: Container(
                  width: pillWidth,
                  height: 38,
                  padding: const EdgeInsets.only(left: 44, right: 10),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: _StatusTextChip(statusText),
                ),
              ),
              Positioned(
                left: 0,
                top: -10,
                child: Image.asset(
                  'assets/official_tailg/ic_control_tip_mascot.png',
                  width: 62,
                  height: 62,
                  errorBuilder: (_, __, ___) => const CircleAvatar(
                    radius: 31,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.smart_toy_outlined),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 7,
                child: Tooltip(
                  message: manualModeEnabled ? '手动模式已开启' : '感应模式已开启',
                  child: AppPressable(
                    onTap: onToggleManualMode,
                    haptic: false,
                    semanticsLabel: manualModeEnabled ? '手动模式' : '感应模式',
                    semanticsButton: true,
                    semanticsEnabled: true,
                    semanticsToggled: !manualModeEnabled,
                    child: SizedBox(
                      width: 78,
                      height: AppTouchTargets.min,
                      child: Center(
                        child: Image.asset(
                          manualModeEnabled || !bleReady
                              ? 'assets/official_tailg/ic_control_mode_hand.png'
                              : 'assets/official_tailg/ic_control_mode_induction.png',
                          width: 74,
                          height: 38,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: 74,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(19),
                            ),
                            child: Icon(
                              manualModeEnabled || !bleReady
                                  ? Icons.touch_app
                                  : Icons.sensors,
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
      },
    );
  }
}

class _StatusTextChip extends StatelessWidget {
  const _StatusTextChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.officialTextMuted,
        letterSpacing: 0,
      ),
    );
  }
}
