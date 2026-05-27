import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart';
import '../theme/app_colors.dart';
import '../widgets/slide_to_action.dart';
import 'location_page.dart';

const _pageBg = Color(0xFFF5F6FA);
const _kmPerPercent = 0.65;
const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(20)),
  boxShadow: [
    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
  ],
);

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
        return Scaffold(
          backgroundColor: _pageBg,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                bottom: AppNav.contentBottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(connState: connState),
                  const _StatusSection(),
                  const SizedBox(height: 20),
                  const _BikeImage(),
                  _StateLabel(connState: connState),
                  const SizedBox(height: 20),
                  _ControlArea(connState: connState),
                  const SizedBox(height: 20),
                  _RidingModeSelector(connState: connState),
                  const SizedBox(height: 20),
                  const _LocationCard(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final ble.ConnectionState connState;
  const _Header({required this.connState});

  @override
  Widget build(BuildContext context) {
    final deviceName = connectionManager.device?.platformName;
    final displayName = deviceName != null && deviceName.isNotEmpty
        ? deviceName
        : connState == ble.ConnectionState.disconnected
        ? '未绑定车辆'
        : '超能S·苍穹灰';
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_drop_down, size: 20),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(fontSize: 12, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: connState != ble.ConnectionState.disconnected
                ? () => connectionManager.disconnect()
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isConnecting)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      connState == ble.ConnectionState.ready
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      size: 14,
                      color: statusColor,
                    ),
                  const SizedBox(width: 6),
                  Text(statusText, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BikeState?>(
      stream: connectionManager.bikeStateStream,
      builder: (context, snapshot) {
        final bike = snapshot.data;
        final battery = bike?.batteryPercent;
        final batteryColor = battery == null
            ? Colors.grey
            : battery > 60
            ? Colors.green
            : battery > 20
            ? Colors.orange
            : Colors.red;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '剩余电量',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(
                          battery == null
                              ? Icons.battery_unknown
                              : battery > 80
                              ? Icons.battery_full
                              : battery > 60
                              ? Icons.battery_5_bar
                              : battery > 40
                              ? Icons.battery_4_bar
                              : battery > 20
                              ? Icons.battery_2_bar
                              : Icons.battery_1_bar,
                          color: batteryColor,
                          size: 32,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          battery != null ? '$battery%' : '--',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '预估里程',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          battery != null
                              ? '${(battery * _kmPerPercent).round()}'
                              : '--',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'km',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BikeImage extends StatelessWidget {
  const _BikeImage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 160,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Icon(
            Icons.electric_bike,
            size: 100,
            color: Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}

class _StateLabel extends StatelessWidget {
  final ble.ConnectionState connState;
  const _StateLabel({required this.connState});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BikeState?>(
      stream: connectionManager.bikeStateStream,
      builder: (context, snapshot) {
        final bike = snapshot.data;
        final isConnected = connState == ble.ConnectionState.ready;

        String stateText;
        IconData stateIcon;
        List<Color> gradientColors;

        if (!isConnected) {
          stateText = '未连接';
          stateIcon = Icons.bluetooth_disabled;
          gradientColors = [Colors.grey.shade300, Colors.grey.shade400];
        } else if (bike == null) {
          stateText = '等待车辆状态';
          stateIcon = Icons.sync;
          gradientColors = [Colors.blue.shade200, Colors.blue.shade300];
        } else if (bike.isLocked && !bike.isPowerOn) {
          stateText = '已设防';
          stateIcon = Icons.lock_outline;
          gradientColors = [Colors.purple.shade200, Colors.blue.shade200];
        } else if (!bike.isLocked && bike.isPowerOn) {
          stateText = '已通电';
          stateIcon = Icons.power;
          gradientColors = [Colors.green.shade300, Colors.teal.shade300];
        } else if (!bike.isLocked) {
          stateText = '已解锁';
          stateIcon = Icons.lock_open;
          gradientColors = [Colors.orange.shade200, Colors.amber.shade300];
        } else {
          stateText = '已上锁';
          stateIcon = Icons.lock_outline;
          gradientColors = [Colors.purple.shade200, Colors.blue.shade200];
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(stateIcon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      stateText,
                      key: ValueKey(stateText),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '手动模式',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 4),
                  _ManualModeToggle(enabled: isConnected),
                ],
              ),
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

class _ControlAreaState extends State<_ControlArea> {
  bool _busy = false;

  Future<void> _send(CommandCode cmd) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      final success = await connectionManager.sendCommand(cmd);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cmd.label}失败'),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.connState == ble.ConnectionState.ready && !_busy;
    return StreamBuilder<BikeState?>(
      stream: connectionManager.bikeStateStream,
      builder: (context, snapshot) {
        final bike = snapshot.data;
        final isLocked = bike?.isLocked ?? true;
        final isPowerOn = bike?.isPowerOn ?? false;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _LockToggleButton(
                        isLocked: isLocked,
                        enabled: enabled,
                        loading: _busy,
                        onTap: () => _send(
                          isLocked ? CommandCode.unlock : CommandCode.lock,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ControlButton(
                      icon: Icons.event_seat_outlined,
                      onTap: enabled ? () => _send(CommandCode.openSeat) : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SlideToAction(
                  label: isPowerOn ? '右滑断电' : '右滑通电',
                  icon: isPowerOn ? Icons.power_off : Icons.power_settings_new,
                  backgroundColor: isPowerOn
                      ? const Color(0xFF5D4037)
                      : const Color(0xFF424242),
                  onSlideComplete: enabled
                      ? () => _send(
                          isPowerOn
                              ? CommandCode.powerOff
                              : CommandCode.powerOn,
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.volume_up_outlined,
                        label: '寻车',
                        onTap: enabled ? () => _send(CommandCode.find) : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LockToggleButton extends StatelessWidget {
  final bool isLocked;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _LockToggleButton({
    required this.isLocked,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled || loading
        ? (isLocked ? Colors.blue : Colors.orange)
        : Colors.grey.shade400;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.mediumImpact();
                  onTap();
                }
              : null,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: loading
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Row(
                      key: ValueKey(isLocked),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isLocked ? Icons.lock_outline : Icons.lock_open,
                            key: ValueKey(isLocked),
                            color: color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isLocked ? '解锁' : '设防',
                          style: TextStyle(
                            color: color,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
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

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ControlButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = onTap != null ? Colors.grey.shade700 : Colors.grey.shade400;
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            HapticFeedback.mediumImpact();
            onTap!();
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = onTap != null ? Colors.grey.shade700 : Colors.grey.shade400;
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            HapticFeedback.mediumImpact();
            onTap!();
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RidingModeSelector extends StatelessWidget {
  final ble.ConnectionState connState;
  const _RidingModeSelector({required this.connState});

  @override
  Widget build(BuildContext context) {
    final enabled = connState == ble.ConnectionState.ready;
    return StreamBuilder<RidingMode>(
      stream: connectionManager.ridingModeStream,
      initialData: connectionManager.ridingMode,
      builder: (context, snapshot) {
        final currentMode = snapshot.data ?? RidingMode.standard;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '骑行模式',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: RidingMode.values.map((mode) {
                    final selected = mode == currentMode;
                    final icon = switch (mode) {
                      RidingMode.eco => Icons.eco,
                      RidingMode.standard => Icons.speed,
                      RidingMode.sport => Icons.bolt,
                    };
                    final color = switch (mode) {
                      RidingMode.eco => Colors.green,
                      RidingMode.standard => Colors.blue,
                      RidingMode.sport => Colors.orange,
                    };
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Material(
                          color: selected
                              ? color.withValues(alpha: 0.15)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: enabled && !selected
                                ? () async {
                                    HapticFeedback.mediumImpact();
                                    await connectionManager.setRidingMode(mode);
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: [
                                  Icon(
                                    icon,
                                    color: selected
                                        ? color
                                        : Colors.grey.shade500,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mode.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: selected
                                          ? color
                                          : Colors.grey.shade600,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ManualModeToggle extends StatefulWidget {
  final bool enabled;
  const _ManualModeToggle({required this.enabled});

  @override
  State<_ManualModeToggle> createState() => _ManualModeToggleState();
}

class _ManualModeToggleState extends State<_ManualModeToggle> {
  bool _manualMode = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled
          ? () {
              setState(() => _manualMode = !_manualMode);
              HapticFeedback.selectionClick();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: _manualMode
              ? const Color(0xFF1E88E5)
              : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(13),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: _manualMode ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LocationPage()),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '车辆位置',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
