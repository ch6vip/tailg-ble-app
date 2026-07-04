import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';
import 'package:tailg_ble_app/theme/app_motion.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

/// Official Tailg control card: two quick placeholders on the left, the
/// slide-style power control plus find/lock actions on the right.
class ControlCard extends StatefulWidget {
  const ControlCard({
    super.key,
    this.onPowerOn,
    this.onFind,
    this.onLock,
    this.powered = false,
    this.busy = false,
  });

  final VoidCallback? onPowerOn;
  final VoidCallback? onFind;
  final VoidCallback? onLock;
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
    final leftWidth = wide ? 90.0 : 82.0;
    final panelHeight = wide ? 170.0 : 160.0;
    final busy = widget.busy;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: leftWidth,
                height: panelHeight,
                child: _OfficialQuickSlots(enabled: !busy),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: panelHeight,
                  child: _OfficialControlPanel(
                    powered: widget.powered,
                    busy: busy,
                    onPowerOn: () {
                      HapticFeedback.heavyImpact();
                      widget.onPowerOn?.call();
                    },
                    onFind: widget.onFind,
                    onLock: widget.onLock,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfficialPanelCard extends StatelessWidget {
  const _OfficialPanelCard({required this.child, required this.padding});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F1F1F).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _OfficialControlPanel extends StatelessWidget {
  const _OfficialControlPanel({
    required this.powered,
    required this.busy,
    required this.onPowerOn,
    this.onFind,
    this.onLock,
  });

  final bool powered;
  final bool busy;
  final VoidCallback onPowerOn;
  final VoidCallback? onFind;
  final VoidCallback? onLock;

  @override
  Widget build(BuildContext context) {
    return _OfficialPanelCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child: _PowerKnob(
              powered: powered,
              busy: busy,
              onPowerOn: onPowerOn,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PanelCommand(
                  asset: 'assets/official_tailg/ic_control_iv_find.png',
                  icon: Icons.campaign_outlined,
                  label: '寻车',
                  onTap: busy ? null : onFind,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PanelCommand(
                  asset: 'assets/official_tailg/ic_control_iv_lock.png',
                  icon: Icons.lock_outline,
                  label: '设防',
                  onTap: busy ? null : onLock,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelCommand extends StatelessWidget {
  const _PanelCommand({
    required this.asset,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final String asset;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      enabled: onTap != null,
      onTap: onTap,
      haptic: false,
      semanticsLabel: label,
      semanticsButton: true,
      semanticsEnabled: onTap != null,
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              asset,
              width: 22,
              height: 22,
              errorBuilder: (_, __, ___) =>
                  Icon(icon, size: 22, color: AppColors.brandRed),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.officialTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficialQuickSlots extends StatelessWidget {
  const _OfficialQuickSlots({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _OfficialPanelCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child: _QuickAddSlot(semanticsLabel: '快捷功能1', enabled: enabled),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: _QuickAddSlot(
                    semanticsLabel: '快捷功能2',
                    enabled: enabled,
                  ),
                ),
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: _QuickEditButton(enabled: enabled),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAddSlot extends StatelessWidget {
  const _QuickAddSlot({required this.semanticsLabel, required this.enabled});

  final String semanticsLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      enabled: false,
      onTap: null,
      haptic: false,
      pressedScale: AppMotion.pressScale,
      duration: AppMotion.micro,
      curve: AppMotion.pressCurve,
      semanticsLabel: semanticsLabel,
      semanticsButton: true,
      semanticsEnabled: false,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF0F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'assets/official_tailg/ic_control_quick_add.webp',
                width: 26,
                height: 26,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.add, size: 24, color: AppColors.brandRed),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickEditButton extends StatelessWidget {
  const _QuickEditButton({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      enabled: false,
      onTap: null,
      haptic: false,
      semanticsLabel: '编辑快捷功能',
      semanticsButton: true,
      semanticsEnabled: false,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Align(
            alignment: Alignment.bottomRight,
            child: Image.asset(
              'assets/official_tailg/ic_quick_edit_entrance.webp',
              width: 22,
              height: 22,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.edit,
                size: 18,
                color: AppColors.officialTextMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Central slide-style power control.
class _PowerKnob extends StatefulWidget {
  const _PowerKnob({required this.powered, this.busy = false, this.onPowerOn});
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

  void _onPointerDown(PointerDownEvent event) {
    if (widget.busy ||
        _holding ||
        (event.kind == PointerDeviceKind.mouse &&
            event.buttons != kPrimaryButton)) {
      return;
    }
    _fired = false;
    HapticFeedback.lightImpact();
    setState(() => _holding = true);
    _ctrl.forward();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_holding) return;
    final size = context.size ?? const Size(88, 64);
    final knobBounds = widget.powered
        ? Rect.fromLTWH(size.width - 70, 0, 70, size.height)
        : Rect.fromLTWH(0, 0, 70, size.height);
    if (!knobBounds.contains(event.localPosition)) {
      _finish();
    }
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
    final coreColor = widget.powered ? AppColors.brandRed : AppColors.brandRed;
    final semanticLabel = widget.busy
        ? '电源：处理中'
        : widget.powered
        ? '电源：长按熄火'
        : '电源：长按开机';
    final semanticAction = widget.busy || widget.onPowerOn == null
        ? null
        : () {
            HapticFeedback.heavyImpact();
            widget.onPowerOn?.call();
          };

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: semanticAction != null,
      onLongPress: semanticAction,
      child: ExcludeSemantics(
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: AnimatedBuilder(
            animation: Listenable.merge([_progress, _busyPulse]),
            builder: (_, child) {
              final progress = widget.busy
                  ? _busyPulse.value
                  : _holding
                  ? _progress.value
                  : widget.powered
                  ? 1.0
                  : 0.0;
              return Container(
                height: double.infinity,
                constraints: const BoxConstraints(minHeight: 64),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF0F5),
                  borderRadius: BorderRadius.circular(15),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: widget.powered
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: coreColor.withValues(alpha: 0.16),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      widget.busy
                          ? '执行中...'
                          : widget.powered
                          ? '左滑关闭'
                          : '右滑启动',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.officialTextMuted,
                      ),
                    ),
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: widget.powered
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 52,
                        height: 52,
                        margin: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: coreColor.withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: widget.busy
                            ? const Padding(
                                padding: EdgeInsets.all(15),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppColors.brandRed,
                                ),
                              )
                            : Icon(
                                widget.powered
                                    ? Icons.power_off
                                    : Icons.power_settings_new,
                                color: AppColors.brandRed,
                                size: 24,
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
