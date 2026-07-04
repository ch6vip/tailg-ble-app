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
    this.online = true,
    this.connectionLabel,
    this.onVehicleSwitch,
    this.onConnect,
    this.onDetail,
    this.onMessage,
  });

  /// Battery level 0-100.
  final int batteryLevel;

  /// Estimated range in km.
  final int? rangeKm;

  /// Kept for API compatibility; the official header does not render it.
  final String? healthLabel;

  /// Current vehicle name.
  final String? vehicleName;

  /// Current cloud online status.
  final bool online;

  /// Connection status label from the control channel.
  final String? connectionLabel;

  final VoidCallback? onVehicleSwitch;
  final VoidCallback? onConnect;
  final VoidCallback? onDetail;
  final VoidCallback? onMessage;

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
                online: online,
                onVehicleSwitch: onVehicleSwitch,
                onDetail: onDetail,
                onMessage: onMessage,
              ),
              SizedBox(height: wide ? 16 : 12),
              Semantics(
                container: true,
                explicitChildNodes: true,
                label: '电量 $batteryLevel%，续航 $displayRange km',
                child: wide
                    ? _WideHeroData(
                        batteryLevel: batteryLevel,
                        displayRange: displayRange,
                        connectionLabel: connectionLabel,
                        onConnect: onConnect,
                      )
                    : _NarrowHeroData(
                        batteryLevel: batteryLevel,
                        displayRange: displayRange,
                        connectionLabel: connectionLabel,
                        onConnect: onConnect,
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
    required this.online,
    this.onVehicleSwitch,
    this.onDetail,
    this.onMessage,
  });

  final String displayName;
  final bool online;
  final VoidCallback? onVehicleSwitch;
  final VoidCallback? onDetail;
  final VoidCallback? onMessage;

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
              _OnlineBadge(online: online),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _TopIconButton(
          asset: 'assets/official_tailg/ic_control_detail.png',
          fallback: Icons.more_horiz,
          label: '车辆详情',
          onTap: onDetail,
        ),
        const SizedBox(width: 14),
        _TopIconButton(
          asset: 'assets/official_tailg/ic_control_msg_change.png',
          fallback: Icons.notifications_none,
          label: '消息',
          onTap: onMessage,
          showDot: true,
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
    this.onConnect,
  });

  final int batteryLevel;
  final int displayRange;
  final String? connectionLabel;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BatteryIconMetric(level: batteryLevel),
        const SizedBox(width: 46),
        _RangeMetric(value: displayRange),
        const Spacer(),
        _BleConnectPill(label: connectionLabel, onTap: onConnect),
      ],
    );
  }
}

class _NarrowHeroData extends StatelessWidget {
  const _NarrowHeroData({
    required this.batteryLevel,
    required this.displayRange,
    required this.connectionLabel,
    this.onConnect,
  });

  final int batteryLevel;
  final int displayRange;
  final String? connectionLabel;
  final VoidCallback? onConnect;

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
            _BleConnectPill(label: connectionLabel, onTap: onConnect),
          ],
        ),
      ],
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.asset,
    required this.fallback,
    required this.label,
    this.onTap,
    this.showDot = false,
  });

  final String asset;
  final IconData fallback;
  final String label;
  final VoidCallback? onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      haptic: false,
      semanticsLabel: label,
      semanticsButton: true,
      semanticsEnabled: onTap != null,
      child: SizedBox(
        width: 30,
        height: 30,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Image.asset(
                asset,
                width: 24,
                height: 24,
                errorBuilder: (_, __, ___) =>
                    Icon(fallback, size: 24, color: AppColors.textPrimary),
              ),
            ),
            if (showDot)
              Positioned(
                top: 2,
                right: 1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.brandRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: online ? const Color(0xFF31C764) : AppColors.officialTextMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        online ? '在线' : '离线',
        style: const TextStyle(
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
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                level.toString(),
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
                  '%',
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
        ),
        const SizedBox(height: 10),
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
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
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
        ),
      ],
    );
  }
}

class _BleConnectPill extends StatelessWidget {
  const _BleConnectPill({required this.label, this.onTap});

  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final connected = label?.trim() == '已连接';
    final connecting = label?.trim() == '连接中';
    final text = connected
        ? '已连接'
        : connecting
        ? '连接中'
        : '点击连接';
    return AppPressable(
      onTap: onTap,
      haptic: false,
      semanticsLabel: text,
      semanticsButton: true,
      semanticsEnabled: onTap != null,
      child: Container(
        height: 33,
        constraints: const BoxConstraints(minWidth: 82),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(17),
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
            Icon(
              connected ? Icons.bluetooth_connected : Icons.bluetooth,
              size: 15,
              color: connected
                  ? const Color(0xFF31C764)
                  : AppColors.officialTextMuted,
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                color: connected
                    ? AppColors.officialTextMuted
                    : AppColors.brandRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
