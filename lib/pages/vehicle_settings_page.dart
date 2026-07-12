import 'package:flutter/material.dart';
import '../main.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import 'notification_prefs_page.dart';

class VehicleSettingsPage extends StatelessWidget {
  const VehicleSettingsPage({super.key});

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
