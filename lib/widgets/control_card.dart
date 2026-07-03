import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';
import 'package:tailg_ble_app/theme/app_motion.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

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
                  disabled: busy,
                  onTap: () {
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
                  disabled: busy,
                  onTap: () {
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
                  onTap: () =>
                      widget.onToggleProximity?.call(!widget.proximityEnabled),
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
    this.disabled = false,
    this.onTap,
  });

  final double size;
  final IconData icon;
  final String label;
  final Color color;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveOnTap = disabled ? null : onTap;
    return AppPressable(
      enabled: effectiveOnTap != null,
      onTap: effectiveOnTap,
      pressedScale: AppMotion.pressScale,
      duration: AppMotion.micro,
      curve: AppMotion.pressCurve,
      haptic: false,
      child: AnimatedOpacity(
        opacity: disabled ? 0.45 : 1.0,
        duration: const Duration(milliseconds: 200),
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

class _PowerKnobState extends State<_PowerKnob> with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;
  bool _holding = false;
  bool _fired = false;

  // Busy-state pulsing ring
  late final AnimationController _busyPulseCtrl;
  late final Animation<double> _busyPulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppMotion.longPressHold)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _fired = true;
          HapticFeedback.heavyImpact();
          widget.onPowerOn?.call();
        }
      });
    _progress = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: AppMotion.progressCurve));

    _busyPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _busyPulse = Tween(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _busyPulseCtrl, curve: AppMotion.pulseCurve),
    );
    _syncBusyPulse();
  }

  @override
  void didUpdateWidget(covariant _PowerKnob oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy) {
      _syncBusyPulse();
    }
  }

  void _syncBusyPulse() {
    if (widget.busy) {
      if (!_busyPulseCtrl.isAnimating) {
        _busyPulseCtrl.repeat(reverse: true);
      }
    } else {
      _busyPulseCtrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.stop();
    _busyPulseCtrl.stop();
    _ctrl.dispose();
    _busyPulseCtrl.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent _) {
    if (widget.busy) return;
    _fired = false;
    HapticFeedback.lightImpact();
    setState(() => _holding = true);
    _ctrl.forward();
  }

  void _onPointerUp(PointerUpEvent _) {
    if (!_holding) return;
    _finish();
  }

  void _onPointerCancel(PointerCancelEvent _) {
    if (!_holding) return;
    _finish();
  }

  void _finish() {
    setState(() => _holding = false);
    // If already auto-fired at 100%, don't fire again
    if (!_fired) {
      // Released early? Keep the visual feedback
    }
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
            animation: Listenable.merge([_progress, _busyPulse]),
            builder: (_, child) {
              final busyGlowAlpha = widget.busy ? _busyPulse.value : 0.0;
              return SizedBox(
                width: sz,
                height: sz,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Busy pulsing glow ring
                    if (widget.busy)
                      Container(
                        width: sz * 1.12,
                        height: sz * 1.12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.energyGreen.withValues(
                              alpha: busyGlowAlpha,
                            ),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.energyGreen.withValues(
                                alpha: busyGlowAlpha * 0.4,
                              ),
                              blurRadius: sz * 0.2,
                            ),
                          ],
                        ),
                      ),
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
                      child: widget.busy
                          ? SizedBox(
                              width: sz * 0.3,
                              height: sz * 0.3,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              widget.powered
                                  ? Icons.power_off
                                  : Icons.power_settings_new,
                              color: Colors.white,
                              size: sz * 0.3,
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            widget.busy
                ? '处理中…'
                : widget.powered
                ? '长按熄火'
                : '长按开机',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: widget.powered && !widget.busy
                  ? AppColors.danger
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.busy ? '请稍候' : '按住 1.2 秒',
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Sub-control circle button (proximity unlock, rider management, dashboard).
class _SubControl extends StatefulWidget {
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
  State<_SubControl> createState() => _SubControlState();
}

class _SubControlState extends State<_SubControl> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (!mounted || _pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.active
        ? widget.color.withValues(alpha: 0.14)
        : _pressed
        ? AppColors.surfaceContainerHigh
        : AppColors.surfaceContainerLow;
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _setPressed(true) : null,
      onTapUp: widget.onTap != null ? (_) => _setPressed(false) : null,
      onTapCancel: widget.onTap != null ? () => _setPressed(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? AppMotion.pressScale : 1.0,
        duration: AppMotion.micro,
        curve: AppMotion.pressCurve,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(
                widget.icon,
                size: 20,
                color: widget.active ? widget.color : AppColors.inkBtn,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
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
