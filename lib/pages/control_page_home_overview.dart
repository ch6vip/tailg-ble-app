part of 'control_page.dart';

class _HomeTopSection extends StatefulWidget {
  const _HomeTopSection();

  @override
  State<_HomeTopSection> createState() => _HomeTopSectionState();
}

class _HomeTopSectionState extends State<_HomeTopSection> {
  final _commandExecutor = ControlCommandExecutor(
    sendCloudCommand: officialCloudService.sendCommand,
  );
  bool _busy = false;
  bool _disposed = false;
  DateTime? _lastControlAt;

  StreamSubscription<OfficialCloudState>? _cloudSub;

  @override
  void initState() {
    super.initState();
    _cloudSub = officialCloudService.stateStream.listen((_) {
      if (mounted) setState(_onCloudStateChanged);
    });
  }

  void _onCloudStateChanged() {
    // Rebuild with latest cloud vehicle snapshot / sync time.
  }

  @override
  void dispose() {
    _disposed = true;
    _cloudSub?.cancel();
    super.dispose();
  }

  bool _currentIsPowerOn() {
    return officialCloudService.state.selectedVehicle?.isPowerOn ?? false;
  }

  ControlChannelAvailability _controlAvailability() {
    return ControlChannelResolver.resolve(
      cloudState: officialCloudService.state,
      busy: _busy,
    );
  }

  /// Official-style cross-control debounce (power/find/lock/seat share 1s).
  bool _isControlDebounced() {
    final now = DateTime.now();
    final last = _lastControlAt;
    if (last != null && now.difference(last) < _controlCommandDebounce) {
      return true;
    }
    _lastControlAt = now;
    return false;
  }

  Future<void> _sendPower() async {
    final isPowerOn = _currentIsPowerOn();
    final cmd = isPowerOn ? CommandCode.powerOff : CommandCode.powerOn;
    await _sendCommand(cmd);
  }

  Future<void> _sendCommand(CommandCode cmd) async {
    if (_busy) return;
    if (_isControlDebounced()) {
      _showSnack('请勿频繁操作', isError: true);
      return;
    }
    final policy = ControlCommandPolicy.evaluate(
      command: cmd,
      isPowerOn: _currentIsPowerOn(),
    );
    if (!policy.allowed) {
      _showSnack(policy.disabledReason ?? '${cmd.label}不可用', isError: true);
      return;
    }
    // 先检查可用性，再设置 _busy，避免 busy 状态影响 availability 判断
    final availability = _controlAvailability();
    if (!availability.enabled) {
      _showSnack(availability.disabledReason, isError: true);
      return;
    }
    setState(() {
      _busy = true;
    });
    HapticFeedback.mediumImpact();
    try {
      // Official: animation first (event 112), then delayed publish.
      await Future<void>.delayed(_controlCommandSendDelay);
      if (!mounted || _disposed) return;

      final result = await _commandExecutor.send(command: cmd);
      if (result.success) {
        _runBackgroundTask(
          locationService.recordDefaultVehicleLocation(),
          failureMessage: '控车后记录车辆位置失败',
        );
        final confirmed = await _waitForCommandConfirmation(cmd);
        if (!mounted) return;
        if (!confirmed) {
          // Align with official BaseEvent(128) recovery: force a status pull
          // so the slide rest position matches the real vehicle ACC/defence.
          await _refreshStateForConfirmation();
          if (!mounted) return;
          _showSnack(_unconfirmedMessage(cmd), isError: true);
        } else {
          _showSnack(result.successMessage ?? '${cmd.label}成功', isError: false);
        }
      } else {
        logService.operation(
          '控车失败: ${cmd.label}',
          detail:
              '渠道=${result.transport.name} 原因=${result.failureMessage ?? '未知'}',
          level: LogLevel.error,
        );
        await _refreshStateForConfirmation();
        if (mounted) {
          _showSnack(
            _failureMessage(cmd, result.failureMessage),
            isError: true,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
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

  String _statusText(OfficialVehicle? cloudVehicle) {
    if (cloudVehicle == null) return '等待连接';
    final online = cloudVehicle.onlineLabel;
    final sync = formatRelativeSyncText(
      officialCloudService.lastVehiclesRefreshAt,
    );
    return '$online · $sync';
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
        '控车后确认车辆状态失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloudVehicle = officialCloudService.state.selectedVehicle;
    final int? rawPercent = cloudVehicle?.electricQuantity;
    final soc = _normalizePercent(rawPercent) ?? 0;
    final cloudMileage = cloudVehicle?.mileage;
    final range = cloudMileage != null
        ? cloudMileage.round()
        : (soc * _kmPerPercent).round();
    final bool? isArmed = cloudVehicle?.isLocked;
    final bool isPowerOn = cloudVehicle?.isPowerOn ?? false;
    final vehicleName = vehicleStore.defaultVehicle?.displayName ?? '我的车辆';
    final statusText = _statusText(cloudVehicle);
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
            connectionLabel: _busy ? '同步中' : '官方云端',
            connectionVariant: '',
            onVehicleSwitch: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const OfficialCloudPage(),
              ),
            ),
            onConnect: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AddVehiclePage()),
            ),
            onBatteryTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BatteryDetailsPage(),
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
            child: _OfficialControlTip(statusText: statusText),
          ),
          const SizedBox(height: 5),
          ControlCard(
            powered: isPowerOn,
            locked: isArmed,
            busy: _busy,
            onPowerOn: _sendPower,
            onFind: () => _sendCommand(CommandCode.find),
            onLock: () => _sendCommand(CommandCode.lock),
            onUnlock: () => _sendCommand(CommandCode.unlock),
            onOpenSeat: () => _sendCommand(CommandCode.openSeat),
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
  }
}

class _OfficialControlTip extends StatelessWidget {
  const _OfficialControlTip({required this.statusText});

  final String statusText;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pillWidth = (constraints.maxWidth * 0.58).clamp(180.0, 260.0);
        return SizedBox(
          height: 50,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 48,
                top: 2,
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
                top: -20,
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
