import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';
import 'package:tailg_ble_app/theme/app_motion.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

const _slideHandleFallbackColor = Color(0xFF50515A);
const _slideHandleFallbackRadius = BorderRadius.all(Radius.circular(9));
const _quickActionOpacityDuration = Duration(milliseconds: 200);
const _quickEditButtonOverflow = 16.0;
const _quickEditButtonVisualInset = 3.0;
const _quickEditButtonVisualOffset = Offset(
  -(_quickEditButtonOverflow + _quickEditButtonVisualInset),
  -(_quickEditButtonOverflow + _quickEditButtonVisualInset),
);

// Official Lottie assets (ControlFragment BaseEvent 112 / 32).
const _lottieStartJson =
    'assets/official_tailg/lottie/startanmim/control_daw_start.json';
const _lottieStopJson =
    'assets/official_tailg/lottie/stopanmim/control_daw_stop.json';
const _lottieLoadJson =
    'assets/official_tailg/lottie/anmim/control_daw_start_stop_load.json';

/// Official Tailg control card: two quick actions on the left, the slide-style
/// power control plus find/lock actions on the right.
class ControlCard extends StatefulWidget {
  const ControlCard({
    super.key,
    this.onPowerOn,
    this.onFind,
    this.onLock,
    this.onUnlock,
    this.onOpenSeat,
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
                  onOpenSeat: widget.onOpenSeat,
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
          borderRadius: BorderRadius.circular(AppRadii.card),
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
  const _OfficialQuickSlots({
    required this.enabled,
    this.onOpenSeat,
    this.onQuickEdit,
  });

  final bool enabled;
  final VoidCallback? onOpenSeat;
  final VoidCallback? onQuickEdit;

  @override
  Widget build(BuildContext context) {
    return _OfficialPanelCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child: _QuickActionSlot(
              label: onOpenSeat == null ? '添加快捷功能' : '打开座桶',
              asset: onOpenSeat == null
                  ? 'assets/official_tailg/ic_control_quick_add.webp'
                  : 'assets/official_tailg/ic_control_iv_chair.png',
              icon: onOpenSeat == null ? Icons.add : Icons.event_seat_outlined,
              showLabel: onOpenSeat != null,
              enabled: enabled && (onOpenSeat ?? onQuickEdit) != null,
              onTap: onOpenSeat ?? onQuickEdit,
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
                    asset: 'assets/official_tailg/ic_control_quick_add.webp',
                    icon: Icons.add,
                    showLabel: false,
                    enabled: enabled && onQuickEdit != null,
                    onTap: onQuickEdit,
                  ),
                ),
                Positioned(
                  right: -_quickEditButtonOverflow,
                  bottom: -_quickEditButtonOverflow,
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
    required this.asset,
    required this.icon,
    required this.enabled,
    this.showLabel = true,
    this.onTap,
  });

  final String label;
  final String asset;
  final IconData icon;
  final bool enabled;
  final bool showLabel;
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
        duration: _quickActionOpacityDuration,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.officialPageBg,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                asset,
                width: 26,
                height: 26,
                errorBuilder: (_, __, ___) =>
                    Icon(icon, size: 24, color: AppColors.brandRed),
              ),
              if (showLabel) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.officialTextMuted,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
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
        duration: _quickActionOpacityDuration,
        child: SizedBox(
          width: AppTouchTargets.min,
          height: AppTouchTargets.min,
          child: Transform.translate(
            offset: _quickEditButtonVisualOffset,
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
      ),
    );
  }
}

/// Central slide-style power control — 1:1 replica of official ControlFragment
/// power rail (`sv_start` / `sv_stop` + Lottie overlays).
///
/// Interaction (ng.max.slideview.Slider):
/// - SeekBar max=100; fire only when progress > 99 on ACTION_UP
/// - Drag only starts when ACTION_DOWN lands on the thumb
/// - No progress fill; hint text alpha = 1 - progress
/// - Thumb follows finger linearly; progress resets to 0 on release
///
/// State machine (ControlFragment BaseEvent 112 / 32):
/// - Idle powered=false → show SlideViewStart ("右滑启动", left rest)
/// - Idle powered=true  → show SlideViewStop  ("左滑关闭", right rest)
/// - On complete → hide slide, show streak Lottie + load Lottie on the end
/// - On busy→false (command finished) → switch to the opposite slide view
class _PowerKnob extends StatefulWidget {
  const _PowerKnob({required this.powered, this.busy = false, this.onPowerOn});
  final bool powered;
  final bool busy;
  final VoidCallback? onPowerOn;

  @override
  State<_PowerKnob> createState() => _PowerKnobState();
}

class _PowerKnobState extends State<_PowerKnob> with TickerProviderStateMixin {
  /// Official: `getProgress() > 99` with max=100.
  static const _triggerThreshold = 0.99;
  static const _handleSize = 64.0;
  static const _handleMargin = 6.0;
  static const _trackRadius = 8.0;
  static const _loadSize = 52.0;

  double _dragProgress = 0;
  bool _dragging = false;

  /// True while showing official command Lottie overlays (busy phase).
  bool _showBusyOverlay = false;

  /// Direction of the in-flight command: false = start (rightward), true = stop.
  bool _busyAsPowered = false;

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
  }

  @override
  void didUpdateWidget(covariant _PowerKnob oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Official event 112: command begins → keep overlay for the direction
    // that was active when the user completed the slide.
    if (!oldWidget.busy && widget.busy) {
      setState(() {
        _showBusyOverlay = true;
        _busyAsPowered = oldWidget.powered;
        _dragging = false;
        _dragProgress = 0;
      });
      if (!_busyPulseCtrl.isAnimating) {
        _busyPulseCtrl.repeat(reverse: true);
      }
    }
    // Official event 32: command ends → hide overlays, show opposite slide.
    if (oldWidget.busy && !widget.busy) {
      _busyPulseCtrl.stop();
      setState(() {
        _showBusyOverlay = false;
        _dragging = false;
        _dragProgress = 0;
      });
    }
    if (oldWidget.powered != widget.powered && !_dragging && !widget.busy) {
      _dragProgress = 0;
    }
  }

  @override
  void dispose() {
    _busyPulseCtrl.stop();
    _busyPulseCtrl.dispose();
    super.dispose();
  }

  Rect _handleRestRect(Size size, {required bool powered}) {
    final top = ((size.height - _handleSize) / 2).clamp(0.0, double.infinity);
    final left = powered
        ? (size.width - _handleSize).clamp(0.0, double.infinity)
        : 0.0;
    return Rect.fromLTWH(left, top, _handleSize, _handleSize);
  }

  /// Official Slider: ACTION_DOWN only accepted inside `thumb.getBounds()`.
  bool _isOnHandle(Offset localPosition, {required bool powered}) {
    final size = context.size;
    if (size == null) return false;
    return _handleRestRect(size, powered: powered).inflate(4).contains(
          localPosition,
        );
  }

  void _onDragStart(DragStartDetails details) {
    if (widget.busy || widget.onPowerOn == null) return;
    if (!_isOnHandle(details.localPosition, powered: widget.powered)) return;
    HapticFeedback.lightImpact();
    setState(() {
      _dragging = true;
      _dragProgress = 0;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final delta = details.primaryDelta;
    if (delta == null) return;
    final width = context.size?.width ?? 1;
    final travel = (width - _handleSize).clamp(1.0, double.infinity);
    // Official stop view uses reverseSlide (180° rotation).
    final signedDelta = widget.powered ? -delta : delta;
    setState(() {
      _dragProgress = (_dragProgress + signedDelta / travel).clamp(0.0, 1.0);
    });
  }

  void _onDragEnd([DragEndDetails? _]) {
    if (!_dragging) return;
    // Official: fire only on ACTION_UP when progress > 99, then setProgress(0).
    final shouldFire = _dragProgress > _triggerThreshold;
    setState(() {
      _dragging = false;
      _dragProgress = 0;
    });
    if (shouldFire) {
      HapticFeedback.heavyImpact();
      // Overlay is shown when parent sets busy=true (didUpdateWidget), after
      // policy/availability pass — avoids stuck Lottie if the command is denied.
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
    final powered = widget.powered;
    final semanticLabel = (_showBusyOverlay || widget.busy)
        ? '电源：处理中'
        : powered
        ? '电源：左滑关闭'
        : '电源：右滑启动';
    final semanticAction =
        widget.busy || _showBusyOverlay || widget.onPowerOn == null
        ? null
        : _triggerFromSemantics;

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: semanticAction != null,
      onIncrease: powered ? null : semanticAction,
      onDecrease: powered ? semanticAction : null,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final trackHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 64.0;

            return Container(
              key: const ValueKey('control-power-slide'),
              width: trackWidth,
              height: trackHeight,
              constraints: const BoxConstraints(minHeight: 64),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Idle slide (sv_start or sv_stop). Hidden during busy
                  // overlay, matching official setVisibility(4) on complete.
                  if (!_showBusyOverlay)
                    Positioned.fill(
                      child: _OfficialSlideTrack(
                        powered: powered,
                        dragProgress: _dragging ? _dragProgress : 0.0,
                        handleSize: _handleSize,
                        handleMargin: _handleMargin,
                        trackRadius: _trackRadius,
                        onDragStart: _onDragStart,
                        onDragUpdate: _onDragUpdate,
                        onDragEnd: _onDragEnd,
                        onDragCancel: _onDragCancel,
                      ),
                    ),
                  // Busy overlays (lav_control_start/stop + load).
                  if (_showBusyOverlay)
                    Positioned.fill(
                      child: _OfficialBusyOverlay(
                        asPowered: _busyAsPowered,
                        loadSize: _loadSize,
                        trackRadius: _trackRadius,
                        pulse: _busyPulse,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One official slide track: either start (left→right) or stop (right→left).
class _OfficialSlideTrack extends StatelessWidget {
  const _OfficialSlideTrack({
    required this.powered,
    required this.dragProgress,
    required this.handleSize,
    required this.handleMargin,
    required this.trackRadius,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });

  final bool powered;
  final double dragProgress;
  final double handleSize;
  final double handleMargin;
  final double trackRadius;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final GestureDragCancelCallback onDragCancel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final trackHeight = constraints.maxHeight;
        final travel = (trackWidth - handleSize).clamp(0.0, double.infinity);
        final handleLeft = powered
            ? travel * (1.0 - dragProgress)
            : travel * dragProgress;
        final handleAsset = powered
            ? 'assets/official_tailg/ic_slide_start_tip_anti_r.png'
            : 'assets/official_tailg/ic_slide_start_tip_r.png';
        final tipAsset = powered
            ? 'assets/official_tailg/ic_slide_left_tip.png'
            : 'assets/official_tailg/ic_slide_right_tip.png';
        final hintText = powered ? '左滑关闭' : '右滑启动';
        // Official SlideView*: text alpha = 1 - progress/100.
        final hintOpacity = (1.0 - dragProgress).clamp(0.0, 1.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: onDragStart,
          onHorizontalDragUpdate: onDragUpdate,
          onHorizontalDragEnd: onDragEnd,
          onHorizontalDragCancel: onDragCancel,
          child: Container(
            width: trackWidth,
            height: trackHeight,
            decoration: BoxDecoration(
              color: AppColors.officialPageBg,
              borderRadius: BorderRadius.circular(trackRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Official: drawableTop tip + text, alpha fades with progress.
                Positioned.fill(
                  child: Opacity(
                    opacity: hintOpacity,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              tipAsset,
                              width: 28,
                              height: 14,
                              errorBuilder: (_, __, ___) => Icon(
                                powered
                                    ? Icons.keyboard_double_arrow_left_rounded
                                    : Icons
                                          .keyboard_double_arrow_right_rounded,
                                size: 22,
                                color: const Color(0xFFB9BBC4),
                              ),
                            ),
                            const SizedBox(height: 2),
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
                // Thumb — absolute left, linear follow (SeekBar).
                Positioned(
                  left: handleLeft,
                  top: ((trackHeight - handleSize) / 2).clamp(
                    0.0,
                    double.infinity,
                  ),
                  width: handleSize,
                  height: handleSize,
                  child: KeyedSubtree(
                    key: const ValueKey('control-power-slide-handle'),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: handleMargin),
                      child: Image.asset(
                        handleAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => DecoratedBox(
                          decoration: BoxDecoration(
                            color: _slideHandleFallbackColor,
                            borderRadius: _slideHandleFallbackRadius,
                          ),
                          child: Icon(
                            Icons.power_settings_new,
                            color: Colors.white,
                            size: powered ? 27 : 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Official busy overlays: full-width streak Lottie + end-side load Lottie.
///
/// Mirrors ControlFragment BaseEvent 112:
/// - start: lav_control_start + lav_control_start_load (right)
/// - stop:  lav_control_stop  + lav_control_stop_load  (left)
class _OfficialBusyOverlay extends StatelessWidget {
  const _OfficialBusyOverlay({
    required this.asPowered,
    required this.loadSize,
    required this.trackRadius,
    required this.pulse,
  });

  /// false = start command (rightward streak, load on right)
  /// true  = stop command  (leftward streak, load on left)
  final bool asPowered;
  final double loadSize;
  final double trackRadius;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final streakJson = asPowered ? _lottieStopJson : _lottieStartJson;
    final bgAsset = asPowered
        ? 'assets/official_tailg/ic_control_stop_drw_bg.png'
        : 'assets/official_tailg/ic_control_start_drw_bg.png';

    return ClipRRect(
      borderRadius: BorderRadius.circular(trackRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Soft track under the streak (official shape_round_bg_ctl_bg).
          const ColoredBox(color: AppColors.officialPageBg),
          // Optional drawn bg used by BLE-direct models; harmless for cloud.
          Positioned.fill(
            child: Image.asset(
              bgAsset,
              fit: BoxFit.fill,
              alignment: asPowered
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          // Full-width streak Lottie (control_daw_start / control_daw_stop).
          // Image assets resolve relative to the JSON path
          // (…/startanmim/images/img_0.png).
          Positioned.fill(
            child: Lottie.asset(
              streakJson,
              fit: BoxFit.fill,
              repeat: true,
              errorBuilder: (_, __, ___) =>
                  _StreakFallback(reverse: asPowered, pulse: pulse),
            ),
          ),
          // Load spinner on the destination end (official dimen120/130).
          Align(
            alignment: asPowered ? Alignment.centerLeft : Alignment.centerRight,
            child: SizedBox(
              width: loadSize,
              height: loadSize,
              child: Lottie.asset(
                _lottieLoadJson,
                fit: BoxFit.contain,
                repeat: true,
                errorBuilder: (_, __, ___) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: AnimatedBuilder(
                    animation: pulse,
                    builder: (_, __) => CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white.withValues(
                        alpha: 0.55 + pulse.value * 0.45,
                      ),
                    ),
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

/// Fallback when Lottie assets fail: a simple sliding highlight.
class _StreakFallback extends StatelessWidget {
  const _StreakFallback({required this.reverse, required this.pulse});
  final bool reverse;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        return Align(
          alignment: Alignment.lerp(
            reverse ? Alignment.centerRight : Alignment.centerLeft,
            reverse ? Alignment.centerLeft : Alignment.centerRight,
            pulse.value,
          )!,
          child: Container(
            width: 80,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: reverse
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                end: reverse
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
