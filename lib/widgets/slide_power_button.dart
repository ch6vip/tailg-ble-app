import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'lucide_icon.dart';

/// Official-like bidirectional power slider.
///
/// Power off starts on the left and slides right to start. Power on starts on
/// the right and slides left to stop. The thumb always returns to the current
/// state origin after activation; only confirmed vehicle state changes its
/// resting side.
class SlidePowerButton extends StatefulWidget {
  const SlidePowerButton({
    super.key,
    required this.isPowered,
    required this.onSlide,
    this.enabled = true,
    this.busy = false,
  });

  final bool? isPowered;
  final Future<void> Function() onSlide;
  final bool enabled;
  final bool busy;

  @override
  State<SlidePowerButton> createState() => _SlidePowerButtonState();
}

class _SlidePowerButtonState extends State<SlidePowerButton>
    with TickerProviderStateMixin {
  static const _trackWidth = 160.0;
  static const _trackHeight = 60.0;
  static const _thumbSize = 60.0;
  static const _completionThreshold = 0.98;

  double _dragPosition = 0;
  late final AnimationController _resetController;
  late Animation<double> _resetAnimation;
  late final AnimationController _feedbackController;
  late final Animation<double> _shakeAnimation;
  bool _awaitingResult = false;
  bool _dragging = false;
  bool? _commandOriginPowered;

  double get _maxDragDistance => _trackWidth - _thumbSize;
  double get _idlePosition => widget.isPowered == true ? _maxDragDistance : 0;
  double get _completedPosition =>
      widget.isPowered == true ? 0 : _maxDragDistance;
  bool get _canSlide =>
      widget.enabled &&
      !widget.busy &&
      !_awaitingResult &&
      widget.isPowered != null;

  String get _label {
    if (_awaitingResult) {
      return _commandOriginPowered == true ? '正在断电' : '正在通电';
    }
    if (widget.busy) return '指令执行中';
    if (widget.isPowered == null) return '车辆状态未知';
    if (!widget.enabled) return '控车不可用';
    return widget.isPowered! ? '左滑关闭' : '右滑启动';
  }

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: AppMotion.standard,
    );
    _resetAnimation = AlwaysStoppedAnimation<double>(_idlePosition);
    _dragPosition = _idlePosition;
    _resetController.addListener(() {
      if (mounted) setState(() => _dragPosition = _resetAnimation.value);
    });
    _feedbackController = AnimationController(
      vsync: this,
      duration: AppMotion.failureFeedback,
    );
    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0, end: -5), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -5, end: 4), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 4, end: -2), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -2, end: 0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _feedbackController, curve: Curves.easeOut),
        );
  }

  @override
  void didUpdateWidget(covariant SlidePowerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPowered != widget.isPowered) {
      _awaitingResult = false;
      _commandOriginPowered = null;
      _animateTo(_idlePosition);
      return;
    }
    if (_awaitingResult) return;
    if (oldWidget.enabled == widget.enabled && oldWidget.busy == widget.busy) {
      return;
    }
    _resetController.stop();
    _dragPosition = _idlePosition;
  }

  @override
  void dispose() {
    _resetController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_canSlide) return;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(
        0.0,
        _maxDragDistance,
      );
    });
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (!_canSlide) return;
    setState(() => _dragging = true);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_canSlide) return;
    final completedDistance = widget.isPowered == true
        ? _maxDragDistance - _dragPosition
        : _dragPosition;
    if (completedDistance >= _maxDragDistance * _completionThreshold) {
      unawaited(_activate());
      return;
    }
    _dragging = false;
    _animateTo(_idlePosition);
  }

  void _onHorizontalDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _animateTo(_idlePosition);
  }

  Future<void> _activate() async {
    if (!_canSlide) return;
    final originPowered = widget.isPowered;
    _resetController.stop();
    setState(() {
      _commandOriginPowered = originPowered;
      _awaitingResult = true;
      _dragging = false;
      _dragPosition = _completedPosition;
    });
    unawaited(HapticFeedback.mediumImpact());
    await widget.onSlide();
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final confirmed = widget.isPowered != originPowered;
    setState(() {
      _awaitingResult = false;
      _commandOriginPowered = null;
    });
    _animateTo(_idlePosition);
    if (!confirmed) {
      unawaited(HapticFeedback.heavyImpact());
      unawaited(_feedbackController.forward(from: 0));
    }
  }

  void _animateTo(double target) {
    _resetAnimation = Tween<double>(begin: _dragPosition, end: target).animate(
      CurvedAnimation(parent: _resetController, curve: AppMotion.pressCurve),
    );
    unawaited(_resetController.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final powered = widget.isPowered == true;
    final arrow = powered ? Lucide.chevronLeft : Lucide.chevronRight;
    return Semantics(
      key: const ValueKey('slide-power-semantics'),
      label: _label,
      hint: _canSlide ? (powered ? '向左滑动关闭车辆电门' : '向右滑动启动车辆电门') : null,
      button: true,
      enabled: _canSlide,
      onTap: _canSlide ? () => unawaited(_activate()) : null,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) => Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: child,
          ),
          child: AnimatedOpacity(
            duration: AppMotion.status,
            opacity: _canSlide || _awaitingResult ? 1 : 0.58,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: _trackWidth,
                  height: _trackHeight,
                  child: Stack(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: CyberHomeColors.controlStrong,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: SizedBox(
                          width: _trackWidth,
                          height: _trackHeight,
                          child: Row(
                            mainAxisAlignment: powered
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.end,
                            children: [
                              if (powered) const SizedBox(width: 15),
                              for (var index = 0; index < 3; index++) ...[
                                LucideIcon(
                                  arrow,
                                  size: AppIconSizes.md,
                                  color: CyberHomeColors.inkFaint.withValues(
                                    alpha: 0.62 - index * 0.12,
                                  ),
                                ),
                                if (index < 2) const SizedBox(width: 1),
                              ],
                              if (!powered) const SizedBox(width: 15),
                            ],
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration:
                            _dragging ||
                                _awaitingResult ||
                                _resetController.isAnimating
                            ? Duration.zero
                            : AppMotion.micro,
                        curve: AppMotion.pressCurve,
                        left: _dragPosition,
                        child: GestureDetector(
                          key: const ValueKey('slide-power-thumb'),
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: _canSlide
                              ? _onHorizontalDragStart
                              : null,
                          onHorizontalDragUpdate: _canSlide
                              ? _onHorizontalDragUpdate
                              : null,
                          onHorizontalDragEnd: _canSlide
                              ? _onHorizontalDragEnd
                              : null,
                          onHorizontalDragCancel: _canSlide
                              ? _onHorizontalDragCancel
                              : null,
                          child: Container(
                            width: _thumbSize,
                            height: _thumbSize,
                            decoration: const BoxDecoration(
                              color: CyberHomeColors.card,
                              shape: BoxShape.circle,
                              boxShadow: AppShadows.cyberActionShadow,
                            ),
                            alignment: Alignment.center,
                            child: AnimatedSwitcher(
                              duration: AppMotion.status,
                              child: _awaitingResult
                                  ? const SizedBox(
                                      key: ValueKey('power-progress'),
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: CyberHomeColors.primary,
                                      ),
                                    )
                                  : const LucideIcon(
                                      Lucide.power,
                                      key: ValueKey('power-icon'),
                                      size: 28,
                                      color: CyberHomeColors.ink,
                                      strokeWidth: 1.8,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 17),
                Text(
                  _label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: CyberHomeColors.inkMuted,
                    fontWeight: FontWeight.w500,
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
