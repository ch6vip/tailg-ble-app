import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/official_vehicle.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/lucide_icon.dart';
import 'induction_settings_page.dart';
import 'notification_prefs_page.dart';

class VehicleSettingsPage extends StatelessWidget {
  const VehicleSettingsPage({super.key});

  Future<void> _unbind(BuildContext context) async {
    final vehicle = officialCloudService.state.selectedVehicle;
    if (vehicle == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberHomeColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
        ),
        title: const Text(
          '解绑车辆',
          style: TextStyle(
            color: CyberHomeColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '解绑后将无法继续查看或控制「${vehicle.displayName}」。确认解绑？',
          style: const TextStyle(color: CyberHomeColors.inkMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: CyberHomeColors.inkMuted,
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: CyberHomeColors.danger,
              foregroundColor: CyberHomeColors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认解绑'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await officialCloudService.unbindVehicle(carId: vehicle.carId);
      if (!context.mounted) return;
      AppSnack.success(context, '已解绑并刷新列表');
    } catch (e) {
      if (!context.mounted) return;
      AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const _SettingsHeader(),
            Expanded(
              child: StreamBuilder<OfficialCloudState>(
                stream: officialCloudService.stateStream,
                initialData: officialCloudService.state,
                builder: (context, snapshot) {
                  final vehicle = snapshot.data!.selectedVehicle;
                  if (vehicle == null) {
                    return const _SettingsEmptyState();
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      _VehicleSummary(vehicle: vehicle),
                      const _SettingsSectionLabel('车辆功能'),
                      _SettingsActionGroup(
                        children: [
                          _SettingsActionRow(
                            icon: Lucide.message,
                            title: '通知偏好',
                            subtitle: '车辆、系统与活动消息',
                            showDivider: true,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const NotificationPrefsPage(),
                              ),
                            ),
                          ),
                          _SettingsActionRow(
                            icon: Lucide.sensors,
                            title: '感应解锁',
                            subtitle: '手动模式、靠近解锁与感应距离',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const InductionSettingsPage(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const _SettingsSectionLabel('车辆管理'),
                      _DangerActionRow(
                        onTap: () => unawaited(_unbind(context)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 8),
      child: Row(
        children: [
          AppPressable(
            key: const ValueKey('vehicle-settings-back'),
            onTap: () => Navigator.of(context).pop(),
            semanticsLabel: '返回',
            semanticsButton: true,
            child: Container(
              width: AppTouchTargets.min,
              height: AppTouchTargets.min,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: CyberHomeColors.card,
                shape: BoxShape.circle,
                boxShadow: AppShadows.cyberActionShadow,
              ),
              child: const LucideIcon(
                Lucide.arrowLeft,
                size: 20,
                color: CyberHomeColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '车辆设置',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: CyberHomeColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleSummary extends StatelessWidget {
  const _VehicleSummary({required this.vehicle});

  final OfficialVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('vehicle-settings-summary'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyberHomeColors.card,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: CyberHomeColors.line),
        boxShadow: AppShadows.cyberCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  vehicle.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: CyberHomeColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(label: vehicle.onlineLabel, active: vehicle.online),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const LucideIcon(
                Lucide.shield,
                size: 15,
                color: CyberHomeColors.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(
                vehicle.defenceLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: CyberHomeColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: CyberHomeColors.line),
          const SizedBox(height: 10),
          _VehicleInfoRow(
            label: '车架号',
            value: vehicle.frame.isEmpty ? '未知' : vehicle.frame,
          ),
          _VehicleInfoRow(
            label: 'IMEI',
            value: vehicle.imei.isEmpty ? '未知' : vehicle.imei,
          ),
          _VehicleInfoRow(
            label: '车型编号',
            value: '${vehicle.modelType ?? '-'}',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? CyberHomeColors.success.withValues(alpha: 0.1)
            : CyberHomeColors.control,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: active
                  ? CyberHomeColors.success
                  : CyberHomeColors.inkFaint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active
                  ? CyberHomeColors.inkSecondary
                  : CyberHomeColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleInfoRow extends StatelessWidget {
  const _VehicleInfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 7, bottom: isLast ? 0 : 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: CyberHomeColors.inkFaint,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CyberHomeColors.inkSecondary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 9),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: CyberHomeColors.inkMuted,
        ),
      ),
    );
  }
}

class _SettingsActionGroup extends StatelessWidget {
  const _SettingsActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CyberHomeColors.card,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: CyberHomeColors.line),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticsLabel: '$title，$subtitle',
      semanticsButton: true,
      child: SizedBox(
        height: 72,
        child: Row(
          children: [
            const SizedBox(width: 14),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: CyberHomeColors.control,
                shape: BoxShape.circle,
              ),
              child: LucideIcon(
                icon,
                size: 20,
                color: CyberHomeColors.inkSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  border: showDivider
                      ? const Border(
                          bottom: BorderSide(color: CyberHomeColors.line),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: CyberHomeColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: CyberHomeColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const LucideIcon(
                      Lucide.chevronRight,
                      size: 18,
                      color: CyberHomeColors.inkFaint,
                    ),
                    const SizedBox(width: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerActionRow extends StatelessWidget {
  const _DangerActionRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticsLabel: '解绑车辆，解除当前账号与车辆的绑定',
      semanticsButton: true,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: CyberHomeColors.danger.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(
            color: CyberHomeColors.danger.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CyberHomeColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const LucideIcon(
                Lucide.unlink,
                size: 20,
                color: CyberHomeColors.danger,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '解绑车辆',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CyberHomeColors.danger,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '解除当前账号与车辆的绑定',
                    style: TextStyle(
                      fontSize: 12,
                      color: CyberHomeColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            const LucideIcon(
              Lucide.chevronRight,
              size: 18,
              color: CyberHomeColors.danger,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsEmptyState extends StatelessWidget {
  const _SettingsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: CyberHomeColors.card,
                shape: BoxShape.circle,
                boxShadow: AppShadows.cyberActionShadow,
              ),
              child: const LucideIcon(
                Lucide.vehicle,
                size: 28,
                color: CyberHomeColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '未选择车辆',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: CyberHomeColors.ink,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              '请先登录并选择一辆车',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: CyberHomeColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
