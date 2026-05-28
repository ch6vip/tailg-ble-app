import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart';
import '../models/official_vehicle.dart';
import '../models/vehicle_profile.dart';
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
import 'vehicle_settings_page.dart';

const _pageBg = Color(0xFFF5F6FA);
const _kmPerPercent = 0.65;
const _phoneControlPanelBg = Color(0xFF252525);
const _phoneControlPanelDown = Color(0xFF1E1E1E);
const _phoneControlItemBg = Color(0x33999999);
const _phoneControlItemPressed = Color(0x1A999999);
const _phoneControlPrimary = Color(0xFF2196F3);
const _phoneControlPrimaryPressed = Color(0x802196F3);
const _phoneControlGearBg = Color(0x80181818);
const _phoneControlRadius = 8.0;
const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(20)),
  boxShadow: [
    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
  ],
);

int? _normalizePercent(int? value) {
  if (value == null) return null;
  return value.clamp(0, 100).toInt();
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
                  _StatusSection(connState: connState),
                  const SizedBox(height: 20),
                  _BikeImage(connState: connState),
                  const SizedBox(height: 20),
                  _ControlArea(connState: connState),
                  const SizedBox(height: 20),
                  const _HomeQuickSection(),
                  const SizedBox(height: 20),
                  _RidingModeSelector(connState: connState),
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

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
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
                              color: effectiveStatusColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              effectiveStatusText,
                              style: TextStyle(
                                fontSize: 12,
                                color: effectiveStatusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: connState != ble.ConnectionState.disconnected
                        ? () => connectionManager.disconnect()
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
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
                              statusIcon,
                              size: 14,
                              color: effectiveStatusColor,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            effectiveStatusText,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
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

class _StatusSection extends StatelessWidget {
  final ble.ConnectionState connState;
  const _StatusSection({required this.connState});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BikeState?>(
      stream: connectionManager.bikeStateStream,
      initialData: connectionManager.latestBikeState,
      builder: (context, snapshot) {
        final bike = snapshot.data;
        return StreamBuilder<OfficialCloudState>(
          stream: officialCloudService.stateStream,
          initialData: officialCloudService.state,
          builder: (context, cloudSnapshot) {
            final cloudState = cloudSnapshot.data ?? officialCloudService.state;
            final cloudVehicle = cloudState.signedIn
                ? cloudState.selectedVehicle
                : null;
            final isBleReady = connState == ble.ConnectionState.ready;
            final battery = _normalizePercent(
              isBleReady
                  ? bike?.batteryPercent ?? cloudVehicle?.electricQuantity
                  : cloudVehicle?.electricQuantity,
            );
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
      },
    );
  }
}

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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 196,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CustomPaint(
                          painter: _BikeModelPainter(
                            accent: display.colors.last,
                            isPowerOn: isPowerOn,
                            isLocked: isLocked,
                          ),
                        ),
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
      return _VehicleStateDisplay('已通电', Icons.power, [
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
    return _VehicleStateDisplay('云端已通电', Icons.power, [
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
  final bool isPowerOn;
  final bool isLocked;

  const _VehicleModelMeta({
    required this.connState,
    required this.isPowerOn,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final state = connState == ble.ConnectionState.ready
        ? '${isPowerOn ? '电源开启' : '电源关闭'} · ${isLocked ? '防盗中' : '可骑行'}'
        : '连接车辆后显示实时状态';
    return Row(
      children: [
        Expanded(
          child: Text(
            '智能电动车',
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

  void _toggleManualMode() {
    if (!widget.enabled) return;
    setState(() => _manualMode = !_manualMode);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: widget.enabled ? _toggleManualMode : null,
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
    );
  }
}

class _BikeModelPainter extends CustomPainter {
  final Color accent;
  final bool isPowerOn;
  final bool isLocked;

  const _BikeModelPainter({
    required this.accent,
    required this.isPowerOn,
    required this.isLocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * 0.56;
    final front = Offset(size.width * 0.72, centerY + 28);
    final rear = Offset(size.width * 0.30, centerY + 28);
    final bodyPaint = Paint()
      ..color = const Color(0xFF2C3038)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accentPaint = Paint()
      ..color = accent.withValues(alpha: isPowerOn ? 0.88 : 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final softPaint = Paint()
      ..color = accent.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.50, centerY + 12), 96, softPaint);
    _drawWheel(canvas, rear, 34, isLocked);
    _drawWheel(canvas, front, 34, isLocked);

    final frame = Path()
      ..moveTo(rear.dx, rear.dy)
      ..lineTo(size.width * 0.43, centerY - 12)
      ..lineTo(size.width * 0.58, centerY + 28)
      ..lineTo(front.dx, front.dy)
      ..moveTo(size.width * 0.43, centerY - 12)
      ..lineTo(size.width * 0.54, centerY - 46)
      ..lineTo(size.width * 0.66, centerY - 18);
    canvas.drawPath(frame, bodyPaint);

    final battery = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.43, centerY - 4, size.width * 0.18, 32),
      const Radius.circular(12),
    );
    canvas.drawRRect(battery, Paint()..color = const Color(0xFF121418));
    canvas.drawRRect(
      battery.deflate(5),
      Paint()..color = accent.withValues(alpha: isPowerOn ? 0.78 : 0.22),
    );

    canvas.drawLine(
      Offset(size.width * 0.54, centerY - 46),
      Offset(size.width * 0.49, centerY - 70),
      bodyPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.46, centerY - 70),
      Offset(size.width * 0.58, centerY - 70),
      bodyPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.66, centerY - 18),
      Offset(size.width * 0.72, centerY - 56),
      bodyPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.72, centerY - 56),
      Offset(size.width * 0.80, centerY - 50),
      accentPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.30, centerY + 28),
      Offset(size.width * 0.25, centerY - 20),
      accentPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.80, centerY - 50),
      5,
      Paint()..color = isPowerOn ? accent : Colors.grey.shade500,
    );
  }

  void _drawWheel(Canvas canvas, Offset center, double radius, bool locked) {
    final wheelPaint = Paint()
      ..color = const Color(0xFF252525)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    final rimPaint = Paint()
      ..color = locked ? Colors.grey.shade400 : accent.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, wheelPaint);
    canvas.drawCircle(center, radius - 11, rimPaint);
    for (var i = 0; i < 6; i++) {
      final angle = i * 3.14159 / 3;
      final end = Offset(
        center.dx + (radius - 13) * math.cos(angle),
        center.dy + (radius - 13) * math.sin(angle),
      );
      canvas.drawLine(center, end, rimPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BikeModelPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.isPowerOn != isPowerOn ||
        oldDelegate.isLocked != isLocked;
  }
}

class _ControlArea extends StatefulWidget {
  final ble.ConnectionState connState;
  const _ControlArea({required this.connState});

  @override
  State<_ControlArea> createState() => _ControlAreaState();
}

class _ControlAreaState extends State<_ControlArea> {
  final _replicaStore = ReplicaFeatureStore();
  QuickControlConfig _quickConfig = const QuickControlConfig();
  bool _busy = false;
  String? _activeControlId;
  String? _lastFailureMessage;

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
    setState(() {
      _busy = true;
      _activeControlId = actionId;
      _lastFailureMessage = null;
    });
    HapticFeedback.mediumImpact();
    try {
      final usesBle = _willUseBle(officialCloudService.state);
      final success = await _sendBySelectedChannel(cmd);
      if (success) {
        unawaited(locationService.recordDefaultVehicleLocation());
        if (usesBle) {
          unawaited(connectionManager.refreshBikeState());
        }
      }
      if (!success && mounted) {
        _showFailureSnack(_lastFailureMessage ?? '${cmd.label}失败');
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

  bool _willUseBle(OfficialCloudState cloudState) {
    return switch (cloudState.controlChannel) {
      OfficialControlChannel.ble =>
        widget.connState == ble.ConnectionState.ready,
      OfficialControlChannel.officialCloud => false,
      OfficialControlChannel.automatic => _canUseLinkedBle(cloudState),
    };
  }

  Future<bool> _sendBySelectedChannel(CommandCode cmd) async {
    final cloudState = officialCloudService.state;
    final canUseBle = _canUseLinkedBle(cloudState);
    final canUseCloud =
        cloudState.signedIn && cloudState.selectedVehicle != null;

    switch (cloudState.controlChannel) {
      case OfficialControlChannel.ble:
        return connectionManager.sendCommand(cmd);
      case OfficialControlChannel.officialCloud:
        return _sendOfficialCloudCommand(cmd);
      case OfficialControlChannel.automatic:
        if (canUseBle) {
          return connectionManager.sendCommand(cmd);
        }
        if (canUseCloud) {
          return _sendOfficialCloudCommand(cmd);
        }
        return false;
    }
  }

  bool _canUseLinkedBle(OfficialCloudState cloudState) {
    if (widget.connState != ble.ConnectionState.ready) return false;
    final selected = cloudState.selectedVehicle;
    if (selected == null) return true;
    final linkedId = cloudState.linkedLocalVehicleId(selected.key);
    if (linkedId == null || linkedId.isEmpty) return true;
    return vehicleStore.defaultVehicleId == linkedId;
  }

  String _disabledReason(OfficialCloudState cloudState) {
    switch (cloudState.controlChannel) {
      case OfficialControlChannel.ble:
        return widget.connState == ble.ConnectionState.ready
            ? '当前官方车辆未关联这台本地 BLE 车辆'
            : 'BLE 未连接，当前通道不可用';
      case OfficialControlChannel.officialCloud:
        return cloudState.signedIn ? '官方账号未选择车辆' : '请先登录官方账号';
      case OfficialControlChannel.automatic:
        return '请连接 BLE 或登录官方账号后再控车';
    }
  }

  void _showUnavailableSnack(String reason) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(reason), duration: const Duration(seconds: 2)),
    );
  }

  Future<bool> _sendOfficialCloudCommand(CommandCode cmd) async {
    try {
      final message = await officialCloudService.sendCommand(cmd);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cmd.label}已通过官方云端返回：$message'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      _lastFailureMessage = _cloudErrorMessage(e);
      return false;
    }
  }

  void _showFailureSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
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

  String _cloudErrorMessage(Object e) {
    if (e is OfficialCloudApiException) return e.message;
    return e.toString();
  }

  Future<void> _runQuickAction(_QuickControlSpec spec, bool enabled) async {
    if (spec.command != null) {
      if (!enabled) return;
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OfficialCloudState>(
      stream: officialCloudService.stateStream,
      initialData: officialCloudService.state,
      builder: (context, cloudSnapshot) {
        final cloudState = cloudSnapshot.data ?? officialCloudService.state;
        final canUseBle = _canUseLinkedBle(cloudState);
        final canUseCloud =
            cloudState.signedIn && cloudState.selectedVehicle != null;
        final enabled =
            !_busy &&
            (switch (cloudState.controlChannel) {
              OfficialControlChannel.ble => canUseBle,
              OfficialControlChannel.officialCloud => canUseCloud,
              OfficialControlChannel.automatic => canUseBle || canUseCloud,
            });
        final disabledReason = _disabledReason(cloudState);

        return StreamBuilder<BikeState?>(
          stream: connectionManager.bikeStateStream,
          builder: (context, snapshot) {
            final bike = snapshot.data;
            final cloudVehicle = cloudState.selectedVehicle;
            final useBleState =
                canUseBle &&
                cloudState.controlChannel !=
                    OfficialControlChannel.officialCloud;
            final isLocked = useBleState
                ? bike?.isLocked ?? true
                : cloudVehicle?.isLocked ?? true;
            final isPowerOn = useBleState
                ? bike?.isPowerOn ?? false
                : cloudVehicle?.isPowerOn ?? false;
            final firstQuick = _quickControlSpec(_quickConfig.firstActionId);
            final secondQuick = _quickControlSpec(_quickConfig.secondActionId);
            final firstQuickActive =
                _activeControlId == 'quick:${firstQuick.id}';
            final secondQuickActive =
                _activeControlId == 'quick:${secondQuick.id}';
            final powerLabel = isPowerOn ? '断电' : '通电';
            final lockLabel = isLocked ? '解锁' : '设防';
            final primaryPowerColor = isPowerOn
                ? AppColors.danger
                : _phoneControlPrimary;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _phoneControlPanelBg,
                  borderRadius: BorderRadius.circular(_phoneControlRadius),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x16000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ControlPanelHeader(
                      enabled: enabled,
                      isLocked: isLocked,
                      isPowerOn: isPowerOn,
                    ),
                    const SizedBox(height: 12),
                    _ControlChannelBar(
                      channel: cloudState.controlChannel,
                      canUseBle: canUseBle,
                      canUseCloud: canUseCloud,
                      vehicleName: cloudVehicle?.displayName,
                      disabledReason: enabled ? null : disabledReason,
                    ),
                    const SizedBox(height: 10),
                    _CurrentGearStrip(enabled: enabled),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ControlTile(
                            icon: isLocked
                                ? Icons.lock_open
                                : Icons.lock_outline,
                            label: lockLabel,
                            enabled: enabled,
                            active: _activeControlId == 'fixedLock',
                            loading: _activeControlId == 'fixedLock',
                            disabledReason: disabledReason,
                            statusText: isLocked ? '当前设防' : '当前解锁',
                            onTap: () => _send(
                              isLocked ? CommandCode.unlock : CommandCode.lock,
                              actionId: 'fixedLock',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ControlTile(
                            icon: Icons.volume_up_outlined,
                            label: '寻车',
                            enabled: enabled,
                            active: _activeControlId == 'fixedFind',
                            loading: _activeControlId == 'fixedFind',
                            disabledReason: disabledReason,
                            statusText: '鸣笛定位',
                            onTap: () =>
                                _send(CommandCode.find, actionId: 'fixedFind'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _PrimaryPowerControl(
                      label: powerLabel,
                      hint: isPowerOn ? '左滑关闭车辆电源' : '右滑开启车辆电源',
                      icon: isPowerOn
                          ? Icons.power_off
                          : Icons.power_settings_new,
                      reverseSlide: isPowerOn,
                      loading: _activeControlId == 'slidePower',
                      loadingLabel: isPowerOn ? '正在断电' : '正在通电',
                      color: primaryPowerColor,
                      enabled: enabled,
                      onDisabledTap: () =>
                          _showUnavailableSnack(disabledReason),
                      onSlideComplete: () => _send(
                        isPowerOn ? CommandCode.powerOff : CommandCode.powerOn,
                        actionId: 'slidePower',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ControlTile(
                            icon: firstQuick.icon,
                            label: firstQuick.label,
                            enabled: firstQuick.command == null || enabled,
                            active: firstQuickActive,
                            loading: firstQuickActive,
                            disabledReason: disabledReason,
                            compact: true,
                            onTap: () => _runQuickAction(firstQuick, enabled),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Stack(
                            children: [
                              _ControlTile(
                                icon: secondQuick.icon,
                                label: secondQuick.label,
                                enabled: secondQuick.command == null || enabled,
                                active: secondQuickActive,
                                loading: secondQuickActive,
                                disabledReason: disabledReason,
                                compact: true,
                                onTap: () =>
                                    _runQuickAction(secondQuick, enabled),
                              ),
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: _QuickEditButton(
                                  onTap: _editQuickControls,
                                  dark: true,
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
          },
        );
      },
    );
  }
}

class _ControlChannelBar extends StatelessWidget {
  final OfficialControlChannel channel;
  final bool canUseBle;
  final bool canUseCloud;
  final String? vehicleName;
  final String? disabledReason;

  const _ControlChannelBar({
    required this.channel,
    required this.canUseBle,
    required this.canUseCloud,
    required this.vehicleName,
    required this.disabledReason,
  });

  @override
  Widget build(BuildContext context) {
    final effective = switch (channel) {
      OfficialControlChannel.ble => 'BLE',
      OfficialControlChannel.officialCloud => '官方云端',
      OfficialControlChannel.automatic =>
        canUseBle
            ? '自动：BLE'
            : canUseCloud
            ? '自动：官方云端'
            : '自动：待连接',
    };
    final color = canUseBle || canUseCloud
        ? AppColors.primary
        : AppColors.textTertiary;
    final subtitle = disabledReason != null
        ? disabledReason!
        : canUseCloud
        ? vehicleName ?? '官方车辆已选择'
        : canUseBle
        ? '本地蓝牙已就绪'
        : '连接 BLE 或登录官方账号后可控车';

    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OfficialCloudPage()),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.cloud_sync_outlined, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '控车通道 · $effective',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlPanelHeader extends StatelessWidget {
  final bool enabled;
  final bool isLocked;
  final bool isPowerOn;

  const _ControlPanelHeader({
    required this.enabled,
    required this.isLocked,
    required this.isPowerOn,
  });

  @override
  Widget build(BuildContext context) {
    final stateText = enabled
        ? [isLocked ? '已设防' : '已解锁', isPowerOn ? '已通电' : '未通电'].join(' · ')
        : '待连接';
    return Row(
      children: [
        const Text(
          '手机控车',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _phoneControlGearBg,
            borderRadius: BorderRadius.circular(_phoneControlRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                enabled ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 12,
                color: enabled ? _phoneControlPrimary : Colors.white38,
              ),
              const SizedBox(width: 6),
              Text(
                stateText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryPowerControl extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool reverseSlide;
  final bool loading;
  final String loadingLabel;
  final Color color;
  final bool enabled;
  final VoidCallback onDisabledTap;
  final VoidCallback onSlideComplete;

  const _PrimaryPowerControl({
    required this.label,
    required this.hint,
    required this.icon,
    required this.reverseSlide,
    required this.loading,
    required this.loadingLabel,
    required this.color,
    required this.enabled,
    required this.onDisabledTap,
    required this.onSlideComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _phoneControlItemBg,
        borderRadius: BorderRadius.circular(_phoneControlRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: enabled ? color : _phoneControlPrimaryPressed,
              borderRadius: BorderRadius.circular(_phoneControlRadius),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 144,
            child: SlideToAction(
              label: reverseSlide ? '左滑' : '右滑',
              icon: icon,
              reverseSlide: reverseSlide,
              loading: loading,
              loadingLabel: loadingLabel,
              backgroundColor: color,
              enabled: enabled,
              onDisabledTap: onDisabledTap,
              onSlideComplete: onSlideComplete,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentGearStrip extends StatelessWidget {
  final bool enabled;

  const _CurrentGearStrip({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RidingMode>(
      stream: connectionManager.ridingModeStream,
      initialData: connectionManager.ridingMode,
      builder: (context, snapshot) {
        final mode = snapshot.data ?? RidingMode.standard;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _phoneControlGearBg,
            borderRadius: BorderRadius.circular(_phoneControlRadius),
          ),
          child: Row(
            children: [
              const Text(
                '当前档位',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: enabled
                        ? (mode.index + 1) / RidingMode.values.length
                        : 0,
                    backgroundColor: _phoneControlItemBg,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      enabled ? _phoneControlPrimary : Colors.white24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                enabled ? mode.label : '未连接',
                style: TextStyle(
                  fontSize: 12,
                  color: enabled ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickControlSpec {
  final String id;
  final String label;
  final IconData icon;
  final CommandCode? command;
  final WidgetBuilder? pageBuilder;

  const _QuickControlSpec({
    required this.id,
    required this.label,
    required this.icon,
    this.command,
    this.pageBuilder,
  });
}

List<_QuickControlSpec> get _quickControlSpecs => [
  _QuickControlSpec(
    id: 'soundEffects',
    label: '声音设置',
    icon: Icons.graphic_eq,
    pageBuilder: (_) => const QgjSoundEffectsPage(),
  ),
  _QuickControlSpec(
    id: 'share',
    label: '分享用车',
    icon: Icons.ios_share,
    pageBuilder: (_) => const ShareBikePage(),
  ),
  _QuickControlSpec(
    id: 'fence',
    label: '电子围栏',
    icon: Icons.location_searching,
    pageBuilder: (_) => const ElectricFencePage(),
  ),
  _QuickControlSpec(
    id: 'nfc',
    label: 'NFC钥匙',
    icon: Icons.nfc,
    pageBuilder: (_) => const NfcKeyPage(),
  ),
  _QuickControlSpec(
    id: 'rideRecord',
    label: '骑行记录',
    icon: Icons.route_outlined,
    pageBuilder: (_) => const RideRecordPage(),
  ),
  const _QuickControlSpec(
    id: 'seat',
    label: '坐垫锁',
    icon: Icons.event_seat_outlined,
    command: CommandCode.openSeat,
  ),
  const _QuickControlSpec(
    id: 'find',
    label: '寻车',
    icon: Icons.volume_up_outlined,
    command: CommandCode.find,
  ),
];

_QuickControlSpec _quickControlSpec(String id) {
  return _quickControlSpecs.firstWhere(
    (spec) => spec.id == id,
    orElse: () => _quickControlSpecs.first,
  );
}

class QuickControlEditPage extends StatefulWidget {
  final QuickControlConfig initialConfig;

  const QuickControlEditPage({super.key, required this.initialConfig});

  @override
  State<QuickControlEditPage> createState() => _QuickControlEditPageState();
}

class _QuickControlEditPageState extends State<QuickControlEditPage> {
  late String _firstActionId;
  late String _secondActionId;

  @override
  void initState() {
    super.initState();
    _firstActionId = widget.initialConfig.firstActionId;
    _secondActionId = widget.initialConfig.secondActionId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '添加快捷键',
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    QuickControlConfig(
                      firstActionId: _firstActionId,
                      secondActionId: _secondActionId,
                    ),
                  ),
                  child: const Text('保存'),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _QuickEditSection(
                    title: '快捷功能1',
                    subtitle: '点击选择快捷功能',
                    selectedId: _firstActionId,
                    specs: _quickControlSpecs
                        .where((spec) => spec.command == null)
                        .toList(growable: false),
                    onSelected: (id) => setState(() => _firstActionId = id),
                  ),
                  _QuickEditSection(
                    title: '快捷功能2',
                    subtitle: '建议放置电子坐垫锁',
                    selectedId: _secondActionId,
                    specs: _quickControlSpecs
                        .where(
                          (spec) =>
                              spec.id == 'seat' ||
                              spec.id == 'find' ||
                              spec.command == null,
                        )
                        .toList(growable: false),
                    onSelected: (id) => setState(() => _secondActionId = id),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      '* 车辆命令仅使用已验证的本地 BLE 控车命令；页面入口不会写入车辆。',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickEditSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String selectedId;
  final List<_QuickControlSpec> specs;
  final ValueChanged<String> onSelected;

  const _QuickEditSection({
    required this.title,
    required this.subtitle,
    required this.selectedId,
    required this.specs,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '（$subtitle）',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: specs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemBuilder: (context, index) {
              final spec = specs[index];
              final selected = spec.id == selectedId;
              return _QuickEditOption(
                spec: spec,
                selected: selected,
                onTap: () => onSelected(spec.id),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickEditOption extends StatelessWidget {
  final _QuickControlSpec spec;
  final bool selected;
  final VoidCallback onTap;

  const _QuickEditOption({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(spec.icon, color: color, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      spec.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  right: 8,
                  bottom: 8,
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool active;
  final bool loading;
  final bool compact;
  final String? statusText;
  final String? disabledReason;
  final VoidCallback onTap;

  const _ControlTile({
    required this.icon,
    required this.label,
    required this.enabled,
    this.active = false,
    required this.loading,
    this.compact = false,
    this.statusText,
    this.disabledReason,
    required this.onTap,
  });

  @override
  State<_ControlTile> createState() => _ControlTileState();
}

class _ControlTileState extends State<_ControlTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _showDisabledReason() {
    final reason = widget.disabledReason;
    if (reason == null || reason.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(reason), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.enabled && !widget.loading;
    final color = widget.active
        ? Colors.white
        : widget.enabled
        ? Colors.white
        : Colors.white38;
    final secondaryColor = widget.enabled ? Colors.white54 : Colors.white30;
    final background = widget.active
        ? _phoneControlPrimary
        : _pressed
        ? _phoneControlItemPressed
        : widget.enabled
        ? _phoneControlItemBg
        : _phoneControlPanelDown;
    final radius = BorderRadius.circular(_phoneControlRadius);
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      scale: _pressed ? 0.96 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: Border.all(
            color: widget.active
                ? _phoneControlPrimary.withValues(alpha: 0.42)
                : Colors.transparent,
            width: 1,
          ),
          boxShadow: widget.active
              ? [
                  BoxShadow(
                    color: _phoneControlPrimary.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: widget.loading
                ? null
                : interactive
                ? () {
                    _setPressed(false);
                    HapticFeedback.mediumImpact();
                    widget.onTap();
                  }
                : _showDisabledReason,
            onTapDown: interactive ? (_) => _setPressed(true) : null,
            onTapCancel: interactive ? () => _setPressed(false) : null,
            onTapUp: interactive ? (_) => _setPressed(false) : null,
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 10 : 12,
                vertical: widget.compact ? 12 : 14,
              ),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: widget.loading
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            width: widget.compact ? 20 : 24,
                            height: widget.compact ? 20 : 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: color,
                            ),
                          )
                        : Icon(
                            widget.icon,
                            key: ValueKey(widget.icon),
                            color: color,
                            size: widget.compact ? 22 : 26,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: widget.compact ? 13 : 15,
                            height: 1.1,
                            color: color,
                            fontWeight: widget.active
                                ? FontWeight.w800
                                : FontWeight.w700,
                          ),
                        ),
                        if (widget.statusText != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.statusText!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryColor,
                            ),
                          ),
                        ],
                      ],
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

class _QuickEditButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool dark;

  const _QuickEditButton({required this.onTap, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final background = dark ? Colors.white24 : AppColors.primary;
    final foreground = dark ? Colors.white : Colors.white;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(Icons.edit, color: foreground, size: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeQuickSection extends StatelessWidget {
  const _HomeQuickSection();

  @override
  Widget build(BuildContext context) {
    final items = [
      _HomeQuickItem(
        icon: Icons.location_on_outlined,
        label: '车辆位置',
        accent: AppColors.info,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LocationPage()),
        ),
      ),
      _HomeQuickItem(
        icon: Icons.tune,
        label: '车辆设置',
        accent: _phoneControlPrimary,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VehicleSettingsPage()),
        ),
      ),
      _HomeQuickItem(
        icon: Icons.location_searching,
        label: '电子围栏',
        accent: AppColors.success,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ElectricFencePage()),
        ),
      ),
      _HomeQuickItem(
        icon: Icons.ios_share,
        label: '分享用车',
        accent: const Color(0xFF7B61FF),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShareBikePage()),
        ),
      ),
      _HomeQuickItem(
        icon: Icons.graphic_eq,
        label: '音效设置',
        accent: const Color(0xFF00A896),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QgjSoundEffectsPage()),
        ),
      ),
      _HomeQuickItem(
        icon: Icons.nfc,
        label: 'NFC钥匙',
        accent: const Color(0xFF7B61FF),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NfcKeyPage()),
        ),
      ),
      _HomeQuickItem(
        icon: Icons.route_outlined,
        label: '骑行记录',
        accent: const Color(0xFFFF8A00),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RideRecordPage()),
        ),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '快捷功能',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 92,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => SizedBox(
                  width: 82,
                  child: _HomeQuickTile(item: items[index]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: SizedBox(
                width: 60,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: 3 / items.length,
                    backgroundColor: const Color(0xFFDFDFDF),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF2C2C2C),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeQuickItem {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _HomeQuickItem({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });
}

class _HomeQuickTile extends StatelessWidget {
  final _HomeQuickItem item;

  const _HomeQuickTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          item.onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 92,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 22, color: item.accent),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
  final bool? value;
  final ValueChanged<bool>? onChanged;
  const _ManualModeToggle({required this.enabled, this.value, this.onChanged});

  @override
  State<_ManualModeToggle> createState() => _ManualModeToggleState();
}

class _ManualModeToggleState extends State<_ManualModeToggle> {
  bool _manualMode = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.value ?? _manualMode;
    return GestureDetector(
      onTap: widget.enabled
          ? () {
              final next = !selected;
              if (widget.value == null) {
                setState(() => _manualMode = next);
              }
              widget.onChanged?.call(next);
              HapticFeedback.selectionClick();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E88E5) : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(13),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: selected ? Alignment.centerRight : Alignment.centerLeft,
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
