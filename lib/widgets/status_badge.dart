import 'package:flutter/material.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';

/// Unified status badge for the v8 Ninebot design system.
///
/// Mirrors the HTML `.chip` style:
/// - [StatusBadgeType.armed]  → red dot + "已设防"
/// - [StatusBadgeType.idle]   → grey dot + "未通电"
/// - [StatusBadgeType.ble]    → teal dot + "蓝牙直连"
/// - [StatusBadgeType.online] → teal "在线"
/// - [StatusBadgeType.offline]→ red "离线"
enum StatusBadgeType { armed, idle, ble, online, offline }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.type,
    this.label,
    this.showDot = true,
    this.compact = false,
  });

  final StatusBadgeType type;
  final String? label;
  final bool showDot;

  /// If true, renders smaller and without background card — inline use only.
  final bool compact;

  Color get _dotColor => switch (type) {
    StatusBadgeType.armed || StatusBadgeType.offline => AppColors.energyRed,
    StatusBadgeType.idle => AppColors.textTertiary,
    StatusBadgeType.ble || StatusBadgeType.online => AppColors.energyGreen,
  };

  Color get _bgColor => switch (type) {
    StatusBadgeType.armed ||
    StatusBadgeType.offline => AppColors.surfaceBrandRedTint,
    StatusBadgeType.idle => AppColors.surfaceContainerHigh,
    StatusBadgeType.ble ||
    StatusBadgeType.online => AppColors.surfaceBrandTealTint,
  };

  /// Only armed, ble, and online states are "active" — their dot should pulse.
  /// Idle and offline are static states and use a static dot.
  bool get _isActive => switch (type) {
    StatusBadgeType.armed ||
    StatusBadgeType.ble ||
    StatusBadgeType.online => true,
    StatusBadgeType.idle || StatusBadgeType.offline => false,
  };

  String get _defaultLabel => switch (type) {
    StatusBadgeType.armed => '已设防',
    StatusBadgeType.idle => '未通电',
    StatusBadgeType.ble => '蓝牙直连',
    StatusBadgeType.online => '在线',
    StatusBadgeType.offline => '离线',
  };

  @override
  Widget build(BuildContext context) {
    final displayLabel = label ?? _defaultLabel;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                color: _dotColor,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            displayLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _dotColor,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: showDot ? 10 : 12, vertical: 5),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            _PulsingDot(color: _dotColor, pulsing: _isActive),
            const SizedBox(width: 5),
          ],
          Text(
            displayLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _dotColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing dot indicator — used inside status chips to signal live status.
/// When [pulsing] is false the dot renders static (for idle/offline states).
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, this.pulsing = true});
  final Color color;
  final bool pulsing;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scale = Tween(
      begin: 0.75,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.pulsing) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
