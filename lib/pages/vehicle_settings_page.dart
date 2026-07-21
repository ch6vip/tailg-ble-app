import 'dart:async';

import 'package:flutter/material.dart';
import '../main.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_snack.dart';
import 'notification_prefs_page.dart';
import 'induction_settings_page.dart';

class VehicleSettingsPage extends StatelessWidget {
  const VehicleSettingsPage({super.key});

  Future<void> _unbind(BuildContext context) async {
    final vehicle = officialCloudService.state.selectedVehicle;
    if (vehicle == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解绑车辆'),
        content: Text('确认解绑「${vehicle.displayName}」？此操作走官方 bikeUnbind。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('解绑'),
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
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '车辆设置'),
            Expanded(
              child: StreamBuilder<OfficialCloudState>(
                stream: officialCloudService.stateStream,
                initialData: officialCloudService.state,
                builder: (context, snapshot) {
                  final state = snapshot.data!;
                  final vehicle = state.selectedVehicle;
                  if (vehicle == null) {
                    return const AppEmptyState(
                      icon: Icons.directions_bike,
                      title: '未选择车辆',
                      subtitle: '请先在官方云端登录并选择一辆车',
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    children: [
                      AppCard(
                        margin: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.displayName,
                              style: AppTextStyles.itemTitle,
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              label: '车架号',
                              value: vehicle.frame.isEmpty
                                  ? '未知'
                                  : vehicle.frame,
                            ),
                            _InfoRow(
                              label: 'IMEI',
                              value: vehicle.imei.isEmpty ? '未知' : vehicle.imei,
                            ),
                            _InfoRow(
                              label: 'modelType',
                              value: '${vehicle.modelType ?? '-'}',
                            ),
                            _InfoRow(label: '状态', value: vehicle.onlineLabel),
                            _InfoRow(label: '设防', value: vehicle.defenceLabel),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppCard(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.notifications_outlined,
                            color: AppColors.textSecondary,
                          ),
                          title: const Text(
                            '通知偏好',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            '管理消息推送类型',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.textTertiary,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const NotificationPrefsPage(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.sensors,
                            color: AppColors.textSecondary,
                          ),
                          title: const Text(
                            '感应解锁',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            '感应 / 手动 · 靠近解锁 · 距离',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const InductionSettingsPage(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.link_off,
                            color: AppColors.danger,
                          ),
                          title: const Text(
                            '解绑车辆',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
                            ),
                          ),
                          subtitle: const Text(
                            '官方 app/car/bikeUnbind',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          onTap: () => unawaited(_unbind(context)),
                        ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
