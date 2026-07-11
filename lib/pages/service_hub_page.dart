import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/cloud_vehicle_gate.dart';
import 'battery_details_page.dart';
import 'diagnostic_page.dart';
import 'location_page.dart';
import 'official_cloud_page.dart';
import 'vehicle_settings_page.dart';

class ServiceHubPage extends StatelessWidget {
  const ServiceHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.officialPageBg,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppNav.contentBottomPadding),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('服务中心', style: AppTextStyles.pageTitle),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                '定位、轨迹、车辆设置和维护服务',
                style: AppTextStyles.bodyMedium.copyWith(height: 1.35),
              ),
            ),
            const AppSectionLabel('常用服务'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 330 ? 3 : 4;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: columns == 3 ? 0.92 : 0.82,
                    children: [
                      _ServiceGridTile(
                        icon: Icons.location_on_outlined,
                        label: '车辆定位',
                        color: AppColors.accentSky,
                        onTap: () => _open(
                          context,
                          const LocationPage(
                            initialTab: LocationInitialTab.map,
                          ),
                        ),
                      ),
                      _ServiceGridTile(
                        icon: Icons.route_outlined,
                        label: '历史轨迹',
                        color: AppColors.accentViolet,
                        onTap: () => _open(
                          context,
                          const LocationPage(
                            initialTab: LocationInitialTab.travel,
                          ),
                        ),
                      ),
                      _ServiceGridTile(
                        icon: Icons.fence_outlined,
                        label: '电子围栏',
                        color: AppColors.accentAmber,
                        onTap: () => _open(
                          context,
                          const LocationPage(
                            initialTab: LocationInitialTab.fence,
                          ),
                        ),
                      ),
                      _ServiceGridTile(
                        icon: Icons.tune,
                        label: '车辆设置',
                        color: AppColors.dark,
                        onTap: () =>
                            _open(context, const VehicleSettingsPage()),
                      ),
                      _ServiceGridTile(
                        icon: Icons.battery_charging_full,
                        label: '电池服务',
                        color: AppColors.energyGreen,
                        onTap: () => _open(context, const BatteryDetailsPage()),
                      ),
                      _ServiceGridTile(
                        icon: Icons.health_and_safety_outlined,
                        label: '故障诊断',
                        color: AppColors.energyRed,
                        onTap: () => _open(context, const DiagnosticPage()),
                      ),
                      _ServiceGridTile(
                        icon: Icons.cloud_outlined,
                        label: '官方账号',
                        color: AppColors.brandRed,
                        onTap: () => _open(
                          context,
                          const OfficialCloudPage(),
                          requireVehicle: false,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const AppSectionLabel('车辆维护'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _ServiceListTile(
                    icon: Icons.support_agent_outlined,
                    title: '售后服务',
                    subtitle: '保养、维修和官方服务渠道',
                    onTap: () => AppSnack.info(context, '售后服务暂未开放'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showUnavailable(BuildContext context, String label) {
    AppSnack.featureUnavailable(context, label);
  }

  static void _open(
    BuildContext context,
    Widget page, {
    bool requireVehicle = true,
  }) {
    if (requireVehicle && !requireCloudVehicle(context)) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _ServiceGridTile extends StatelessWidget {
  const _ServiceGridTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticsLabel: label,
      semanticsButton: true,
      borderRadius: BorderRadius.circular(AppRadii.tile),
      pressedBackground: AppColors.surfaceContainerHigh,
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 9),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceListTile extends StatelessWidget {
  const _ServiceListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      semanticsLabel: title,
      semanticsButton: true,
      borderRadius: BorderRadius.circular(AppRadii.tile),
      pressedBackground: AppColors.surfaceContainerHigh,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.textSecondary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.itemTitle),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(height: 1.25),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
