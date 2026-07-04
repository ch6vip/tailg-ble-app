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

extension _StatusBadgeTypeTokens on StatusBadgeType {
  Color get dotColor => switch (this) {
    StatusBadgeType.armed || StatusBadgeType.offline => AppColors.energyRed,
    StatusBadgeType.idle => AppColors.textTertiary,
    StatusBadgeType.ble || StatusBadgeType.online => AppColors.energyGreen,
  };

  Color get bgColor => switch (this) {
    StatusBadgeType.armed ||
    StatusBadgeType.offline => AppColors.surfaceBrandRedTint,
    StatusBadgeType.idle => AppColors.surfaceContainerHigh,
    StatusBadgeType.ble ||
    StatusBadgeType.online => AppColors.surfaceBrandTealTint,
  };

  /// Only armed, ble, and online states are "active" — their dot should pulse.
  /// Idle and offline are static states and use a static dot.
  bool get isActive => switch (this) {
    StatusBadgeType.armed ||
    StatusBadgeType.ble ||
    StatusBadgeType.online => true,
    StatusBadgeType.idle || StatusBadgeType.offline => false,
  };

  String get defaultLabel => switch (this) {
    StatusBadgeType.armed => '已设防',
    StatusBadgeType.idle => '未通电',
    StatusBadgeType.ble => '蓝牙直连',
    StatusBadgeType.online => '在线',
    StatusBadgeType.offline => '离线',
  };
}

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

  @override
  Widget build(BuildContext context) {
    final displayLabel = label ?? type.defaultLabel;
    final badge = _StatusBadgeVisual(
      displayLabel: displayLabel,
      dotColor: type.dotColor,
      bgColor: type.bgColor,
      showDot: showDot,
      compact: compact,
      pulsing: type.isActive,
    );

    return Semantics(
      container: true,
      label: '车辆状态：$displayLabel',
      child: ExcludeSemantics(child: badge),
    );
  }
}

class _StatusBadgeVisual extends StatelessWidget {
  const _StatusBadgeVisual({
    required this.displayLabel,
    required this.dotColor,
    required this.bgColor,
    required this.showDot,
    required this.compact,
    required this.pulsing,
  });

  final String displayLabel;
  final Color dotColor;
  final Color bgColor;
  final bool showDot;
  final bool compact;
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
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
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            displayLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dotColor,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: showDot ? 10 : 12, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            _PulsingDot(color: dotColor, pulsing: pulsing),
            const SizedBox(width: 5),
          ],
          Text(
            displayLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dotColor,
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
  void didUpdateWidget(covariant _PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing != oldWidget.pulsing) {
      if (widget.pulsing) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.stop();
        _ctrl.value = 0;
      }
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
