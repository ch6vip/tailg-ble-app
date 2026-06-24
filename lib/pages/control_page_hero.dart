import 'package:flutter/material.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';

/// v8 Hero area for the control page home.
///
/// Shows big battery percentage with color-coded SOC bar,
/// range estimate, and vehicle name switcher. Responsive:
/// switches to a stacked layout on narrow screens (< 360 logical px).
/// Aligns with `design_v2/home_v8_ninebot.html` `.hero-head` + `.soc-bar`.
class ControlPageHero extends StatelessWidget {
  const ControlPageHero({
    super.key,
    required this.batteryLevel,
    this.rangeKm,
    this.healthLabel,
    this.vehicleName,
    this.connectionLabel,
    this.onVehicleSwitch,
    this.onBatteryTap,
  });

  /// Battery level 0–100.
  final int batteryLevel;

  /// Estimated range in km.
  final int? rangeKm;

  /// Health status text, e.g. "健康良好".
  final String? healthLabel;

  /// Current vehicle name.
  final String? vehicleName;

  /// Connection status label, e.g. "蓝牙已连接".
  final String? connectionLabel;

  final VoidCallback? onVehicleSwitch;
  final VoidCallback? onBatteryTap;

  /// Returns the color for the battery percentage based on level.
  static Color batteryColor(int level) {
    if (level >= 60) return AppColors.energyGreen;
    if (level >= 30) return AppColors.energyAmber;
    return AppColors.energyRed;
  }

  /// Returns the color for the SOC bar fill.
  static Color barColor(int level) {
    if (level >= 60) return AppColors.energyGreen;
    if (level >= 30) return AppColors.energyAmber;
    return AppColors.energyRed;
  }

  @override
  Widget build(BuildContext context) {
    final bColor = batteryColor(batteryLevel);
    final displayRange = rangeKm ?? 0;
    final displayHealth = healthLabel ?? '健康良好';
    final displayName = vehicleName ?? '我的车辆';
    final displayConn = connectionLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 360;
          final pctFontSize = wide ? 56.0 : 42.0;
          final pctFontWeight = FontWeight.w800;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar: vehicle name + action icons
              _TopBar(
                displayName: displayName,
                displayConn: displayConn,
                onVehicleSwitch: onVehicleSwitch,
              ),
              SizedBox(height: wide ? 14 : 8),

              // Hero: big battery % + range
              GestureDetector(
                onTap: onBatteryTap,
                child: wide
                    ? _WideHeroData(
                        batteryLevel: batteryLevel,
                        bColor: bColor,
                        pctFontSize: pctFontSize,
                        pctFontWeight: pctFontWeight,
                        displayRange: displayRange,
                        displayHealth: displayHealth,
                      )
                    : _NarrowHeroData(
                        batteryLevel: batteryLevel,
                        bColor: bColor,
                        pctFontSize: pctFontSize,
                        pctFontWeight: pctFontWeight,
                        displayRange: displayRange,
                        displayHealth: displayHealth,
                      ),
              ),

              // SOC bar
              const SizedBox(height: 10),
              _SocBar(level: batteryLevel),
            ],
          );
        },
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.displayName,
    required this.displayConn,
    this.onVehicleSwitch,
  });

  final String displayName;
  final String? displayConn;
  final VoidCallback? onVehicleSwitch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: GestureDetector(
            onTap: onVehicleSwitch,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        if (displayConn != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceBrandTealTint,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.energyGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    displayConn ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.energyGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(width: 8),
        _TopIconButton(icon: Icons.notifications_outlined, onTap: () {}),
      ],
    );
  }
}

class _WideHeroData extends StatelessWidget {
  const _WideHeroData({
    required this.batteryLevel,
    required this.bColor,
    required this.pctFontSize,
    required this.pctFontWeight,
    required this.displayRange,
    required this.displayHealth,
  });

  final int batteryLevel;
  final Color bColor;
  final double pctFontSize;
  final FontWeight pctFontWeight;
  final int displayRange;
  final String displayHealth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Big percentage
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$batteryLevel',
              style: TextStyle(
                fontSize: pctFontSize,
                fontWeight: pctFontWeight,
                height: 0.95,
                letterSpacing: -2,
                color: bColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '%',
                style: TextStyle(
                  fontSize: pctFontSize * 0.4,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: pctFontSize * 0.13, left: 2),
              child: const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        // Range text
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      const TextSpan(text: '续航 '),
                      TextSpan(
                        text: '$displayRange',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const TextSpan(text: ' km'),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '· $displayHealth',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NarrowHeroData extends StatelessWidget {
  const _NarrowHeroData({
    required this.batteryLevel,
    required this.bColor,
    required this.pctFontSize,
    required this.pctFontWeight,
    required this.displayRange,
    required this.displayHealth,
  });

  final int batteryLevel;
  final Color bColor;
  final double pctFontSize;
  final FontWeight pctFontWeight;
  final int displayRange;
  final String displayHealth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$batteryLevel',
              style: TextStyle(
                fontSize: pctFontSize,
                fontWeight: pctFontWeight,
                height: 0.95,
                letterSpacing: -2,
                color: bColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '%',
                style: TextStyle(
                  fontSize: pctFontSize * 0.4,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: pctFontSize * 0.13, left: 2),
              child: const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            children: [
              const TextSpan(text: '续航 '),
              TextSpan(
                text: '$displayRange',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const TextSpan(text: ' km'),
            ],
          ),
        ),
        Text(
          '· $displayHealth',
          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _SocBar extends StatelessWidget {
  const _SocBar({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(3),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: (level / 100).clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: ControlPageHero.barColor(level),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}
