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

const _pageBg = ReplicaColors.pageBg;
const _kmPerPercent = 0.65;
const _phoneControlItemBg = Color(0xFFF7F8FA);
const _phoneControlPrimary = ReplicaColors.blue;
const _phoneControlPrimaryPressed = Color(0x225596FF);
const _phoneControlRadius = 8.0;
const _officialPressedBg = Color(0xFFE5E5E5);
const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(ReplicaRadii.card)),
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
                  _HomeTopSection(connState: connState),
                  const SizedBox(height: 14),
                  _ControlArea(connState: connState),
                  const SizedBox(height: 14),
                  const _HomeQuickSection(),
                  const SizedBox(height: 14),
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

class _HomeTopSection extends StatelessWidget {
  final ble.ConnectionState connState;

  const _HomeTopSection({required this.connState});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: ReplicaColors.pageBg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(connState: connState),
          _StatusSection(connState: connState),
          const SizedBox(height: 8),
          _BikeImage(connState: connState),
          const SizedBox(height: 4),
        ],
      ),
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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
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
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: ReplicaColors.ink,
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
                    tooltip: '消息与连接日志',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LogPage()),
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _HomeMetric(
                      label: '剩余电量',
                      value: battery != null ? '$battery' : '--',
                      unit: battery != null ? '%' : '',
                      color: batteryColor,
                    ),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: _HomeMetric(
                      label: '预估里程',
                      value: battery != null
                          ? '${(battery * _kmPerPercent).round()}'
                          : '--',
                      unit: battery != null ? 'km' : '',
                    ),
                  ),
                  const SizedBox(width: 14),
                  _HomeBlePill(connState: connState),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HomeMetric extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _HomeMetric({
    required this.label,
    required this.value,
    required this.unit,
    this.color = ReplicaColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ReplicaColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: value.length > 3 ? 30 : 32,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ReplicaColors.ink,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HomeBlePill extends StatelessWidget {
  final ble.ConnectionState connState;

  const _HomeBlePill({required this.connState});

  @override
  Widget build(BuildContext context) {
    final ready = connState == ble.ConnectionState.ready;
    final connecting =
        connState == ble.ConnectionState.connecting ||
        connState == ble.ConnectionState.reconnecting;
    final color = ready
        ? AppColors.success
        : connecting
        ? AppColors.warning
        : ReplicaColors.muted;
    final text = ready
        ? 'BLE'
        : connecting
        ? '连接中'
        : '离线';
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(ReplicaRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
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
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.97 : 1,
      child: Material(
        color: _pressed
            ? _officialPressedBg
            : Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: widget.enabled
              ? () {
                  _setPressed(false);
                  _toggleManualMode();
                }
              : null,
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
    final front = Offset(size.width * 0.75, centerY + 34);
    final rear = Offset(size.width * 0.27, centerY + 34);
    final bodyPaint = Paint()
      ..color = const Color(0xFF2A2D35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accentPaint = Paint()
      ..color = accent.withValues(alpha: isPowerOn ? 0.88 : 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final softPaint = Paint()
      ..color = const Color(0xFFDDE3EC).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, centerY + 52),
        width: size.width * 0.82,
        height: 32,
      ),
      softPaint,
    );
    _drawWheel(canvas, rear, 38, isLocked);
    _drawWheel(canvas, front, 38, isLocked);

    final frame = Path()
      ..moveTo(rear.dx, rear.dy)
      ..lineTo(size.width * 0.42, centerY - 16)
      ..lineTo(size.width * 0.59, centerY + 32)
      ..lineTo(front.dx, front.dy)
      ..moveTo(size.width * 0.42, centerY - 16)
      ..lineTo(size.width * 0.54, centerY - 52)
      ..lineTo(size.width * 0.67, centerY - 22);
    canvas.drawPath(frame, bodyPaint);

    final battery = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.42, centerY - 2, size.width * 0.20, 34),
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
              child: Column(
                children: [
                  _ControlTipBar(
                    enabled: enabled,
                    isLocked: isLocked,
                    isPowerOn: isPowerOn,
                    channel: cloudState.controlChannel,
                    canUseBle: canUseBle,
                    canUseCloud: canUseCloud,
                    vehicleName: cloudVehicle?.displayName,
                    disabledReason: enabled ? null : disabledReason,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 204,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 90,
                          child: _OfficialQuickControlCard(
                            firstQuick: firstQuick,
                            secondQuick: secondQuick,
                            firstActive: firstQuickActive,
                            secondActive: secondQuickActive,
                            enabled: enabled,
                            disabledReason: disabledReason,
                            onFirstTap: () =>
                                _runQuickAction(firstQuick, enabled),
                            onSecondTap: () =>
                                _runQuickAction(secondQuick, enabled),
                            onEditTap: _editQuickControls,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _OfficialMainControlCard(
                            powerLabel: powerLabel,
                            powerHint: isPowerOn ? '左滑关闭' : '右滑启动',
                            powerIcon: isPowerOn
                                ? Icons.power_off
                                : Icons.power_settings_new,
                            reverseSlide: isPowerOn,
                            powerLoading: _activeControlId == 'slidePower',
                            powerLoadingLabel: isPowerOn ? '正在断电' : '正在通电',
                            powerColor: primaryPowerColor,
                            enabled: enabled,
                            disabledReason: disabledReason,
                            onDisabledTap: () =>
                                _showUnavailableSnack(disabledReason),
                            onPowerSlideComplete: () => _send(
                              isPowerOn
                                  ? CommandCode.powerOff
                                  : CommandCode.powerOn,
                              actionId: 'slidePower',
                            ),
                            lockIcon: isLocked
                                ? Icons.lock_open
                                : Icons.lock_outline,
                            lockLabel: lockLabel,
                            lockStatus: isLocked ? '当前设防' : '当前解锁',
                            lockActive: _activeControlId == 'fixedLock',
                            onLockTap: () => _send(
                              isLocked ? CommandCode.unlock : CommandCode.lock,
                              actionId: 'fixedLock',
                            ),
                            findActive: _activeControlId == 'fixedFind',
                            onFindTap: () =>
                                _send(CommandCode.find, actionId: 'fixedFind'),
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

class _ControlTipBar extends StatelessWidget {
  final bool enabled;
  final bool isLocked;
  final bool isPowerOn;
  final OfficialControlChannel channel;
  final bool canUseBle;
  final bool canUseCloud;
  final String? vehicleName;
  final String? disabledReason;

  const _ControlTipBar({
    required this.enabled,
    required this.isLocked,
    required this.isPowerOn,
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
      OfficialControlChannel.officialCloud => '云端',
      OfficialControlChannel.automatic =>
        canUseBle
            ? 'BLE'
            : canUseCloud
            ? '云端'
            : '待连接',
    };
    final status = enabled
        ? '${isLocked ? '设防' : '解锁'} · ${isPowerOn ? '已通电' : '未通电'}'
        : disabledReason ?? '请连接车辆后控车';
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.smart_toy_outlined,
            size: 22,
            color: ReplicaColors.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OfficialCloudPage()),
              ),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$status · $effective',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ReplicaColors.muted,
                        ),
                      ),
                    ),
                    if (vehicleName != null && canUseCloud) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          vehicleName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ReplicaColors.subtle,
                          ),
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
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            enabled ? Icons.touch_app_outlined : Icons.link_off,
            size: 21,
            color: enabled ? ReplicaColors.blue : ReplicaColors.muted,
          ),
        ),
      ],
    );
  }
}

class _OfficialQuickControlCard extends StatelessWidget {
  final _QuickControlSpec firstQuick;
  final _QuickControlSpec secondQuick;
  final bool firstActive;
  final bool secondActive;
  final bool enabled;
  final String disabledReason;
  final VoidCallback onFirstTap;
  final VoidCallback onSecondTap;
  final VoidCallback onEditTap;

  const _OfficialQuickControlCard({
    required this.firstQuick,
    required this.secondQuick,
    required this.firstActive,
    required this.secondActive,
    required this.enabled,
    required this.disabledReason,
    required this.onFirstTap,
    required this.onSecondTap,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _officialControlCardDecoration,
      child: Column(
        children: [
          Expanded(
            child: _OfficialSmallControlButton(
              icon: firstQuick.icon,
              label: firstQuick.label,
              enabled: firstQuick.command == null || enabled,
              active: firstActive,
              loading: firstActive,
              disabledReason: disabledReason,
              onTap: onFirstTap,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _OfficialSmallControlButton(
                    icon: secondQuick.icon,
                    label: secondQuick.label,
                    enabled: secondQuick.command == null || enabled,
                    active: secondActive,
                    loading: secondActive,
                    disabledReason: disabledReason,
                    onTap: onSecondTap,
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: _QuickEditButton(onTap: onEditTap),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialMainControlCard extends StatelessWidget {
  final String powerLabel;
  final String powerHint;
  final IconData powerIcon;
  final bool reverseSlide;
  final bool powerLoading;
  final String powerLoadingLabel;
  final Color powerColor;
  final bool enabled;
  final String disabledReason;
  final VoidCallback onDisabledTap;
  final VoidCallback onPowerSlideComplete;
  final IconData lockIcon;
  final String lockLabel;
  final String lockStatus;
  final bool lockActive;
  final VoidCallback onLockTap;
  final bool findActive;
  final VoidCallback onFindTap;

  const _OfficialMainControlCard({
    required this.powerLabel,
    required this.powerHint,
    required this.powerIcon,
    required this.reverseSlide,
    required this.powerLoading,
    required this.powerLoadingLabel,
    required this.powerColor,
    required this.enabled,
    required this.disabledReason,
    required this.onDisabledTap,
    required this.onPowerSlideComplete,
    required this.lockIcon,
    required this.lockLabel,
    required this.lockStatus,
    required this.lockActive,
    required this.onLockTap,
    required this.findActive,
    required this.onFindTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _officialControlCardDecoration,
      child: Column(
        children: [
          _PrimaryPowerControl(
            label: powerLabel,
            hint: powerHint,
            icon: powerIcon,
            reverseSlide: reverseSlide,
            loading: powerLoading,
            loadingLabel: powerLoadingLabel,
            color: powerColor,
            enabled: enabled,
            onDisabledTap: onDisabledTap,
            onSlideComplete: onPowerSlideComplete,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _OfficialSmallControlButton(
                  icon: Icons.volume_up_outlined,
                  label: '寻车',
                  subLabel: '鸣笛定位',
                  enabled: enabled,
                  active: findActive,
                  loading: findActive,
                  disabledReason: disabledReason,
                  onTap: onFindTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OfficialSmallControlButton(
                  icon: lockIcon,
                  label: lockLabel,
                  subLabel: lockStatus,
                  enabled: enabled,
                  active: lockActive,
                  loading: lockActive,
                  disabledReason: disabledReason,
                  onTap: onLockTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

BoxDecoration get _officialControlCardDecoration => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(_phoneControlRadius),
  border: Border.all(color: Colors.white),
  boxShadow: const [
    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
  ],
);

class _OfficialSmallControlButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subLabel;
  final bool enabled;
  final bool active;
  final bool loading;
  final String disabledReason;
  final VoidCallback onTap;

  const _OfficialSmallControlButton({
    required this.icon,
    required this.label,
    this.subLabel,
    required this.enabled,
    required this.active,
    required this.loading,
    required this.disabledReason,
    required this.onTap,
  });

  @override
  State<_OfficialSmallControlButton> createState() =>
      _OfficialSmallControlButtonState();
}

class _OfficialSmallControlButtonState
    extends State<_OfficialSmallControlButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _showDisabledReason() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.disabledReason),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.enabled && !widget.loading;
    final color = widget.active ? ReplicaColors.blue : ReplicaColors.muted;
    final background = widget.active
        ? ReplicaColors.blue.withValues(alpha: _pressed ? 0.16 : 0.1)
        : _pressed
        ? _officialPressedBg
        : const Color(0xFFF0F0F5);
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.96 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
            onTapUp: interactive ? (_) => _setPressed(false) : null,
            onTapCancel: interactive ? () => _setPressed(false) : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.loading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  else
                    Icon(widget.icon, color: color, size: 26),
                  const SizedBox(height: 6),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.enabled ? ReplicaColors.muted : Colors.grey,
                    ),
                  ),
                  if (widget.subLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: ReplicaColors.subtle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
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
        border: Border.all(
          color: enabled ? color.withValues(alpha: 0.18) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: enabled ? color : _phoneControlPrimaryPressed,
              borderRadius: BorderRadius.circular(_phoneControlRadius),
            ),
            child: Icon(icon, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: ReplicaColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ReplicaColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 104, maxWidth: 132),
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
    pageBuilder: (_) =>
        const LocationPage(initialTab: LocationInitialTab.fence),
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

class _QuickEditButton extends StatefulWidget {
  final VoidCallback onTap;

  const _QuickEditButton({required this.onTap});

  @override
  State<_QuickEditButton> createState() => _QuickEditButtonState();
}

class _QuickEditButtonState extends State<_QuickEditButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.92 : 1,
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
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: _pressed ? AppColors.primaryDark : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: Icon(Icons.edit, color: Colors.white, size: 16),
                ),
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
          MaterialPageRoute(
            builder: (_) =>
                const LocationPage(initialTab: LocationInitialTab.fence),
          ),
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
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ReplicaRadii.card),
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
                '功能设置',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ReplicaColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 92,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) => SizedBox(
                  width: 86,
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

class _HomeQuickTile extends StatefulWidget {
  final _HomeQuickItem item;

  const _HomeQuickTile({required this.item});

  @override
  State<_HomeQuickTile> createState() => _HomeQuickTileState();
}

class _HomeQuickTileState extends State<_HomeQuickTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.96 : 1,
      child: Material(
        color: _pressed ? _officialPressedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(ReplicaRadii.card),
        child: InkWell(
          onTap: () {
            _setPressed(false);
            HapticFeedback.mediumImpact();
            widget.item.onTap();
          },
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          borderRadius: BorderRadius.circular(ReplicaRadii.card),
          child: SizedBox(
            height: 92,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _pressed ? Colors.white : const Color(0xFFF0F0F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.item.icon,
                    size: 23,
                    color: widget.item.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.item.label,
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
