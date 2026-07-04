import 'package:flutter/material.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

/// Official control-page header replica.
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

  /// Battery level 0-100.
  final int batteryLevel;

  /// Estimated range in km.
  final int? rangeKm;

  /// Kept for API compatibility; the official header does not render it.
  final String? healthLabel;

  /// Current vehicle name.
  final String? vehicleName;

  /// Connection status label from the control channel.
  final String? connectionLabel;

  final VoidCallback? onVehicleSwitch;
  final VoidCallback? onBatteryTap;
  final VoidCallback? onNotification;

  static Color batteryColor(int level) {
    if (level >= 30) return AppColors.textPrimary;
    return AppColors.brandRed;
  }

  static Color barColor(int level) {
    if (level >= 30) return AppColors.brandRed;
    return AppColors.energyRed;
  }

  static String batteryAsset(int level) {
    if (level >= 90) return 'assets/official_tailg/ic_control_power_100.png';
    if (level >= 70) return 'assets/official_tailg/ic_control_power_80.png';
    if (level >= 50) return 'assets/official_tailg/ic_control_power_60.png';
    if (level >= 30) return 'assets/official_tailg/ic_control_power_40.png';
    if (level > 0) return 'assets/official_tailg/ic_control_power_20.png';
    return 'assets/official_tailg/ic_control_power_0.png';
  }

  @override
  Widget build(BuildContext context) {
    final displayRange = rangeKm ?? 0;
    final displayName = vehicleName ?? '我的车辆';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 360;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopBar(
                displayName: displayName,
                onVehicleSwitch: onVehicleSwitch,
                onNotification: onNotification,
              ),
              SizedBox(height: wide ? 16 : 12),
              Semantics(
                label: '电量 $batteryLevel%，续航 $displayRange km',
                button: onBatteryTap != null,
                enabled: onBatteryTap != null,
                onTap: onBatteryTap,
                child: ExcludeSemantics(
                  child: GestureDetector(
                    onTap: onBatteryTap,
                    behavior: HitTestBehavior.opaque,
                    child: wide
                        ? _WideHeroData(
                            batteryLevel: batteryLevel,
                            displayRange: displayRange,
                            connectionLabel: connectionLabel,
                          )
                        : _NarrowHeroData(
                            batteryLevel: batteryLevel,
                            displayRange: displayRange,
                            connectionLabel: connectionLabel,
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.displayName,
    this.onVehicleSwitch,
    this.onNotification,
  });

  final String displayName;
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
            const SizedBox(width: 8),
            Image.asset(
              'assets/official_tailg/ic_control_pup_select.png',
              width: 13,
              height: 13,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(width: 10),
              const _OnlineBadge(),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _TopIconButton(
          asset: 'assets/official_tailg/ic_control_detail.png',
          icon: Icons.pedal_bike_outlined,
          semanticsLabel: '车辆详情',
          onTap: onVehicleSwitch,
        ),
        const SizedBox(width: 12),
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
    required this.displayRange,
    required this.connectionLabel,
  });

  final int batteryLevel;
  final int displayRange;
  final String? connectionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BatteryIconMetric(level: batteryLevel),
        const SizedBox(width: 46),
        _RangeMetric(value: displayRange),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _ConnectionPill(label: connectionLabel),
        ),
      ],
    );
  }
}

class _NarrowHeroData extends StatelessWidget {
  const _NarrowHeroData({
    required this.batteryLevel,
    required this.displayRange,
    required this.connectionLabel,
  });

  final int batteryLevel;
  final int displayRange;
  final String? connectionLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BatteryIconMetric(level: batteryLevel),
            const SizedBox(width: 34),
            Expanded(child: _RangeMetric(value: displayRange)),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: _ConnectionPill(label: connectionLabel),
        ),
      ],
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF31C764),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '在线',
        style: TextStyle(
          fontSize: 14,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _BatteryIconMetric extends StatelessWidget {
  const _BatteryIconMetric({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '剩余电量',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.officialTextMuted,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        Image.asset(
          ControlPageHero.batteryAsset(level),
          width: 42,
          height: 30,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.battery_full_outlined,
            size: 36,
            color: level <= 20 ? AppColors.brandRed : const Color(0xFF31C764),
          ),
        ),
      ],
    );
  }
}

class _RangeMetric extends StatelessWidget {
  const _RangeMetric({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '预估里程',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.officialTextMuted,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 0.95,
                letterSpacing: 0,
                color: Color(0xFF252525),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 2, left: 2),
              child: Text(
                'km',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF252525),
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final normalized = label?.trim();
    final text = normalized == '重连中' ? '重连中' : '连接中';
    return Container(
      height: 42,
      constraints: const BoxConstraints(minWidth: 116),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 23,
            height: 23,
            child: CircularProgressIndicator(
              value: 0.74,
              strokeWidth: 3,
              backgroundColor: Colors.transparent,
              color: const Color(0xFF202124),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              color: AppColors.textPrimary,
            ),
          ),
        ],
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
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: asset == null
              ? Icon(icon, size: 26, color: AppColors.textPrimary)
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      asset!,
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          Icon(icon, size: 26, color: AppColors.textPrimary),
                    ),
                    Opacity(
                      opacity: 0,
                      child: Icon(icon, size: 26, color: AppColors.textPrimary),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
