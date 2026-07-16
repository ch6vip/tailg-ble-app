import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/cloud_vehicle_gate.dart';
import 'battery_details_page.dart';
import 'diagnostic_page.dart';
import 'location_page.dart';
import 'official_cloud_page.dart';
import 'ride_stats_page.dart';
import 'vehicle_settings_page.dart';

/// 服务中心 · Tailg Aurora
///
/// 布局对齐控车 / 我的页的 Aurora Cockpit 语言：
/// - 页面灰底 + 白卡片 elevation
/// - 圆形 soft glyph 网格
/// - AppPressable 按压反馈
///
/// 入口与权限门槛仍走 [openCloudGatedPage]。
class ServiceHubPage extends StatelessWidget {
  const ServiceHubPage({super.key});

  static const _pageBg = Color(0xFFF5F6F8);

  @override
  Widget build(BuildContext context) {
    final bottomPad =
        AppNav.contentBottomPadding + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPad),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                '服务中心',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                '定位、轨迹、车辆设置和维护服务',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            // ── 常用服务 ────────────────────────────────────────────────
            _ServiceCard(
              title: '常用服务',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 330 ? 3 : 4;
                  final items = <_ServiceItem>[
                    _ServiceItem(
                      icon: Icons.location_on_outlined,
                      label: '车辆定位',
                      color: AppColors.accentSky,
                      onTap: () => openCloudGatedPage(
                        context,
                        const LocationPage(initialTab: LocationInitialTab.map),
                      ),
                    ),
                    _ServiceItem(
                      icon: Icons.route_outlined,
                      label: '历史轨迹',
                      color: AppColors.accentViolet,
                      onTap: () => openCloudGatedPage(
                        context,
                        const LocationPage(
                          initialTab: LocationInitialTab.travel,
                        ),
                      ),
                    ),
                    _ServiceItem(
                      icon: Icons.fence_outlined,
                      label: '电子围栏',
                      color: AppColors.accentAmber,
                      onTap: () => openCloudGatedPage(
                        context,
                        const LocationPage(
                          initialTab: LocationInitialTab.fence,
                        ),
                      ),
                    ),
                    _ServiceItem(
                      icon: Icons.tune_rounded,
                      label: '车辆设置',
                      color: AppColors.inkBtn,
                      onTap: () => openCloudGatedPage(
                        context,
                        const VehicleSettingsPage(),
                      ),
                    ),
                    _ServiceItem(
                      icon: Icons.battery_charging_full_rounded,
                      label: '电池服务',
                      color: AppColors.energyGreen,
                      onTap: () => openCloudGatedPage(
                        context,
                        const BatteryDetailsPage(),
                      ),
                    ),
                    _ServiceItem(
                      icon: Icons.bar_chart_rounded,
                      label: '骑行统计',
                      color: AppColors.accentPurple,
                      onTap: () =>
                          openCloudGatedPage(context, const RideStatsPage()),
                    ),
                    _ServiceItem(
                      icon: Icons.health_and_safety_outlined,
                      label: '故障诊断',
                      color: AppColors.energyRed,
                      onTap: () =>
                          openCloudGatedPage(context, const DiagnosticPage()),
                    ),
                    _ServiceItem(
                      icon: Icons.cloud_outlined,
                      label: '官方账号',
                      color: AppColors.primaryDark,
                      onTap: () => openCloudGatedPage(
                        context,
                        const OfficialCloudPage(),
                        requireVehicle: false,
                      ),
                    ),
                  ];

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      mainAxisExtent: 96,
                    ),
                    itemBuilder: (context, index) {
                      return _ServiceGridTile(item: items[index]);
                    },
                  );
                },
              ),
            ),

            // ── 车辆维护 ────────────────────────────────────────────────
            _ServiceCard(
              title: '车辆维护',
              child: _ServiceListTile(
                icon: Icons.support_agent_outlined,
                title: '售后服务',
                subtitle: '保养、维修和官方服务渠道',
                onTap: () => AppSnack.notYetOpen(context, '售后服务'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Card shell
// ═══════════════════════════════════════════════════════════════════════════
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ServiceItem {
  const _ServiceItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _ServiceGridTile extends StatelessWidget {
  const _ServiceGridTile({required this.item});

  final _ServiceItem item;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: item.onTap,
      pressedScale: AppMotion.pressScale,
      borderRadius: BorderRadius.circular(AppRadii.md),
      pressedBackground: const Color(0x080F1620),
      semanticsLabel: item.label,
      semanticsButton: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: AppIconSizes.md),
          ),
          const SizedBox(height: 9),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: 0.1,
              height: 1.2,
            ),
          ),
        ],
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
      pressedScale: AppMotion.pressScale,
      borderRadius: BorderRadius.circular(AppRadii.md),
      pressedBackground: AppColors.surfaceContainerHigh,
      semanticsLabel: title,
      semanticsButton: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Container(
              width: AppTouchTargets.min,
              height: AppTouchTargets.min,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.textSecondary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFC4C8CD), size: 18),
          ],
        ),
      ),
    );
  }
}
