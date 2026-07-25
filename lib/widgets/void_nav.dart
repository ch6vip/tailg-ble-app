import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'lucide_icon.dart';

/// Three-entry floating navigation styled after the light Cyber cockpit.
///
/// Product scope intentionally remains 服务 / 控车 / 我的. The two operation
/// tabs shown in the visual reference are not represented by empty shells.
class VoidOrbitalNav extends StatelessWidget {
  const VoidOrbitalNav({
    super.key,
    required this.currentIndex,
    required this.onService,
    required this.onVehicle,
    required this.onMine,
  });

  final int currentIndex;
  final VoidCallback onService;
  final VoidCallback onVehicle;
  final VoidCallback onMine;

  static const double barHeight = 76;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 10 + bottomInset * 0.45),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CyberHomeColors.navSurface,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: CyberHomeColors.white),
              boxShadow: AppShadows.cyberNavShadow,
            ),
            child: SizedBox(
              key: const ValueKey('official-bottom-nav-bar'),
              height: barHeight,
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      itemKey: const ValueKey(
                        'official-bottom-nav-item-service',
                      ),
                      label: '服务',
                      icon: Lucide.service,
                      selected: currentIndex == 0,
                      onTap: onService,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      itemKey: const ValueKey(
                        'official-bottom-nav-item-vehicle',
                      ),
                      label: '控车',
                      icon: Lucide.vehicle,
                      selected: currentIndex == 1,
                      onTap: onVehicle,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      itemKey: const ValueKey('official-bottom-nav-item-mine'),
                      label: '我的',
                      icon: Lucide.mine,
                      selected: currentIndex == 2,
                      onTap: onMine,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.itemKey,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Key itemKey;

  @override
  Widget build(BuildContext context) {
    final color = selected ? CyberHomeColors.ink : CyberHomeColors.inkSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: SizedBox(
          key: itemKey,
          height: VoidOrbitalNav.barHeight,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: AnimatedContainer(
              duration: AppMotion.standard,
              curve: AppMotion.pressCurve,
              decoration: BoxDecoration(
                color: selected
                    ? CyberHomeColors.navSelected
                    : CyberHomeColors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LucideIcon(icon, size: 24, color: color, strokeWidth: 1.9),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: AppMotion.micro,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.2,
                      color: color,
                    ),
                    child: Text(label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
