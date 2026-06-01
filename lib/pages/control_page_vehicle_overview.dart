part of 'control_page.dart';

class _BikeImage extends StatelessWidget {
  final ble.ConnectionState connState;

  const _BikeImage({required this.connState});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BikeState?>(
      stream: connectionManager.bikeStateStream,
      initialData: connectionManager.latestBikeState,
      builder: (context, snapshot) {
        final bike = snapshot.data;
        final isConnected = connState == ble.ConnectionState.ready;
        return StreamBuilder<OfficialCloudState>(
          stream: officialCloudService.stateStream,
          initialData: officialCloudService.state,
          builder: (context, cloudSnapshot) {
            final cloudState = cloudSnapshot.data ?? officialCloudService.state;
            final cloudVehicle = cloudState.signedIn
                ? cloudState.selectedVehicle
                : null;
            final display = _vehicleStateDisplay(
              connState: connState,
              bike: bike,
              cloudVehicle: cloudVehicle,
            );
            final isPowerOn = isConnected && bike != null
                ? bike.isPowerOn
                : cloudVehicle?.isPowerOn ?? false;
            final isLocked = isConnected && bike != null
                ? bike.isLocked
                : cloudVehicle?.isLocked ?? true;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Container(
                height: 200,
                decoration: const BoxDecoration(color: Colors.transparent),
                child: Stack(
                  children: [
                    Positioned(
                      left: -18,
                      right: -18,
                      top: 10,
                      bottom: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.52),
                              const Color(0xFFE7EAF1).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: _VehicleVisual(
                        photoUrl: cloudVehicle?.carPhoto,
                        accent: display.colors.last,
                        isPowerOn: isPowerOn,
                        isLocked: isLocked,
                      ),
                    ),
                    Positioned(
                      left: 18,
                      top: 16,
                      child: _VehicleStateChip(display: display),
                    ),
                    Positioned(
                      right: 16,
                      top: 14,
                      child: _ManualModePill(enabled: isConnected),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 14,
                      child: _VehicleModelMeta(
                        connState: connState,
                        cloudVehicle: cloudVehicle,
                        isPowerOn: isPowerOn,
                        isLocked: isLocked,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _VehicleVisual extends StatelessWidget {
  final String? photoUrl;
  final Color accent;
  final bool isPowerOn;
  final bool isLocked;

  const _VehicleVisual({
    required this.photoUrl,
    required this.accent,
    required this.isPowerOn,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(ReplicaRadii.card),
      child: url.isEmpty
          ? _PaintedBikeVisual(
              accent: accent,
              isPowerOn: isPowerOn,
              isLocked: isLocked,
            )
          : Image.network(
              url,
              fit: BoxFit.contain,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: child,
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _PaintedBikeVisual(
                      accent: accent,
                      isPowerOn: isPowerOn,
                      isLocked: isLocked,
                    ),
                    Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                );
              },
              errorBuilder: (_, __, ___) => _PaintedBikeVisual(
                accent: accent,
                isPowerOn: isPowerOn,
                isLocked: isLocked,
              ),
            ),
    );
  }
}

class _PaintedBikeVisual extends StatelessWidget {
  final Color accent;
  final bool isPowerOn;
  final bool isLocked;

  const _PaintedBikeVisual({
    required this.accent,
    required this.isPowerOn,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BikeModelPainter(
        accent: accent,
        isPowerOn: isPowerOn,
        isLocked: isLocked,
      ),
    );
  }
}

class _VehicleStateDisplay {
  final String text;
  final IconData icon;
  final List<Color> colors;

  const _VehicleStateDisplay(this.text, this.icon, this.colors);
}

_VehicleStateDisplay _vehicleStateDisplay({
  required ble.ConnectionState connState,
  required BikeState? bike,
  required OfficialVehicle? cloudVehicle,
}) {
  final isConnected = connState == ble.ConnectionState.ready;
  if (isConnected && bike != null) {
    if (bike.isLocked && !bike.isPowerOn) {
      return _VehicleStateDisplay('已设防', Icons.lock_outline, [
        Colors.purple.shade200,
        Colors.blue.shade200,
      ]);
    }
    if (!bike.isLocked && bike.isPowerOn) {
      return _VehicleStateDisplay('已启动', Icons.power, [
        Colors.green.shade300,
        Colors.teal.shade300,
      ]);
    }
    if (!bike.isLocked) {
      return _VehicleStateDisplay('已解锁', Icons.lock_open, [
        Colors.orange.shade200,
        Colors.amber.shade300,
      ]);
    }
    return _VehicleStateDisplay('已上锁', Icons.lock_outline, [
      Colors.purple.shade200,
      Colors.blue.shade200,
    ]);
  }
  if (cloudVehicle != null) return _cloudVehicleStateDisplay(cloudVehicle);
  if (!isConnected) {
    return _VehicleStateDisplay('未连接', Icons.bluetooth_disabled, [
      Colors.grey.shade300,
      Colors.grey.shade400,
    ]);
  }
  return _VehicleStateDisplay('等待车辆状态', Icons.sync, [
    Colors.blue.shade200,
    Colors.blue.shade300,
  ]);
}

_VehicleStateDisplay _cloudVehicleStateDisplay(OfficialVehicle vehicle) {
  if (!vehicle.online) {
    return _VehicleStateDisplay('云端离线', Icons.cloud_off, [
      Colors.grey.shade300,
      Colors.grey.shade400,
    ]);
  }
  if (vehicle.isPowerOn) {
    return _VehicleStateDisplay('云端已启动', Icons.power, [
      Colors.green.shade300,
      Colors.teal.shade300,
    ]);
  }
  if (vehicle.isLocked) {
    return _VehicleStateDisplay('云端已设防', Icons.lock_outline, [
      Colors.purple.shade200,
      Colors.blue.shade200,
    ]);
  }
  return _VehicleStateDisplay('云端已解锁', Icons.lock_open, [
    Colors.orange.shade200,
    Colors.amber.shade300,
  ]);
}

class _VehicleStateChip extends StatelessWidget {
  final _VehicleStateDisplay display;

  const _VehicleStateChip({required this.display});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: display.colors),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(display.icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            display.text,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleModelMeta extends StatelessWidget {
  final ble.ConnectionState connState;
  final OfficialVehicle? cloudVehicle;
  final bool isPowerOn;
  final bool isLocked;

  const _VehicleModelMeta({
    required this.connState,
    required this.cloudVehicle,
    required this.isPowerOn,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final usesCloud =
        connState != ble.ConnectionState.ready && cloudVehicle != null;
    final state = connState == ble.ConnectionState.ready
        ? '${isPowerOn ? '电源开启' : '电源关闭'} · ${isLocked ? '防盗中' : '可骑行'}'
        : usesCloud
        ? '${cloudVehicle!.onlineLabel} · ${cloudVehicle!.defenceLabel} · ${cloudVehicle!.powerLabel}'
        : '连接车辆后显示实时状态';
    final title = cloudVehicle?.displayName ?? '智能电动车';
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          state,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ManualModePill extends StatefulWidget {
  final bool enabled;
  const _ManualModePill({required this.enabled});

  @override
  State<_ManualModePill> createState() => _ManualModePillState();
}

class _ManualModePillState extends State<_ManualModePill> {
  bool _manualMode = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _toggleManualMode() {
    if (!widget.enabled) return;
    setState(() => _manualMode = !_manualMode);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.enabled
          ? _manualMode
                ? '已开启手动模式，点按关闭'
                : '开启手动模式：禁用自动控车'
          : '请先连接车辆',
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.97 : 1,
        child: Material(
          color: _pressed
              ? _officialPressedBg
              : Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: widget.enabled ? _toggleManualMode : null,
            onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
            onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
            onTapCancel: widget.enabled ? () => _setPressed(false) : null,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '手动模式',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.enabled
                          ? AppColors.textSecondary
                          : AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _ManualModeToggle(
                    enabled: widget.enabled,
                    value: _manualMode,
                    onChanged: (_) => _toggleManualMode(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
