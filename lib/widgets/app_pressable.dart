import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_motion.dart';

typedef AppPressableBuilder =
    Widget Function(BuildContext context, bool pressed);

/// Reusable press-feedback widget that consolidates the _pressed / AnimatedScale
/// / GestureDetector pattern previously duplicated across 10+ files.
///
/// Wrap any tappable child to get consistent scale + color animation on press.
class AppPressable extends StatefulWidget {
  final Widget? child;
  final AppPressableBuilder? builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final double pressedScale;
  final Color background;
  final Color? pressedBackground;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? boxShadow;
  final List<BoxShadow>? pressedBoxShadow;
  final Duration duration;
  final Curve curve;
  final bool haptic;

  const AppPressable({
    super.key,
    this.child,
    this.builder,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.pressedScale = AppMotion.pressScale,
    this.background = Colors.transparent,
    this.pressedBackground,
    this.borderRadius,
    this.boxShadow,
    this.pressedBoxShadow,
    this.duration = AppMotion.micro,
    this.curve = AppMotion.pressCurve,
    this.haptic = true,
  }) : assert(child != null || builder != null);

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.enabled && _pressed;
    final child = widget.builder?.call(context, isActive) ?? widget.child!;
    return Semantics(
      button: widget.enabled,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
        onTapUp: widget.enabled
            ? (_) {
                _setPressed(false);
                if (widget.haptic) {
                  HapticFeedback.lightImpact();
                }
                widget.onTap?.call();
              }
            : null,
        onTapCancel: widget.enabled ? () => _setPressed(false) : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        child: AnimatedScale(
          duration: widget.duration,
          curve: widget.curve,
          scale: isActive ? widget.pressedScale : 1,
          child: AnimatedContainer(
            duration: widget.duration,
            curve: widget.curve,
            decoration: BoxDecoration(
              color: isActive
                  ? (widget.pressedBackground ??
                        widget.background.withValues(alpha: 0.7))
                  : widget.background,
              borderRadius: widget.borderRadius,
              boxShadow: isActive ? widget.pressedBoxShadow : widget.boxShadow,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
