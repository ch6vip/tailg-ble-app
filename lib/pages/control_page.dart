import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart';
import '../widgets/slide_to_action.dart';

const _pageBg = Color(0xFFF5F6FA);
const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(20)),
  boxShadow: [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
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
    final isConnecting = connState == ble.ConnectionState.connecting ||
        connState == ble.ConnectionState.reconnecting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  '超能S·苍穹灰',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_drop_down, size: 20),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
        final voltage = bike?.voltage;
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
                    Text('剩余电量',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
                              fontSize: 28, fontWeight: FontWeight.w300),
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
                    Text('当前电压',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(Icons.bolt, color: Colors.amber.shade700, size: 28),
                        const SizedBox(width: 4),
                        Text(
                          voltage != null ? voltage.toStringAsFixed(1) : '--',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w300),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text('V',
                              style: TextStyle(fontSize: 14, color: Colors.black54)),
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
        height: 180,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Icon(Icons.electric_bike, size: 100, color: Colors.grey.shade300),
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
          stateText = '已连接';
          stateIcon = Icons.bluetooth_connected;
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
                    child: Text(stateText,
                        key: ValueKey(stateText),
                        style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
              if (bike != null && bike.temperature != null)
                Row(
                  children: [
                    Icon(Icons.thermostat, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text('${bike.temperature!.toStringAsFixed(0)}°C',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ControlArea extends StatelessWidget {
  final ble.ConnectionState connState;
  const _ControlArea({required this.connState});

  @override
  Widget build(BuildContext context) {
    final enabled = connState == ble.ConnectionState.ready;
    return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration,
            child: Column(
              children: [
                Row(
                  children: [
                    _ControlButton(
                      icon: Icons.event_seat_outlined,
                      onTap: enabled
                          ? () => connectionManager
                              .sendCommand(CommandCode.openSeat)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SlideToAction(
                        onSlideComplete: enabled
                            ? () => connectionManager
                                .sendCommand(CommandCode.unlock)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ControlButton(
                      icon: Icons.power_off_outlined,
                      onTap: enabled
                          ? () => connectionManager
                              .sendCommand(CommandCode.powerOff)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.volume_up_outlined,
                              label: '寻车',
                              onTap: enabled
                                  ? () => connectionManager
                                      .sendCommand(CommandCode.find)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.lock_outline,
                              label: '设防',
                              onTap: enabled
                                  ? () => connectionManager
                                      .sendCommand(CommandCode.lock)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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

class _LocationCard extends StatelessWidget {
  const _LocationCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('车辆位置',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
