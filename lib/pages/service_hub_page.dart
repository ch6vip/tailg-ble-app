import 'package:flutter/material.dart';
import 'dart:async';

import '../theme/app_colors.dart';
import '../theme/app_void.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/cloud_vehicle_gate.dart';
import '../widgets/lucide_icon.dart';
import '../widgets/void_canvas.dart';
import 'battery_details_page.dart';
import 'diagnostic_page.dart';
import 'location_page.dart';
import 'official_cloud_page.dart';
import 'ride_stats_page.dart';
import 'vehicle_settings_page.dart';

/// 服务中心 · VOID COCKPIT
///
/// Experimental service lattice on an immersive canvas.
/// Lucide icons only. No emoji.
class ServiceHubPage extends StatelessWidget {
  const ServiceHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPad =
        AppNav.contentBottomPadding + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: VoidColors.voidDeep,
      body: VoidCanvas(
        child: SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomPad),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  VoidSpace.screenX,
                  20,
                  VoidSpace.screenX,
                  6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SERVICES', style: VoidType.micro),
                    const SizedBox(height: 10),
                    Text('服务中心', style: VoidType.hero.copyWith(fontSize: 34)),
                    const SizedBox(height: 8),
                    Text(
                      '定位 · 轨迹 · 车辆 · 能耗 — 全部车务入口',
                      style: VoidType.body,
                    ),
                  ],
                ),
              ),

              const VoidSectionLabel('定位服务'),
              _GlyphSection(
                items: [
                  _GlyphItem(
                    icon: Lucide.mapPin,
                    label: '车辆定位',
                    onTap: () => openCloudGatedPage(
                      context,
                      const LocationPage(initialTab: LocationInitialTab.map),
                    ),
                  ),
                  _GlyphItem(
                    icon: Lucide.route,
                    label: '历史轨迹',
                    onTap: () => openCloudGatedPage(
                      context,
                      const LocationPage(initialTab: LocationInitialTab.travel),
                    ),
                  ),
                  _GlyphItem(
                    icon: Lucide.fence,
                    label: '电子围栏',
                    onTap: () => openCloudGatedPage(
                      context,
                      const LocationPage(initialTab: LocationInitialTab.fence),
                    ),
                  ),
                ],
              ),

              const VoidSectionLabel('车辆与能耗'),
              _GlyphSection(
                items: [
                  _GlyphItem(
                    icon: Lucide.tune,
                    label: '车辆设置',
                    onTap: () =>
                        openCloudGatedPage(context, const VehicleSettingsPage()),
                  ),
                  _GlyphItem(
                    icon: Lucide.battery,
                    label: '电池服务',
                    onTap: () =>
                        openCloudGatedPage(context, const BatteryDetailsPage()),
                  ),
                  _GlyphItem(
                    icon: Lucide.chart,
                    label: '骑行统计',
                    onTap: () =>
                        openCloudGatedPage(context, const RideStatsPage()),
                  ),
                ],
              ),

              const VoidSectionLabel('更多'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: VoidSpace.screenX),
                child: VoidGlass(
                  radius: VoidRadii.lg,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _ServiceListTile(
                    icon: Lucide.more,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreServicesPage extends StatelessWidget {
  const _MoreServicesPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VoidColors.voidDeep,
      body: VoidCanvas(
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, VoidSpace.screenX, 8),
                child: Row(
                  children: [
                    AppPressable(
                      onTap: () => Navigator.pop(context),
                      pressedScale: VoidMotion.pressScale,
                      semanticsLabel: '返回',
                      semanticsButton: true,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: VoidColors.voidPanel.withValues(alpha: 0.8),
                          border: Border.all(color: VoidColors.hairline),
                        ),
                        child: const LucideIcon(
                          Lucide.arrowLeft,
                          size: 18,
                          color: VoidColors.inkMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('更多服务', style: VoidType.hero.copyWith(fontSize: 22)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: VoidSpace.screenX),
                child: VoidGlass(
                  radius: VoidRadii.lg,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _ServiceListTile(
                        icon: Lucide.stethoscope,
                        title: '故障诊断',
                        subtitle: '车辆健康与异常排查',
                        onTap: () =>
                            openCloudGatedPage(context, const DiagnosticPage()),
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 60,
                        color: VoidColors.hairline,
                      ),
                      _ServiceListTile(
                        icon: Lucide.cloud,
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
                        color: VoidColors.hairline,
                      ),
                      _ServiceListTile(
                        icon: Lucide.help,
                        title: '售后服务',
                        subtitle: '非复刻范围 · 请使用官方渠道',
                        onTap: () =>
                            AppSnack.outOfReplicaScope(context, '售后服务'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlyphSection extends StatelessWidget {
  const _GlyphSection({required this.items});

  final List<_GlyphItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VoidSpace.screenX),
      child: VoidGlass(
        radius: VoidRadii.lg,
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
        child: Row(
          children: [
            for (final item in items) Expanded(child: _GlyphTile(item: item)),
          ],
        ),
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
      pressedScale: VoidMotion.pressScale,
      borderRadius: BorderRadius.circular(VoidRadii.md),
      semanticsLabel: item.label,
      semanticsButton: true,
      child: SizedBox(
        height: 96,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: VoidColors.voidPanelHi,
                shape: BoxShape.circle,
                border: Border.all(color: VoidColors.hairline),
              ),
              child: LucideIcon(
                item.icon,
                color: VoidColors.energy,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: VoidType.bodyStrong.copyWith(fontSize: 12),
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
      pressedScale: VoidMotion.pressScale,
      borderRadius: BorderRadius.circular(VoidRadii.md),
      semanticsLabel: title,
      semanticsButton: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: VoidColors.voidPanelHi,
                shape: BoxShape.circle,
                border: Border.all(color: VoidColors.hairline),
              ),
              child: LucideIcon(icon, color: VoidColors.energy, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: VoidType.bodyStrong),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: VoidType.caption,
                  ),
                ],
              ),
            ),
            const LucideIcon(
              Lucide.chevronRight,
              color: VoidColors.inkFaint,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
