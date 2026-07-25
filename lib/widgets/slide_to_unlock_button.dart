import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'lucide_icon.dart';

/// Compact slide-to-unlock control used by the light Cyber home.
///
/// Drag remains the primary interaction. A semantic tap action is provided so
/// switch-control and screen-reader users are not blocked by a drag-only UI.
class SlideToUnlockButton extends StatefulWidget {
  const SlideToUnlockButton({
    super.key,
    required this.onUnlocked,
    this.isLocked = true,
  });

  final VoidCallback onUnlocked;
  final bool isLocked;

  @override
  State<SlideToUnlockButton> createState() => _SlideToUnlockButtonState();
}

class _SlideToUnlockButtonState extends State<SlideToUnlockButton>
    with SingleTickerProviderStateMixin {
  static const _trackWidth = 172.0;
  static const _trackHeight = 68.0;
  static const _thumbSize = 68.0;

  double _dragPosition = 0;
  late final AnimationController _resetController;
  late Animation<double> _resetAnimation;

  double get _maxDragDistance => _trackWidth - _thumbSize;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: AppMotion.standard,
    );
    _resetAnimation = const AlwaysStoppedAnimation<double>(0);
    _resetController.addListener(() {
      if (mounted) setState(() => _dragPosition = _resetAnimation.value);
    });
    if (!widget.isLocked) _dragPosition = _maxDragDistance;
  }

  @override
  void didUpdateWidget(covariant SlideToUnlockButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLocked == widget.isLocked) return;
    _resetController.stop();
    setState(() {
      _dragPosition = widget.isLocked ? 0 : _maxDragDistance;
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.isLocked) return;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(
        0.0,
        _maxDragDistance,
      );
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.isLocked) return;
    if (_dragPosition >= _maxDragDistance * 0.78) {
      _activateUnlock();
      return;
    }
    _animateTo(0);
  }

  void _activateUnlock() {
    if (!widget.isLocked) return;
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _dragPosition = _maxDragDistance);
    widget.onUnlocked();
  }

  void _animateTo(double target) {
    _resetAnimation = Tween<double>(begin: _dragPosition, end: target).animate(
      CurvedAnimation(parent: _resetController, curve: AppMotion.pressCurve),
    );
    unawaited(_resetController.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isLocked ? '滑动开锁' : '车辆已解锁';
    return Semantics(
      key: const ValueKey('slide-unlock-semantics'),
      label: label,
      hint: widget.isLocked ? '向右滑动，或使用辅助功能激活' : null,
      button: true,
      enabled: widget.isLocked,
      onTap: widget.isLocked ? _activateUnlock : null,
      child: ExcludeSemantics(
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
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          for (var index = 0; index < 3; index++) ...[
                            LucideIcon(
                              Lucide.chevronRight,
                              size: AppIconSizes.md,
                              color: CyberHomeColors.inkFaint.withValues(
                                alpha: 0.62 - index * 0.12,
                              ),
                            ),
                            if (index < 2) const SizedBox(width: 1),
                          ],
                          const SizedBox(width: 15),
                        ],
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: _resetController.isAnimating
                        ? Duration.zero
                        : AppMotion.micro,
                    curve: AppMotion.pressCurve,
                    left: _dragPosition,
                    child: GestureDetector(
                      key: const ValueKey('slide-unlock-thumb'),
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: _onHorizontalDragUpdate,
                      onHorizontalDragEnd: _onHorizontalDragEnd,
                      child: Container(
                        width: _thumbSize,
                        height: _thumbSize,
                        decoration: const BoxDecoration(
                          color: CyberHomeColors.card,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.cyberActionShadow,
                        ),
                        alignment: Alignment.center,
                        child: LucideIcon(
                          widget.isLocked ? Lucide.lock : Lucide.unlock,
                          size: 30,
                          color: CyberHomeColors.ink,
                          strokeWidth: 1.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: CyberHomeColors.inkMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
