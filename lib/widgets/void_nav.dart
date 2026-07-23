import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_void.dart';
import 'lucide_icon.dart';

/// Floating orbital bottom nav — glass pill, Lucide icons, energy active state.
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

  static const double barHeight = 72;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final fill = dark
        ? VoidColors.voidPanel.withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.86);
    final edge = dark ? VoidColors.hairlineStrong : VoidColors.lightHairline;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 10 + bottomInset * 0.4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VoidRadii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(VoidRadii.pill),
              border: Border.all(color: edge),
              boxShadow: VoidGlow.float,
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
                      primary: true,
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
    this.itemKey,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Key? itemKey;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final idle = dark ? VoidColors.inkFaint : VoidColors.lightInkMuted;
    final active = primary && selected
        ? VoidColors.energy
        : (selected ? (dark ? VoidColors.ink : VoidColors.lightInk) : idle);

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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: VoidMotion.soft,
                curve: VoidMotion.outExpo,
                width: primary ? 48 : 40,
                height: primary ? 48 : 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected && primary
                      ? VoidColors.energy.withValues(alpha: 0.16)
                      : Colors.transparent,
                  boxShadow: selected && primary
                      ? VoidGlow.energy(intensity: 0.45)
                      : const [],
                ),
                child: LucideIcon(icon, size: primary ? 24 : 20, color: active),
              ),
              if (!primary) ...[
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: VoidMotion.snap,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.4,
                    color: active,
                  ),
                  child: Text(label),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
