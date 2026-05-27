import 'package:flutter/material.dart';
import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart';

class ControlPage extends StatelessWidget {
  const ControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: StreamBuilder<ble.ConnectionState>(
          stream: connectionManager.stateStream,
          initialData: connectionManager.state,
          builder: (context, snapshot) {
            final connState = snapshot.data ?? ble.ConnectionState.disconnected;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, connState),
                  _buildStatusSection(context),
                  const SizedBox(height: 20),
                  _buildBikeImage(context),
                  _buildStateLabel(context, connState),
                  const SizedBox(height: 20),
                  _buildControlArea(context, connState),
                  const SizedBox(height: 20),
                  _buildLocationCard(context),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ble.ConnectionState connState) {
    final statusText = switch (connState) {
      ble.ConnectionState.disconnected => '离线',
      ble.ConnectionState.connecting => '连接中',
      ble.ConnectionState.connected => '已连接',
      ble.ConnectionState.ready => '在线',
    };
    final statusColor = connState == ble.ConnectionState.ready
        ? Colors.green
        : Colors.grey;
    final isConnecting = connState == ble.ConnectionState.connecting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  '超能S·苍穹灰',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_drop_down, size: 20),
                const SizedBox(width: 8),
                Container(
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
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
        ],
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('剩余电量',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(width: 24),
              Text('预估里程',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 48,
                height: 22,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              const Text(
                '--',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w300),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('km',
                    style: TextStyle(fontSize: 16, color: Colors.black54)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBikeImage(BuildContext context) {
    return Center(
      child: Container(
        height: 180,
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

  Widget _buildStateLabel(BuildContext context, ble.ConnectionState connState) {
    final stateText = connState == ble.ConnectionState.ready ? '已关机设防' : '未连接';
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
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade200, Colors.blue.shade200],
                  ),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.lock_outline, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(stateText, style: const TextStyle(fontSize: 14)),
            ],
          ),
          Row(
            children: [
              Text('手动模式',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(width: 4),
              Switch(value: false, onChanged: null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlArea(BuildContext context, ble.ConnectionState connState) {
    final enabled = connState == ble.ConnectionState.ready;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildSmallButton(Icons.bookmark_border),
                const SizedBox(width: 12),
                Expanded(child: _buildPowerSlider()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSmallButton(Icons.add_circle_outline),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                            Icons.volume_up_outlined, '寻车',
                            onTap: enabled
                                ? () => connectionManager
                                    .sendCommand(CommandCode.find)
                                : null),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                            Icons.lock_outline, '设防',
                            onTap: enabled
                                ? () => connectionManager
                                    .sendCommand(CommandCode.lock)
                                : null),
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

  Widget _buildSmallButton(IconData icon) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: Colors.grey.shade700, size: 24),
    );
  }

  Widget _buildPowerSlider() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(left: 4),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.power_settings_new,
                color: Colors.white, size: 24),
          ),
          const Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                  Icon(Icons.chevron_right, color: Colors.white70, size: 20),
                  SizedBox(width: 4),
                  Text('右滑启动',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, {VoidCallback? onTap}) {
    final color = onTap != null ? Colors.grey.shade700 : Colors.grey.shade400;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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