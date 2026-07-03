import 'package:flutter/material.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

/// v8 Hero area for the control page home.
///
/// Shows big battery percentage with color-coded SOC bar,
/// range estimate, and vehicle name switcher. Responsive:
/// switches to a stacked layout on narrow screens (< 360 logical px).
/// Current design notes live in `docs/design_system.md`.
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
    this.onNotification,
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
  final VoidCallback? onNotification;

  /// Returns the color for the battery percentage based on level.
  static Color batteryColor(int level) {
    if (level >= 30) return AppColors.textPrimary;
    return AppColors.brandRed;
  }

  /// Returns the color for the SOC bar fill.
  static Color barColor(int level) {
    if (level >= 30) return AppColors.brandRed;
    return AppColors.energyRed;
  }

  @override
  Widget build(BuildContext context) {
    final bColor = batteryColor(batteryLevel);
    final displayRange = rangeKm ?? 0;
    final displayHealth = healthLabel ?? '--';
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
                onNotification: onNotification,
              ),
              SizedBox(height: wide ? 18 : 10),

              // Hero: big battery % + range
              Semantics(
                label: '电量 $batteryLevel%，续航 $displayRange km，$displayHealth',
                button: onBatteryTap != null,
                enabled: onBatteryTap != null,
                onTap: onBatteryTap,
                child: ExcludeSemantics(
                  child: GestureDetector(
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
                ),
              ),

              const SizedBox(height: 12),
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
    this.onNotification,
  });

  final String displayName;
  final String? displayConn;
  final VoidCallback? onVehicleSwitch;
  final VoidCallback? onNotification;

  @override
  Widget build(BuildContext context) {
    final vehicleSwitch = GestureDetector(
      key: const ValueKey('control-hero-vehicle-switch'),
      onTap: onVehicleSwitch,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Image.asset(
              'assets/official_tailg/ic_control_pup_select.png',
              width: 12,
              height: 12,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        Flexible(
          child: Semantics(
            label: '$displayName，切换车辆',
            button: true,
            enabled: onVehicleSwitch != null,
            onTap: onVehicleSwitch,
            child: ExcludeSemantics(child: vehicleSwitch),
          ),
        ),
        const Spacer(),
        if (displayConn != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
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
        _TopIconButton(
          asset: 'assets/official_tailg/ic_control_detail.png',
          icon: Icons.more_horiz,
          semanticsLabel: '车辆详情',
          onTap: onVehicleSwitch,
        ),
        const SizedBox(width: 8),
        _TopIconButton(
          asset: 'assets/official_tailg/ic_control_msg_change.png',
          icon: Icons.notifications_outlined,
          semanticsLabel: '车辆消息',
          onTap: onNotification,
        ),
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
        _OfficialMetric(
          label: '剩余电量',
          value: '$batteryLevel',
          unit: '%',
          color: bColor,
          fontSize: pctFontSize,
          fontWeight: pctFontWeight,
        ),
        const SizedBox(width: 34),
        Expanded(
          child: _OfficialMetric(
            label: '预估里程',
            value: '$displayRange',
            unit: 'km',
            color: AppColors.textPrimary,
            fontSize: pctFontSize,
            fontWeight: pctFontWeight,
            footer: displayHealth,
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
          children: [
            Expanded(
              child: _OfficialMetric(
                label: '剩余电量',
                value: '$batteryLevel',
                unit: '%',
                color: bColor,
                fontSize: pctFontSize,
                fontWeight: pctFontWeight,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _OfficialMetric(
                label: '预估里程',
                value: '$displayRange',
                unit: 'km',
                color: AppColors.textPrimary,
                fontSize: pctFontSize,
                fontWeight: pctFontWeight,
                footer: displayHealth,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OfficialMetric extends StatelessWidget {
  const _OfficialMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.fontSize,
    required this.fontWeight,
    this.footer,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.officialTextMuted,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: fontWeight,
                height: 0.95,
                letterSpacing: 0,
                color: color,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: fontSize * 0.08, left: 3),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: fontSize * 0.36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        if (footer != null)
          Text(
            footer!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.officialTextMuted,
            ),
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
          color: const Color(0xFFE0E1E7),
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
  const _TopIconButton({
    this.asset,
    required this.icon,
    required this.semanticsLabel,
    this.onTap,
  });
  final String? asset;
  final IconData icon;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      haptic: false,
      semanticsLabel: semanticsLabel,
      semanticsButton: true,
      semanticsEnabled: onTap != null,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          shape: BoxShape.circle,
        ),
        child: asset == null
            ? Icon(icon, size: 18, color: AppColors.textSecondary)
            : Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    asset!,
                    width: 22,
                    height: 22,
                    errorBuilder: (_, __, ___) =>
                        Icon(icon, size: 18, color: AppColors.textSecondary),
                  ),
                  Opacity(
                    opacity: 0,
                    child: Icon(icon, size: 18, color: AppColors.textSecondary),
                  ),
                ],
              ),
      ),
    );
  }
}
