import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_pressable.dart';
import 'lucide_icon.dart';

const cyberPageTitleStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w700,
  color: CyberHomeColors.ink,
);

const cyberSectionTitleStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  color: CyberHomeColors.inkMuted,
);

const cyberItemTitleStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: CyberHomeColors.ink,
);

const cyberBodyStyle = TextStyle(
  fontSize: 13,
  height: 1.45,
  color: CyberHomeColors.inkMuted,
);

const cyberCaptionStyle = TextStyle(
  fontSize: 12,
  height: 1.4,
  color: CyberHomeColors.inkFaint,
);

class CyberPageHeader extends StatelessWidget {
  const CyberPageHeader({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions = const [],
  });

  final String title;
  final bool showBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          if (showBack) ...[
            Tooltip(
              message: '返回',
              excludeFromSemantics: true,
              child: AppPressable(
                key: const ValueKey('app-page-header-back'),
                onTap: () => Navigator.of(context).pop(),
                semanticsLabel: '返回',
                semanticsButton: true,
                child: Container(
                  width: AppTouchTargets.min,
                  height: AppTouchTargets.min,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: CyberHomeColors.card,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.cyberActionShadow,
                  ),
                  child: const LucideIcon(
                    Lucide.arrowLeft,
                    size: 20,
                    color: CyberHomeColors.inkSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: cyberPageTitleStyle,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class CyberHeaderAction extends StatelessWidget {
  const CyberHeaderAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: AppPressable(
        onTap: onTap,
        enabled: onTap != null,
        semanticsLabel: label,
        semanticsButton: true,
        semanticsEnabled: onTap != null,
        child: SizedBox(
          width: AppTouchTargets.min,
          height: AppTouchTargets.min,
          child: Center(
            child: LucideIcon(
              icon,
              size: 20,
              color: onTap == null
                  ? CyberHomeColors.inkFaint
                  : CyberHomeColors.inkSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class CyberSectionLabel extends StatelessWidget {
  const CyberSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(text, style: cyberSectionTitleStyle),
    );
  }
}

class CyberCard extends StatelessWidget {
  const CyberCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpacing.screenX),
    this.padding = const EdgeInsets.all(16),
    this.color = CyberHomeColors.card,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: CyberHomeColors.line),
      ),
      child: Material(
        color: CyberHomeColors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class CyberEmptyState extends StatelessWidget {
  const CyberEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

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
              color: CyberHomeColors.primarySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: LucideIcon(icon, size: 24, color: CyberHomeColors.primary),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: cyberItemTitleStyle),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: cyberBodyStyle),
          ],
        ],
      ),
    );
  }
}

InputDecoration cyberInputDecoration({
  String? labelText,
  String? hintText,
  Widget? prefixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.tile),
    borderSide: const BorderSide(color: CyberHomeColors.lineStrong),
  );
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: CyberHomeColors.cardMuted,
    labelStyle: const TextStyle(color: CyberHomeColors.inkMuted),
    floatingLabelStyle: const TextStyle(color: CyberHomeColors.primary),
    hintStyle: const TextStyle(color: CyberHomeColors.inkFaint),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: CyberHomeColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );
}

ButtonStyle cyberFilledButtonStyle() {
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    backgroundColor: CyberHomeColors.primary,
    foregroundColor: CyberHomeColors.white,
    disabledBackgroundColor: CyberHomeColors.controlStrong,
    disabledForegroundColor: CyberHomeColors.inkFaint,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.tile),
    ),
  );
}

ButtonStyle cyberOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    foregroundColor: CyberHomeColors.inkSecondary,
    side: const BorderSide(color: CyberHomeColors.lineStrong),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.tile),
    ),
  );
}
