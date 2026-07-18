import 'package:flutter/material.dart';
import 'dart:async';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../widgets/app_chrome.dart';
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
/// 信息架构（避免一张「大白卡」塞满等权入口）：
/// - 定位服务：定位 / 轨迹 / 围栏（核心车务，三列轻网格）
/// - 车辆与能耗：设置 / 电池 / 骑行统计
/// - 更多：一级只露「更多服务」；故障诊断 / 官方账号 / 售后 为二级入口
///
/// 视觉对齐设置页：section label 在卡外，内容用 elevation 白卡。
/// 入口权限门槛仍走 [openCloudGatedPage]。
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
              padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                '定位、轨迹、车辆设置和维护服务',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            // ── 定位服务（核心三入口） ──────────────────────────────────────
            const AppSectionLabel('定位服务'),
            _GlyphSection(
              items: [
                _GlyphItem(
                  icon: Icons.location_on_outlined,
                  label: '车辆定位',
                  onTap: () => openCloudGatedPage(
                    context,
                    const LocationPage(initialTab: LocationInitialTab.map),
                  ),
                ),
                _GlyphItem(
                  icon: Icons.route_outlined,
                  label: '历史轨迹',
                  onTap: () => openCloudGatedPage(
                    context,
                    const LocationPage(initialTab: LocationInitialTab.travel),
                  ),
                ),
                _GlyphItem(
                  icon: Icons.fence_outlined,
                  label: '电子围栏',
                  onTap: () => openCloudGatedPage(
                    context,
                    const LocationPage(initialTab: LocationInitialTab.fence),
                  ),
                ),
              ],
            ),

            // ── 车辆与能耗 ────────────────────────────────────────────────
            const AppSectionLabel('车辆与能耗'),
            _GlyphSection(
              items: [
                _GlyphItem(
                  icon: Icons.tune_rounded,
                  label: '车辆设置',
                  onTap: () =>
                      openCloudGatedPage(context, const VehicleSettingsPage()),
                ),
                _GlyphItem(
                  icon: Icons.battery_charging_full_rounded,
                  label: '电池服务',
                  onTap: () =>
                      openCloudGatedPage(context, const BatteryDetailsPage()),
                ),
                _GlyphItem(
                  icon: Icons.bar_chart_rounded,
                  label: '骑行统计',
                  onTap: () =>
                      openCloudGatedPage(context, const RideStatsPage()),
                ),
              ],
            ),

            // ── 更多：一级入口 → 二级页 ─────────────────────────────────────
            const AppSectionLabel('更多'),
            AppCard(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _ServiceListTile(
                icon: Icons.apps_outlined,
                title: '更多服务',
                subtitle: '故障诊断、官方账号、售后服务',
                onTap: () {
                  unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _MoreServicesPage(),
                      ),
                    ),
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

// ═══════════════════════════════════════════════════════════════════════════
// Secondary entries (二级入口) — revealed only after tapping「更多服务」
// ═══════════════════════════════════════════════════════════════════════════
class _MoreServicesPage extends StatelessWidget {
  const _MoreServicesPage();

  static const _pageBg = Color(0xFFF5F6F8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const AppPageHeader(title: '更多服务'),
            const SizedBox(height: 8),
            AppCard(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _ServiceListTile(
                    icon: Icons.health_and_safety_outlined,
                    title: '故障诊断',
                    subtitle: '车辆健康与异常排查',
                    onTap: () =>
                        openCloudGatedPage(context, const DiagnosticPage()),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 60,
                    color: AppColors.hairline,
                  ),
                  _ServiceListTile(
                    icon: Icons.cloud_outlined,
                    title: '官方账号',
                    subtitle: '云端登录与账号同步',
                    onTap: () => openCloudGatedPage(
                      context,
                      const OfficialCloudPage(),
                      requireVehicle: false,
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 60,
                    color: AppColors.hairline,
                  ),
                  _ServiceListTile(
                    icon: Icons.support_agent_outlined,
                    title: '售后服务',
                    subtitle: '非复刻范围 · 请使用官方渠道',
                    onTap: () => AppSnack.outOfReplicaScope(context, '售后服务'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Glyph section (3 equal items, quiet mono soft circles)
// ═══════════════════════════════════════════════════════════════════════════
class _GlyphSection extends StatelessWidget {
  const _GlyphSection({required this.items});

  final List<_GlyphItem> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        children: [
          for (final item in items) Expanded(child: _GlyphTile(item: item)),
        ],
      ),
    );
  }
}

class _GlyphItem {
  const _GlyphItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _GlyphTile extends StatelessWidget {
  const _GlyphTile({required this.item});

  final _GlyphItem item;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: item.onTap,
      pressedScale: AppMotion.pressScale,
      borderRadius: BorderRadius.circular(AppRadii.md),
      pressedBackground: const Color(0x080F1620),
      semanticsLabel: item.label,
      semanticsButton: true,
      child: SizedBox(
        height: 86,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                color: AppColors.textSecondary,
                size: AppIconSizes.lg,
              ),
            ),
            const SizedBox(height: 8),
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
