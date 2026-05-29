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
import 'vehicle_message_page.dart';
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

String _formatMetricNumber(num value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.05) return rounded.toInt().toString();
  return value.toStringAsFixed(1);
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
        return StreamBuilder<List<VehicleProfile>>(
          stream: vehicleStore.vehiclesStream,
          initialData: vehicleStore.vehicles,
          builder: (context, vehicleSnapshot) {
            final vehicles = vehicleSnapshot.data ?? const <VehicleProfile>[];
            return StreamBuilder<OfficialCloudState>(
              stream: officialCloudService.stateStream,
              initialData: officialCloudService.state,
              builder: (context, cloudSnapshot) {
                final cloudState =
                    cloudSnapshot.data ?? officialCloudService.state;
                final hasLocalVehicle =
                    vehicles.isNotEmpty || vehicleStore.defaultVehicle != null;
                final hasCloudVehicle =
                    cloudState.signedIn && cloudState.selectedVehicle != null;
                final hasTransientDevice =
                    connectionManager.device != null ||
                    connState != ble.ConnectionState.disconnected;
                final showUnboundHome =
                    !hasLocalVehicle && !hasCloudVehicle && !hasTransientDevice;

                return Scaffold(
                  backgroundColor: _pageBg,
                  body: SafeArea(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(
                        bottom: AppNav.contentBottomPadding,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: showUnboundHome
                            ? const _UnboundVehicleHome()
                            : Column(
                                key: const ValueKey('bound-home'),
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
                  ),
                );
              },
            );
          },
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

class _UnboundVehicleHome extends StatelessWidget {
  const _UnboundVehicleHome();

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('unbound-home'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: _UnboundLogoMark(),
        ),
        const SizedBox(height: 54),
        const Text(
          '未绑定车辆',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 36,
            height: 1.05,
            fontWeight: FontWeight.w800,
            color: ReplicaColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '绑定车辆后可使用蓝牙控车、定位、轨迹和电池服务',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: ReplicaColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        const _UnboundBanner(),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              _OfficialActionButton(
                label: '绑定设备',
                foreground: Colors.white,
                background: const Color(0xFFF11C2C),
                borderColor: const Color(0xFFF11C2C),
                onTap: () => openScanTab(context),
              ),
              const SizedBox(height: 12),
              _OfficialActionButton(
                label: '虚拟体验',
                foreground: const Color(0xFFF11C2C),
                background: ReplicaColors.pageBg,
                borderColor: const Color(0xFFF11C2C),
                onTap: () => _showSnack(context, '虚拟体验页待复刻，当前可先登录官方账号查看云端车辆'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GaragePage()),
                ),
                child: const Text(
                  '绑定说明',
                  style: TextStyle(
                    color: ReplicaColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _OfficialTextLinkRow(
                icon: Icons.cloud_done_outlined,
                label: '已绑定官方账号？登录后自动显示车辆',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OfficialCloudPage()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _UnboundLogoMark extends StatelessWidget {
  const _UnboundLogoMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.electric_bike,
            size: 25,
            color: Color(0xFFF11C2C),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'TAILG',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: ReplicaColors.ink,
          ),
        ),
      ],
    );
  }
}

class _UnboundBanner extends StatelessWidget {
  const _UnboundBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Container(
            height: 230,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFF8FAFF),
                          Color(0xFFE9F0FF),
                          Color(0xFFFFF4F4),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: const _UnboundBannerPainter()),
                ),
                const Positioned(
                  left: 18,
                  top: 18,
                  child: _UnboundBannerChip(text: '蓝牙控车'),
                ),
                const Positioned(
                  right: 18,
                  top: 18,
                  child: _UnboundBannerChip(text: '云端车辆'),
                ),
                const Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Text(
                    '绑定设备后同步车辆状态',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: ReplicaColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BannerDot(active: true),
              SizedBox(width: 6),
              _BannerDot(active: false),
              SizedBox(width: 6),
              _BannerDot(active: false),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnboundBannerChip extends StatelessWidget {
  final String text;

  const _UnboundBannerChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: ReplicaColors.muted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BannerDot extends StatelessWidget {
  final bool active;

  const _BannerDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: active ? 28 : 8,
      height: 6,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF11C2C) : const Color(0xFFD8DAE2),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _OfficialActionButton extends StatefulWidget {
  final String label;
  final Color foreground;
  final Color background;
  final Color borderColor;
  final VoidCallback onTap;

  const _OfficialActionButton({
    required this.label,
    required this.foreground,
    required this.background,
    required this.borderColor,
    required this.onTap,
  });

  @override
  State<_OfficialActionButton> createState() => _OfficialActionButtonState();
}

class _OfficialActionButtonState extends State<_OfficialActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      scale: _pressed ? 0.97 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 54,
        decoration: BoxDecoration(
          color: _pressed ? _officialPressedBg : widget.background,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _pressed ? _officialPressedBg : widget.borderColor,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: () {
              _setPressed(false);
              HapticFeedback.mediumImpact();
              widget.onTap();
            },
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            borderRadius: BorderRadius.circular(15),
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _pressed ? ReplicaColors.secondary : widget.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfficialTextLinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OfficialTextLinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: ReplicaColors.blue),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ReplicaColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnboundBannerPainter extends CustomPainter {
  const _UnboundBannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * 0.55;
    final accent = const Color(0xFF5596FF);
    final red = const Color(0xFFF11C2C);
    final shadow = Paint()
      ..color = const Color(0xFFDDE3EC).withValues(alpha: 0.72);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.78),
        width: size.width * 0.78,
        height: 22,
      ),
      shadow,
    );

    final wheelPaint = Paint()
      ..color = const Color(0xFF252525)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    final rimPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final leftWheel = Offset(size.width * 0.28, centerY + 34);
    final rightWheel = Offset(size.width * 0.72, centerY + 34);
    final radius = math.min(size.width, size.height) * 0.12;
    for (final wheel in [leftWheel, rightWheel]) {
      canvas.drawCircle(wheel, radius, wheelPaint);
      canvas.drawCircle(wheel, radius * 0.62, rimPaint);
    }

    final frame = Path()
      ..moveTo(leftWheel.dx, leftWheel.dy)
      ..lineTo(size.width * 0.42, centerY - 20)
      ..lineTo(size.width * 0.57, leftWheel.dy)
      ..lineTo(rightWheel.dx, rightWheel.dy)
      ..moveTo(size.width * 0.42, centerY - 20)
      ..lineTo(size.width * 0.53, centerY - 64)
      ..lineTo(size.width * 0.66, centerY - 34);
    final framePaint = Paint()
      ..color = const Color(0xFF2A2D35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(frame, framePaint);

    final seatPaint = Paint()
      ..color = const Color(0xFF2A2D35)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.51, centerY - 64),
      Offset(size.width * 0.41, centerY - 68),
      seatPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.65, centerY - 35),
      Offset(size.width * 0.78, centerY - 46),
      seatPaint,
    );

    final batteryRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.43, centerY - 2, size.width * 0.23, 34),
      const Radius.circular(12),
    );
    canvas.drawRRect(batteryRect, Paint()..color = const Color(0xFF121418));
    canvas.drawRRect(
      batteryRect.deflate(5),
      Paint()..color = red.withValues(alpha: 0.78),
    );
  }

  @override
  bool shouldRepaint(covariant _UnboundBannerPainter oldDelegate) => false;
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                          const SizedBox(width: 8),
                          const Icon(Icons.keyboard_arrow_down, size: 20),
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
            final mileage = cloudVehicle?.mileage;
            final rangeText = mileage != null
                ? _formatMetricNumber(mileage)
                : battery != null
                ? '${(battery * _kmPerPercent).round()}'
                : '--';
            final rangeLabel = mileage != null ? '累计里程' : '预估里程';

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
                      label: rangeLabel,
                      value: rangeText,
                      unit: rangeText == '--' ? '' : 'km',
                    ),
                  ),
                  const SizedBox(width: 14),
                  _HomeChannelPill(
                    connState: connState,
                    cloudVehicle: cloudVehicle,
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

class _HomeChannelPill extends StatelessWidget {
  final ble.ConnectionState connState;
  final OfficialVehicle? cloudVehicle;

  const _HomeChannelPill({required this.connState, required this.cloudVehicle});

  @override
  Widget build(BuildContext context) {
    final ready = connState == ble.ConnectionState.ready;
    final connecting =
        connState == ble.ConnectionState.connecting ||
        connState == ble.ConnectionState.reconnecting;
    final cloudReady = cloudVehicle != null;
    final color = ready
        ? AppColors.success
        : connecting
        ? AppColors.warning
        : cloudReady
        ? ReplicaColors.blue
        : ReplicaColors.muted;
    final text = ready
        ? 'BLE'
        : connecting
        ? '连接中'
        : cloudReady
        ? '云端'
        : '离线';
    final icon = ready
        ? Icons.bluetooth_connected
        : connecting
        ? Icons.sync
        : cloudReady
        ? Icons.cloud_done_outlined
        : Icons.bluetooth_disabled;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(ReplicaRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
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
    final effectiveColor = switch (effective) {
      'BLE' => AppColors.success,
      '云端' => ReplicaColors.blue,
      _ => ReplicaColors.muted,
    };
    final effectiveIcon = switch (effective) {
      'BLE' => Icons.bluetooth_connected,
      '云端' => Icons.cloud_done_outlined,
      _ => Icons.link_off,
    };
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
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: effectiveColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(effectiveIcon, size: 13, color: effectiveColor),
                          const SizedBox(width: 4),
                          Text(
                            effective,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: effectiveColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status,
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
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Icon(
              enabled ? Icons.touch_app_outlined : Icons.link_off,
              key: ValueKey(enabled),
              size: 21,
              color: enabled ? ReplicaColors.blue : ReplicaColors.muted,
            ),
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
              loadingLabel: '执行中',
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
                    loadingLabel: '执行中',
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
            disabledReason: disabledReason,
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
                  loadingLabel: '寻车中',
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
                  loadingLabel: lockLabel == '解锁' ? '解锁中' : '设防中',
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
  final String loadingLabel;
  final bool enabled;
  final bool active;
  final bool loading;
  final String disabledReason;
  final VoidCallback onTap;

  const _OfficialSmallControlButton({
    required this.icon,
    required this.label,
    this.subLabel,
    this.loadingLabel = '执行中',
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
        child: Opacity(
          opacity: widget.enabled || widget.loading ? 1 : 0.54,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.loading)
                      _PulseActionIcon(icon: widget.icon, color: color)
                    else
                      Icon(widget.icon, color: color, size: 26),
                    const SizedBox(height: 6),
                    Text(
                      widget.loading ? widget.loadingLabel : widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: widget.enabled
                            ? ReplicaColors.muted
                            : Colors.grey,
                      ),
                    ),
                    if (widget.subLabel != null && !widget.loading) ...[
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
  final String disabledReason;
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
    required this.disabledReason,
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
                  enabled ? hint : disabledReason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: enabled ? ReplicaColors.muted : AppColors.warning,
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

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _showUnavailable(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _HomeQuickItem(
        icon: Icons.location_on_outlined,
        label: '车辆位置',
        accent: AppColors.info,
        onTap: () => _open(context, const LocationPage()),
      ),
      _HomeQuickItem(
        icon: Icons.tune,
        label: '车辆设置',
        accent: _phoneControlPrimary,
        onTap: () => _open(context, const VehicleSettingsPage()),
      ),
      _HomeQuickItem(
        icon: Icons.location_searching,
        label: '电子围栏',
        accent: AppColors.success,
        onTap: () => _open(
          context,
          const LocationPage(initialTab: LocationInitialTab.fence),
        ),
      ),
      _HomeQuickItem(
        icon: Icons.ios_share,
        label: '分享用车',
        accent: const Color(0xFF7B61FF),
        onTap: () => _open(context, const ShareBikePage()),
      ),
      _HomeQuickItem(
        icon: Icons.graphic_eq,
        label: '音效设置',
        accent: const Color(0xFF00A896),
        onTap: () => _open(context, const QgjSoundEffectsPage()),
      ),
      _HomeQuickItem(
        icon: Icons.nfc,
        label: 'NFC钥匙',
        accent: const Color(0xFF7B61FF),
        onTap: () => _open(context, const NfcKeyPage()),
      ),
      _HomeQuickItem(
        icon: Icons.route_outlined,
        label: '骑行记录',
        accent: const Color(0xFFFF8A00),
        onTap: () => _open(
          context,
          const LocationPage(initialTab: LocationInitialTab.travel),
        ),
      ),
    ];

    return StreamBuilder<List<VehicleProfile>>(
      stream: vehicleStore.vehiclesStream,
      initialData: vehicleStore.vehicles,
      builder: (context, vehicleSnapshot) {
        final localVehicle = vehicleStore.defaultVehicle;
        return StreamBuilder<OfficialCloudState>(
          stream: officialCloudService.stateStream,
          initialData: officialCloudService.state,
          builder: (context, cloudSnapshot) {
            final cloudState = cloudSnapshot.data ?? officialCloudService.state;
            final location = cloudState.vehicleLocation;
            final locationText = location != null && location.hasData
                ? (location.bleConnectAddress.isNotEmpty
                      ? location.bleConnectAddress
                      : '${location.bleConnectLat}, ${location.bleConnectLng}')
                : localVehicle?.lastLocation?.coordinateText ?? '暂无车辆位置';
            final locationTime = location?.bleConnectTime.isNotEmpty == true
                ? location!.bleConnectTime
                : localVehicle?.lastLocation?.recordedAt
                          .toString()
                          .split('.')
                          .first ??
                      '待读取';
            final travelCount = cloudState.travelDays.fold<int>(
              0,
              (sum, day) => sum + day.records.length,
            );
            final totalMileage = cloudState.travelDays
                .map((day) => day.totalMileage)
                .firstWhere((value) => value.isNotEmpty, orElse: () => '');
            final hasGps =
                cloudState.selectedVehicle?.imeiGps.isNotEmpty == true;
            final addGpsTitle = hasGps ? '智能控车' : '可添加GPS';
            final addGpsSubtitle = hasGps ? '远程定位 防盗通知 云端控车' : '可定位 防盗通知 远程控车等';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _FunctionSettingsCard(items: items),
                  const SizedBox(height: 12),
                  _VehicleLocationServiceCard(
                    address: locationText,
                    time: locationTime,
                    loading: cloudState.vehicleLocationLoading,
                    onTap: () => _open(context, const LocationPage()),
                  ),
                  const SizedBox(height: 12),
                  _OfficialServiceBannerCard(
                    icon: Icons.route_outlined,
                    title: '历史轨迹',
                    subtitle: travelCount > 0
                        ? '今日骑行记录 $travelCount 条'
                        : totalMileage.isNotEmpty
                        ? '累计轨迹 ${totalMileage}km'
                        : '今日骑行记录',
                    accent: const Color(0xFFFF8A00),
                    onTap: () => _open(
                      context,
                      const LocationPage(initialTab: LocationInitialTab.travel),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _OfficialServiceBannerCard(
                    icon: Icons.add_location_alt_outlined,
                    title: addGpsTitle,
                    subtitle: addGpsSubtitle,
                    accent: ReplicaColors.blue,
                    onTap: () => _open(context, const OfficialCloudPage()),
                  ),
                  const SizedBox(height: 12),
                  _OfficialSettingsServiceCard(
                    onSettingsTap: () =>
                        _open(context, const VehicleSettingsPage()),
                    onFenceTap: () => _open(
                      context,
                      const LocationPage(initialTab: LocationInitialTab.fence),
                    ),
                    onShareTap: () => _open(context, const ShareBikePage()),
                  ),
                  const SizedBox(height: 12),
                  _SoundEffectsServiceCard(
                    onTap: () => _open(context, const QgjSoundEffectsPage()),
                  ),
                  const SizedBox(height: 12),
                  _NfcServiceCard(
                    onTap: () => _open(context, const NfcKeyPage()),
                  ),
                  const SizedBox(height: 12),
                  _BleRenewalServiceCard(
                    onTap: () =>
                        _showUnavailable(context, '蓝牙续费涉及官方支付与服务权益，当前保持只读占位'),
                  ),
                  const SizedBox(height: 12),
                  _ChargingStationServiceCard(
                    onTap: () =>
                        _showUnavailable(context, '台铃充电站涉及官方站点与交易接口，当前保持只读占位'),
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

class _FunctionSettingsCard extends StatelessWidget {
  final List<_HomeQuickItem> items;

  const _FunctionSettingsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
      decoration: _cardDecoration,
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
    return _OfficialPressable(
      onTap: item.onTap,
      radius: ReplicaRadii.card,
      background: Colors.transparent,
      pressedBackground: _officialPressedBg,
      shadow: false,
      child: SizedBox(
        height: 92,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, size: 23, color: item.accent),
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
    );
  }
}

class _VehicleLocationServiceCard extends StatelessWidget {
  final String address;
  final String time;
  final bool loading;
  final VoidCallback onTap;

  const _VehicleLocationServiceCard({
    required this.address,
    required this.time,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      onTap: onTap,
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ServiceCardHeader(
                  title: '车辆定位',
                  trailing: loading ? '刷新中' : time,
                ),
                const SizedBox(height: 8),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ReplicaColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Expanded(child: _MiniMapPreview()),
              ],
            ),
            if (loading)
              const Positioned(
                right: 0,
                bottom: 0,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfficialServiceBannerCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _OfficialServiceBannerCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      onTap: onTap,
      child: SizedBox(
        height: 100,
        child: Stack(
          children: [
            Positioned.fill(
              child: _SweepHighlight(color: accent.withValues(alpha: 0.2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _ServiceIconBox(icon: icon, color: accent),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ServiceTitle(title),
                        const SizedBox(height: 7),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: ReplicaColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 22,
                    color: ReplicaColors.muted,
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

class _OfficialSettingsServiceCard extends StatelessWidget {
  final VoidCallback onSettingsTap;
  final VoidCallback onFenceTap;
  final VoidCallback onShareTap;

  const _OfficialSettingsServiceCard({
    required this.onSettingsTap,
    required this.onFenceTap,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 158,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ServiceTitle('功能设置'),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _ServiceSettingButton(
                    icon: Icons.tune,
                    label: '车辆设置',
                    color: ReplicaColors.blue,
                    onTap: onSettingsTap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ServiceSettingButton(
                    icon: Icons.location_searching,
                    label: '电子围栏',
                    color: AppColors.success,
                    onTap: onFenceTap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ServiceSettingButton(
                    icon: Icons.ios_share,
                    label: '分享用车',
                    color: const Color(0xFF7B61FF),
                    onTap: onShareTap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceSettingButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ServiceSettingButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      onTap: onTap,
      radius: 10,
      background: Colors.white,
      pressedBackground: _officialPressedBg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ServiceIconBox(icon: icon, color: color, size: 42),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: ReplicaColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundEffectsServiceCard extends StatelessWidget {
  final VoidCallback onTap;

  const _SoundEffectsServiceCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      onTap: onTap,
      background: const Color(0xFF20242B),
      pressedBackground: const Color(0xFF343943),
      child: SizedBox(
        height: 96,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: const _SoundWavePainter(color: Color(0xFF5596FF)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  _ServiceIconBox(
                    icon: Icons.graphic_eq,
                    color: Color(0xFF5596FF),
                    dark: true,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '音效设置',
                          style: TextStyle(
                            fontSize: 17,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'QGJ 个性化提示音',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFB8C0CC),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 22, color: Colors.white70),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NfcServiceCard extends StatelessWidget {
  final VoidCallback onTap;

  const _NfcServiceCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      onTap: onTap,
      child: Container(
        height: 112,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const _ServiceIconBox(
              icon: Icons.nfc,
              color: Color(0xFF7B61FF),
              size: 58,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ServiceTitle('NFC钥匙'),
                  const SizedBox(height: 6),
                  const Text(
                    '刷卡骑行新体验',
                    style: TextStyle(
                      fontSize: 13,
                      color: ReplicaColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: const [
                      _MiniHelpChip('手机如何添加'),
                      _MiniHelpChip('智能手表如何添加'),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: ReplicaColors.muted),
          ],
        ),
      ),
    );
  }
}

class _BleRenewalServiceCard extends StatelessWidget {
  final VoidCallback onTap;

  const _BleRenewalServiceCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      onTap: onTap,
      background: const Color(0xFFEFF6FF),
      pressedBackground: _officialPressedBg,
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const _ServiceIconBox(
              icon: Icons.bluetooth_audio,
              color: ReplicaColors.blue,
              size: 48,
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ServiceTitle('蓝牙续费'),
                  SizedBox(height: 7),
                  Text(
                    '充值后智能控车',
                    style: TextStyle(
                      fontSize: 13,
                      color: ReplicaColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: ReplicaColors.blue,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                '续费',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChargingStationServiceCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ChargingStationServiceCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _OfficialPressable(
      onTap: onTap,
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ServiceCardHeader(title: '台铃充电站', trailing: '附近站点'),
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const _ServiceIconBox(
                      icon: Icons.ev_station,
                      color: Color(0xFFFF8A00),
                      size: 58,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '最近充电站',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              color: ReplicaColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '空闲 -- ｜ 占用 --',
                            style: TextStyle(
                              fontSize: 13,
                              color: ReplicaColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey.shade500),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCardHeader extends StatelessWidget {
  final String title;
  final String trailing;

  const _ServiceCardHeader({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ServiceTitle(title)),
        const SizedBox(width: 10),
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  trailing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFAAA9B1),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xFFAAA9B1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceTitle extends StatelessWidget {
  final String text;

  const _ServiceTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 17,
        color: ReplicaColors.ink,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ServiceIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool dark;

  const _ServiceIconBox({
    required this.icon,
    required this.color,
    this.size = 50,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: size * 0.48, color: color),
    );
  }
}

class _MiniHelpChip extends StatelessWidget {
  final String text;

  const _MiniHelpChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF1F1DF1),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OfficialPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color background;
  final Color pressedBackground;
  final double radius;
  final bool shadow;

  const _OfficialPressable({
    required this.child,
    required this.onTap,
    this.background = Colors.white,
    this.pressedBackground = _officialPressedBg,
    this.radius = ReplicaRadii.card,
    this.shadow = true,
  });

  @override
  State<_OfficialPressable> createState() => _OfficialPressableState();
}

class _OfficialPressableState extends State<_OfficialPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      scale: _pressed ? 0.98 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _pressed ? widget.pressedBackground : widget.background,
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: widget.shadow
              ? const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _setPressed(false);
                HapticFeedback.mediumImpact();
                widget.onTap();
              },
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMapPreview extends StatelessWidget {
  const _MiniMapPreview();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _MiniMapPainter()),
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF11C2C).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.location_on,
                  color: Color(0xFFF11C2C),
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFF0F3F8);
    canvas.drawRect(Offset.zero & size, bg);

    final park = Paint()..color = const Color(0xFFDDE7D8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.04,
          size.height * 0.10,
          size.width * 0.35,
          size.height * 0.28,
        ),
        const Radius.circular(16),
      ),
      park,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.62,
          size.height * 0.56,
          size.width * 0.28,
          size.height * 0.32,
        ),
        const Radius.circular(16),
      ),
      park,
    );

    final road = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final mainRoad = Path()
      ..moveTo(-20, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.34,
        size.height * 0.42,
        size.width * 0.56,
        size.height * 0.52,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.62,
        size.width + 20,
        size.height * 0.30,
      );
    canvas.drawPath(mainRoad, road);
    canvas.drawLine(
      Offset(size.width * 0.18, -20),
      Offset(size.width * 0.58, size.height + 20),
      road,
    );

    final line = Paint()
      ..color = const Color(0xFFD9DEE8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 34) {
      canvas.drawLine(Offset(x, 0), Offset(x + 18, size.height), line);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 6), line);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) => false;
}

class _SoundWavePainter extends CustomPainter {
  final Color color;

  const _SoundWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 5; i++) {
      final path = Path();
      final y = size.height * (0.18 + i * 0.14);
      path.moveTo(size.width * 0.46, y);
      path.cubicTo(
        size.width * 0.58,
        y - 16,
        size.width * 0.70,
        y + 18,
        size.width * 0.86,
        y,
      );
      path.cubicTo(
        size.width * 0.93,
        y - 8,
        size.width * 0.98,
        y + 8,
        size.width * 1.04,
        y,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoundWavePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SweepHighlight extends StatefulWidget {
  final Color color;

  const _SweepHighlight({required this.color});

  @override
  State<_SweepHighlight> createState() => _SweepHighlightState();
}

class _SweepHighlightState extends State<_SweepHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dx = -0.35 + _controller.value * 1.7;
        return FractionalTranslation(
          translation: Offset(dx, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                width: 34,
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      widget.color,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PulseActionIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _PulseActionIcon({required this.icon, required this.color});

  @override
  State<_PulseActionIcon> createState() => _PulseActionIconState();
}

class _PulseActionIconState extends State<_PulseActionIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = Curves.easeInOut.transform(_controller.value);
        return SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 24 + value * 8,
                height: 24 + value * 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.08 + value * 0.08),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(widget.icon, color: widget.color, size: 16),
              ),
            ],
          ),
        );
      },
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ReplicaColors.ink,
                  ),
                ),
                if (!enabled) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '需 BLE 连接后切换，云端模式仅展示车辆状态',
                    style: TextStyle(fontSize: 12, color: ReplicaColors.subtle),
                  ),
                ],
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
                          borderRadius: BorderRadius.circular(
                            _phoneControlRadius,
                          ),
                          child: InkWell(
                            onTap: enabled && !selected
                                ? () async {
                                    HapticFeedback.mediumImpact();
                                    await connectionManager.setRidingMode(mode);
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(
                              _phoneControlRadius,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: [
                                  Icon(
                                    icon,
                                    color: selected
                                        ? color
                                        : enabled
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade400,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mode.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: selected
                                          ? color
                                          : enabled
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400,
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
