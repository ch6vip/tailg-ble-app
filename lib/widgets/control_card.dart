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
    this.onUnlock,
    this.onOpenSeat,
    this.onProximityUnlock,
    this.onQuickEdit,
    this.powered = false,
    this.locked,
    this.busy = false,
  });

  final VoidCallback? onPowerOn;
  final VoidCallback? onFind;
  final VoidCallback? onLock;
  final VoidCallback? onUnlock;
  final VoidCallback? onOpenSeat;
  final VoidCallback? onProximityUnlock;
  final VoidCallback? onQuickEdit;
  final bool powered;
  final bool? locked;
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
                child: _OfficialQuickSlots(
                  enabled: !busy,
                  onQuickEdit: widget.onQuickEdit,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: panelHeight,
                  child: _OfficialControlPanel(
                    powered: widget.powered,
                    locked: widget.locked,
                    busy: busy,
                    onPowerOn: () {
                      HapticFeedback.heavyImpact();
                      widget.onPowerOn?.call();
                    },
                    onFind: widget.onFind,
                    onLock: widget.onLock,
                    onUnlock: widget.onUnlock,
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
    required this.locked,
    required this.busy,
    required this.onPowerOn,
    this.onFind,
    this.onLock,
    this.onUnlock,
  });

  final bool powered;
  final bool? locked;
  final bool busy;
  final VoidCallback onPowerOn;
  final VoidCallback? onFind;
  final VoidCallback? onLock;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    final lockLabel = locked == true ? '解防' : '设防';
    final lockAsset = locked == true
        ? 'assets/official_tailg/ic_control_iv_unlock.png'
        : 'assets/official_tailg/ic_control_iv_lock.png';
    final lockIcon = locked == true ? Icons.lock_open : Icons.lock_outline;
    final lockAction = locked == true ? onUnlock : onLock;
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
                  asset: lockAsset,
                  icon: lockIcon,
                  label: lockLabel,
                  onTap: busy ? null : lockAction,
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
  const _OfficialQuickSlots({required this.enabled, this.onQuickEdit});

  final bool enabled;
  final VoidCallback? onQuickEdit;

  @override
  Widget build(BuildContext context) {
    return _OfficialPanelCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child: _QuickActionSlot(
              label: '添加快捷功能',
              enabled: enabled && onQuickEdit != null,
              onTap: onQuickEdit,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: _QuickActionSlot(
                    label: '添加快捷功能',
                    enabled: enabled && onQuickEdit != null,
                    onTap: onQuickEdit,
                  ),
                ),
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: _QuickEditButton(
                    enabled: enabled && onQuickEdit != null,
                    onTap: onQuickEdit,
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

class _QuickActionSlot extends StatelessWidget {
  const _QuickActionSlot({
    required this.label,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      enabled: enabled,
      onTap: onTap,
      haptic: false,
      pressedScale: AppMotion.pressScale,
      duration: AppMotion.micro,
      curve: AppMotion.pressCurve,
      semanticsLabel: label,
      semanticsButton: true,
      semanticsEnabled: enabled,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF0F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/official_tailg/ic_control_quick_add.webp',
                width: 26,
                height: 26,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.add, size: 24, color: AppColors.brandRed),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickEditButton extends StatelessWidget {
  const _QuickEditButton({required this.enabled, this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      enabled: enabled,
      onTap: onTap,
      haptic: false,
      semanticsLabel: '编辑快捷功能',
      semanticsButton: true,
      semanticsEnabled: enabled,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          width: AppTouchTargets.min,
          height: AppTouchTargets.min,
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
  static const _triggerThreshold = 0.82;
  double _dragProgress = 0;
  bool _dragging = false;

  // Busy-state pulsing ring
  late final AnimationController _busyPulseCtrl;
  late final Animation<double> _busyPulse;

  @override
  void initState() {
    super.initState();
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
    _busyPulseCtrl.stop();
    _busyPulseCtrl.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (widget.busy || widget.onPowerOn == null) {
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _dragging = true;
      _dragProgress = 0;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final width = context.size?.width ?? 1;
    final travel = (width - 66).clamp(1.0, double.infinity);
    final signedDelta = widget.powered
        ? -details.primaryDelta!
        : details.primaryDelta!;
    setState(() {
      _dragProgress = (_dragProgress + signedDelta / travel).clamp(0.0, 1.0);
    });
  }

  void _onDragEnd([DragEndDetails? _]) {
    if (!_dragging) return;
    final shouldFire = _dragProgress >= _triggerThreshold;
    setState(() {
      _dragging = false;
      _dragProgress = 0;
    });
    if (shouldFire) {
      HapticFeedback.heavyImpact();
      widget.onPowerOn?.call();
    }
  }

  void _onDragCancel() {
    if (!_dragging) return;
    setState(() {
      _dragging = false;
      _dragProgress = 0;
    });
  }

  void _triggerFromSemantics() {
    if (widget.busy || widget.onPowerOn == null) return;
    HapticFeedback.heavyImpact();
    widget.onPowerOn?.call();
  }

  @override
  Widget build(BuildContext context) {
    const handleSize = 64.0;
    const handleMargin = 6.0;
    const reservedHandleSpace = handleSize + handleMargin * 2 + 6;
    const trackColor = Color(0xFFEFF0F5);
    const accentColor = AppColors.brandRed;
    final handleAsset = widget.powered
        ? 'assets/official_tailg/ic_slide_start_tip_anti_r.png'
        : 'assets/official_tailg/ic_slide_start_tip_r.png';
    final semanticLabel = widget.busy
        ? '电源：处理中'
        : widget.powered
        ? '电源：左滑关闭'
        : '电源：右滑启动';
    final semanticAction = widget.busy || widget.onPowerOn == null
        ? null
        : _triggerFromSemantics;

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: semanticAction != null,
      onIncrease: widget.powered ? null : semanticAction,
      onDecrease: widget.powered ? semanticAction : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('control-power-slide'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: _onDragCancel,
          child: AnimatedBuilder(
            animation: _busyPulse,
            builder: (_, child) {
              final progress = widget.busy
                  ? _busyPulse.value
                  : _dragging
                  ? Curves.easeOutCubic.transform(_dragProgress)
                  : widget.powered
                  ? 1.0
                  : 0.0;
              final visualProgress = widget.busy
                  ? _busyPulse.value
                  : _dragging
                  ? progress
                  : 0.0;
              final knobAlignment = _dragging
                  ? Alignment.lerp(
                      widget.powered
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      widget.powered
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      progress,
                    )!
                  : widget.powered
                  ? Alignment.centerRight
                  : Alignment.centerLeft;
              final hintText = widget.busy
                  ? (widget.powered ? '关闭中' : '启动中')
                  : widget.powered
                  ? '左滑关闭'
                  : '右滑启动';
              final hintIcon = widget.powered
                  ? Icons.keyboard_double_arrow_left_rounded
                  : Icons.keyboard_double_arrow_right_rounded;
              return Container(
                height: double.infinity,
                constraints: const BoxConstraints(minHeight: 64),
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (visualProgress > 0)
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: widget.powered
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          widthFactor: visualProgress.clamp(0.0, 1.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                      ),
                    Positioned.fill(
                      left: widget.powered ? 10 : reservedHandleSpace,
                      right: widget.powered ? reservedHandleSpace : 10,
                      child: Center(
                        child: AnimatedOpacity(
                          duration: AppMotion.micro,
                          opacity: _dragging ? 0.45 : 1,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!widget.busy) ...[
                                  Icon(
                                    hintIcon,
                                    size: 27,
                                    color: const Color(0xFFB9BBC4),
                                  ),
                                  const SizedBox(width: 2),
                                ],
                                Text(
                                  hintText,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.officialTextMuted,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedAlign(
                      duration: _dragging
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: knobAlignment,
                      child: SizedBox(
                        width: handleSize,
                        height: handleSize,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: handleMargin,
                          ),
                          child: widget.busy
                              ? DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF50515A),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Image.asset(
                                  handleAsset,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF50515A),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Icon(
                                      Icons.power_settings_new,
                                      color: Colors.white,
                                      size: widget.powered ? 27 : 28,
                                    ),
                                  ),
                                ),
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
