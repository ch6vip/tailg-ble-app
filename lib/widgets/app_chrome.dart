import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_void.dart';
import 'app_pressable.dart';
import 'lucide_icon.dart';

class AppPageHeader extends StatelessWidget {
  final String title;
  final bool showBack;
  final List<Widget> actions;

  const AppPageHeader({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 0),
      child: Row(
        children: [
          if (showBack) ...[
            AppPressable(
              onTap: () => Navigator.pop(context),
              pressedScale: VoidMotion.pressScale,
              semanticsLabel: '返回',
              semanticsButton: true,
              child: Container(
                width: AppTouchTargets.min,
                height: AppTouchTargets.min,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VoidColors.voidPanel.withValues(alpha: 0.7),
                  border: Border.all(color: VoidColors.hairline),
                ),
                child: const LucideIcon(
                  Lucide.arrowLeft,
                  size: 18,
                  color: VoidColors.inkMuted,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(title, style: VoidType.hero.copyWith(fontSize: 20)),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class AppSectionLabel extends StatelessWidget {
  final String text;

  const AppSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 1.5,
            color: VoidColors.energy.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: VoidType.micro.copyWith(color: VoidColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpacing.screenX),
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill =
        color ??
        (dark
            ? VoidColors.voidPanel.withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.9));
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(VoidRadii.lg),
        border: Border.all(
          color: dark ? VoidColors.hairline : VoidColors.lightHairline,
        ),
        boxShadow: dark ? VoidGlow.panel : AppShadows.elevation1,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(VoidRadii.lg),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class AppHeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  const AppHeaderAction({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final tooltip = this.tooltip;
    Widget button = AppPressable(
      onTap: onTap,
      enabled: onTap != null,
      pressedScale: AppMotion.pressScale,
      semanticsLabel: tooltip,
      semanticsButton: true,
      semanticsEnabled: onTap != null,
      child: SizedBox(
        width: AppTouchTargets.min,
        height: AppTouchTargets.min,
        child: Center(
          child: LucideIcon(icon, size: 20, color: VoidColors.inkMuted),
        ),
      ),
    );
    if (tooltip != null) {
      button = Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: button,
      );
    }
    return button;
  }
}

/// Skeleton placeholder for loading metrics.
class AppSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const AppSkeleton({
    super.key,
    required this.width,
    this.height = 12,
    this.borderRadius,
  });

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.pulsePeriod,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.repeat(reverse: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius =
        widget.borderRadius ?? BorderRadius.circular(widget.height / 2);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = AppMotion.pulseCurve.transform(_controller.value);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(VoidColors.voidPanelHi, VoidColors.voidLift, t),
            borderRadius: radius,
          ),
        );
      },
    );
  }
}

/// Empty-state: circular glyph + title + optional subtitle.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: VoidColors.voidPanelHi,
              shape: BoxShape.circle,
              border: Border.all(color: VoidColors.hairline),
            ),
            child: LucideIcon(
              icon,
              size: AppIconSizes.md,
              color: VoidColors.inkFaint,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: VoidType.bodyStrong.copyWith(color: VoidColors.inkMuted),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: VoidType.caption.copyWith(
                height: 1.5,
                color: VoidColors.inkFaint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
