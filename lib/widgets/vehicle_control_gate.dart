import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'app_pressable.dart';

/// 爱车空态 / 门控（PLAN P1-1）：未登录 / 无车 / 刷新中 / 错误。
enum VehicleControlHomeGateKind {
  signedOut,
  noVehicle,
  loading,
  error,
  nearField,
  none,
}

class VehicleControlHomeGate {
  const VehicleControlHomeGate._();

  static VehicleControlHomeGateKind resolve({
    required bool signedIn,
    required bool hasVehicle,
    required bool loading,
    String? error,
    required bool showNearFieldHint,
  }) {
    if (!signedIn) return VehicleControlHomeGateKind.signedOut;
    if (loading && !hasVehicle) return VehicleControlHomeGateKind.loading;
    final err = error?.trim() ?? '';
    if (err.isNotEmpty && !hasVehicle) {
      return VehicleControlHomeGateKind.error;
    }
    if (!hasVehicle) return VehicleControlHomeGateKind.noVehicle;
    if (showNearFieldHint) return VehicleControlHomeGateKind.nearField;
    return VehicleControlHomeGateKind.none;
  }
}

/// Shared banner used by 爱车 empty/gate states.
class VehicleControlGateBanner extends StatelessWidget {
  const VehicleControlGateBanner({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.busy = false,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0B4F8A),
              ),
            ),
          ),
          AppPressable(
            onTap: busy ? null : onAction,
            enabled: !busy,
            pressedScale: AppMotion.pressScale,
            semanticsLabel: actionLabel,
            semanticsButton: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: busy ? AppColors.textSecondary : const Color(0xFF1A73E8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
