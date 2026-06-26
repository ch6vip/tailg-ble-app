import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';

/// v8 floating control card — Ninebot-style central ink-button
/// with long-press power ring progress.
///
/// Aligns with `design_v2/home_v8_ninebot.html` `.control-card` section.
class ControlCard extends StatefulWidget {
  const ControlCard({
    super.key,
    this.onSeatOpen,
    this.onPowerOn,
    this.onMore,
    this.onToggleProximity,
    this.onRiderManagement,
    this.onSuperDashboard,
    this.proximityEnabled = false,
    this.powered = false,
    this.busy = false,
  });

  final VoidCallback? onSeatOpen;
  final VoidCallback? onPowerOn;
  final VoidCallback? onMore;
  final ValueChanged<bool>? onToggleProximity;
  final VoidCallback? onRiderManagement;
  final VoidCallback? onSuperDashboard;
  final bool proximityEnabled;
  final bool powered;
  final bool busy;

  @override
  State<ControlCard> createState() => _ControlCardState();
}

class _ControlCardState extends State<ControlCard> {
  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final wide = screenW >= 360;
    final sideSize = wide ? 52.0 : 44.0;
    final knobSize = wide ? 88.0 : 70.0;
    final busy = widget.busy;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF182740).withValues(alpha: 0.1),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Opacity(
        opacity: busy ? 0.55 : 1.0,
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Main control row: seat | power knob | more
            Padding(
              padding: EdgeInsets.symmetric(horizontal: wide ? 16 : 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SideButton(
                    size: sideSize,
                    icon: Icons.inventory_2_outlined,
                    label: '打开座桶',
                    color: AppColors.inkBtn,
                    onTap: () {
                      if (busy) return;
                      HapticFeedback.mediumImpact();
                      widget.onSeatOpen?.call();
                    },
                  ),
                  _PowerKnob(
                    size: knobSize,
                    powered: widget.powered,
                    busy: busy,
                    onPowerOn: () {
                      HapticFeedback.heavyImpact();
                      widget.onPowerOn?.call();
                    },
                  ),
                  _SideButton(
                    size: sideSize,
                    icon: Icons.apps,
                    label: '更多功能',
                    color: AppColors.inkBtn,
                    onTap: () {
                      if (busy) return;
                      HapticFeedback.selectionClick();
                      widget.onMore?.call();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 0.5, color: Color(0x0A000000)),
            // Sub control row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SubControl(
                    icon: Icons.bluetooth_connected,
                    label: '感应解锁',
                    color: AppColors.energyGreen,
                    active: widget.proximityEnabled,
                    onTap: () => widget.onToggleProximity?.call(
                      !widget.proximityEnabled,
                    ),
                  ),
                  _SubControl(
                    icon: Icons.people_outline,
                    label: '用车人',
                    color: AppColors.accentViolet,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onRiderManagement?.call();
                    },
                  ),
                  _SubControl(
                    icon: Icons.dashboard_outlined,
                    label: '超级仪表',
                    color: AppColors.accentSky,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onSuperDashboard?.call();
                    },
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

/// Side action button (seat bucket / more functions).
class _SideButton extends StatelessWidget {
  const _SideButton({
    this.size = 52,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final double size;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: size * 0.45, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Central power knob with long-press ring progress (Ninebot-style).
class _PowerKnob extends StatefulWidget {
  const _PowerKnob({
    this.size = 88,
    required this.powered,
    this.busy = false,
    this.onPowerOn,
  });
  final double size;
  final bool powered;
  final bool busy;
  final VoidCallback? onPowerOn;

  @override
  State<_PowerKnob> createState() => _PowerKnobState();
}

class _PowerKnobState extends State<_PowerKnob>
    with SingleTickerProviderStateMixin {
  static const _holdMs = 1200;
  late final AnimationController _ctrl;
  late final Animation<double> _progress;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _holdMs),
    );
    _progress = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent _) {
    if (widget.busy) return;
    HapticFeedback.lightImpact();
    setState(() => _holding = true);
    _ctrl.forward();
  }

  void _onPointerUp(PointerUpEvent _) {
    if (!_holding) return;
    setState(() => _holding = false);
    if (_ctrl.value >= 0.95) {
      widget.onPowerOn?.call();
    }
    _ctrl.reverse();
  }

  void _onPointerCancel(PointerCancelEvent _) {
    if (!_holding) return;
    setState(() => _holding = false);
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.powered
        ? AppColors.energyGreen
        : AppColors.inkBtn2;
    final coreColor = widget.powered ? AppColors.energyGreen : AppColors.inkBtn;
    final sz = widget.size;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _progress,
            builder: (_, child) => SizedBox(
              width: sz,
              height: sz,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(sz, sz),
                    painter: _RingPainter(
                      color: ringColor.withValues(alpha: 0.15),
                      progress: 1.0,
                    ),
                  ),
                  CustomPaint(
                    size: Size(sz, sz),
                    painter: _RingPainter(
                      color: AppColors.energyGreen,
                      progress: widget.powered ? 1.0 : _progress.value,
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _holding ? sz * 0.70 : sz * 0.73,
                    height: _holding ? sz * 0.70 : sz * 0.73,
                    decoration: BoxDecoration(
                      color: coreColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: coreColor.withValues(alpha: 0.28),
                          blurRadius: sz * 0.23,
                          offset: Offset(0, sz * 0.09),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.power_settings_new,
                      color: Colors.white,
                      size: sz * 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.powered ? '已通电' : '长按开机',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: widget.powered
                  ? AppColors.energyGreen
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '按住 1.2 秒',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Sub-control circle button (proximity unlock, rider management, dashboard).
class _SubControl extends StatelessWidget {
  const _SubControl({
    required this.icon,
    required this.label,
    required this.color,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? color.withValues(alpha: 0.14)
        : AppColors.surfaceContainerLow;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(
              icon,
              size: 20,
              color: active ? color : AppColors.inkBtn,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ring progress painter for the power knob.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.color, required this.progress});
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.44;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.color != color || old.progress != progress;
}
