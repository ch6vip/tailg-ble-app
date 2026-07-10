import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'app_pressable.dart';

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
            IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
                semanticLabel: '返回',
              ),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: AppTouchTargets.min,
                minHeight: AppTouchTargets.min,
              ),
              tooltip: '返回',
            ),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(title, style: AppTextStyles.subPageTitle)),
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
      child: Text(text, style: AppTextStyles.sectionLabel),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Color color;

  const AppCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpacing.screenX),
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.elevation1,
      ),
      child: child,
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
      haptic: false,
      semanticsLabel: tooltip,
      semanticsButton: true,
      semanticsEnabled: onTap != null,
      borderRadius: BorderRadius.circular(AppRadii.sheet),
      pressedBackground: AppColors.primary.withValues(alpha: 0.05),
      child: SizedBox(
        width: AppTouchTargets.min,
        height: AppTouchTargets.min,
        child: Icon(
          icon,
          size: AppIconSizes.md,
          color: AppColors.textSecondary,
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

/// 极简骨架占位：浅灰圆角条配上呼吸式高光，用于数据加载/待读取态，
/// 替代静态的「等待数据 / 待读取」文字，给出更高级的加载反馈。
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
  )..repeat(reverse: true);

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
            color: Color.lerp(
              const Color(0xFFEDEDEA),
              const Color(0xFFF7F7F4),
              t,
            ),
            borderRadius: radius,
          ),
        );
      },
    );
  }
}

/// 极简空状态：圆形浅底图标 + 标题 + 副标题，统一各页面的空白区表达。
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
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2EF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: AppIconSizes.md,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.itemTitle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
