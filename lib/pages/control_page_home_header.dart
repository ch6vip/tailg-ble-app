part of 'control_page.dart';

class _Header extends StatelessWidget {
  final ble.ConnectionState connState;
  const _Header({required this.connState});

  @override
  Widget build(BuildContext context) {
    final statusText = switch (connState) {
      ble.ConnectionState.disconnected => '离线',
      ble.ConnectionState.connecting => '连接中',
      ble.ConnectionState.reconnecting => '重连中',
      ble.ConnectionState.connected => '已连接',
      ble.ConnectionState.ready => '在线',
    };
    final statusColor = switch (connState) {
      ble.ConnectionState.ready => Colors.green,
      ble.ConnectionState.reconnecting => Colors.orange,
      _ => Colors.grey,
    };
    final isConnecting =
        connState == ble.ConnectionState.connecting ||
        connState == ble.ConnectionState.reconnecting;

    return StreamBuilder<List<VehicleProfile>>(
      stream: vehicleStore.vehiclesStream,
      initialData: vehicleStore.vehicles,
      builder: (context, snapshot) {
        final defaultVehicle = vehicleStore.defaultVehicle;
        return StreamBuilder<OfficialCloudState>(
          stream: officialCloudService.stateStream,
          initialData: officialCloudService.state,
          builder: (context, cloudSnapshot) {
            final cloudState = cloudSnapshot.data ?? officialCloudService.state;
            final cloudVehicle = cloudState.signedIn
                ? cloudState.selectedVehicle
                : null;
            final deviceName = connectionManager.device?.platformName;
            final hasDeviceName = deviceName != null && deviceName.isNotEmpty;
            final usesCloudIdentity =
                defaultVehicle == null &&
                !hasDeviceName &&
                cloudVehicle != null;
            final useCloudStatus =
                usesCloudIdentity &&
                connState == ble.ConnectionState.disconnected;
            final displayName =
                defaultVehicle?.displayName ??
                (hasDeviceName
                    ? deviceName
                    : cloudVehicle?.displayName ??
                          (connState == ble.ConnectionState.disconnected
                              ? '未绑定车辆'
                              : '当前车辆'));
            final effectiveStatusText = useCloudStatus
                ? cloudVehicle.online
                      ? '云端在线'
                      : '云端离线'
                : statusText;
            final effectiveStatusColor = useCloudStatus
                ? cloudVehicle.online
                      ? Colors.green
                      : Colors.grey
                : statusColor;
            final statusIcon = useCloudStatus
                ? cloudVehicle.online
                      ? Icons.cloud_done
                      : Icons.cloud_off
                : connState == ble.ConnectionState.ready
                ? Icons.bluetooth_connected
                : Icons.bluetooth_disabled;
            final subtitle = cloudVehicle != null
                ? '${cloudVehicle.defenceLabel} · ${cloudVehicle.powerLabel}'
                : hasDeviceName
                ? 'BLE $deviceName'
                : defaultVehicle?.id ?? '点按选择或绑定车辆';

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => usesCloudIdentity
                                    ? const OfficialCloudPage()
                                    : const GaragePage(),
                              ),
                            ),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 23,
                                          fontWeight: FontWeight.w800,
                                          color: ReplicaColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: ReplicaColors.subtle,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: ReplicaColors.subtle,
                                ),
                                const SizedBox(width: 8),
                                Semantics(
                                  label: '车辆连接状态：$effectiveStatusText',
                                  liveRegion: true,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: effectiveStatusColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          statusIcon,
                                          size: 12,
                                          color: effectiveStatusColor,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          effectiveStatusText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: effectiveStatusColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _HeaderIconAction(
                          icon: Icons.article_outlined,
                          tooltip: '车辆详情',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VehicleSettingsPage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _HeaderIconAction(
                          icon: isConnecting
                              ? Icons.sync
                              : statusIcon == Icons.cloud_done
                              ? Icons.notifications_none
                              : statusIcon,
                          color: isConnecting
                              ? AppColors.warning
                              : statusIcon == Icons.cloud_done
                              ? ReplicaColors.ink
                              : effectiveStatusColor,
                          tooltip: '消息中心',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VehicleMessagePage(),
                            ),
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

class _HeaderIconAction extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconAction({
    required this.icon,
    this.color = ReplicaColors.ink,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HeaderIconAction> createState() => _HeaderIconActionState();
}

class _HeaderIconActionState extends State<_HeaderIconAction> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.96 : 1,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              _setPressed(false);
              HapticFeedback.selectionClick();
              widget.onTap();
            },
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _pressed
                    ? _officialPressedBg
                    : Colors.white.withValues(alpha: 0.72),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, size: 22, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}
