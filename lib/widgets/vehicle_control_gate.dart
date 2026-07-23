import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_void.dart';
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

/// Shared banner used by 爱车 empty/gate states — VOID glass strip.
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
      margin: const EdgeInsets.fromLTRB(VoidSpace.screenX, 8, VoidSpace.screenX, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: VoidColors.voidPanel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(VoidRadii.md),
        border: Border.all(color: VoidColors.energy.withValues(alpha: 0.28)),
        boxShadow: VoidGlow.energy(intensity: 0.25),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: VoidType.bodyStrong.copyWith(
                fontSize: 13,
                color: VoidColors.ink,
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
                color: busy ? VoidColors.inkFaint : VoidColors.energy,
                borderRadius: BorderRadius.circular(VoidRadii.pill),
                boxShadow: busy ? const [] : VoidGlow.energy(intensity: 0.4),
              ),
              child: Text(
                actionLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: busy ? VoidColors.inkMuted : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
