import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/cloud_vehicle_gate.dart';
import '../widgets/lucide_icon.dart';
import 'battery_details_page.dart';
import 'diagnostic_page.dart';
import 'location_page.dart';
import 'official_cloud_page.dart';
import 'ride_stats_page.dart';
import 'vehicle_settings_page.dart';

const _serviceCardDecoration = BoxDecoration(
  color: CyberHomeColors.card,
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.tile)),
  border: Border.fromBorderSide(BorderSide(color: CyberHomeColors.line)),
);

const _serviceItemTitle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: CyberHomeColors.ink,
);

const _serviceBodyText = TextStyle(
  fontSize: 13,
  height: 1.4,
  color: CyberHomeColors.inkMuted,
);

/// 服务中心 · Cyber home light cockpit.
class ServiceHubPage extends StatelessWidget {
  const ServiceHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPad =
        AppNav.contentBottomPadding + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPad),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '服务中心',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: CyberHomeColors.ink,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text('定位 · 轨迹 · 车辆 · 能耗', style: _serviceBodyText),
                ],
              ),
            ),

            const _ServiceSectionLabel('定位服务'),
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

            const _ServiceSectionLabel('车辆与能耗'),
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

            const _ServiceSectionLabel('更多'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: _serviceCardDecoration,
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
    );
  }
}

class _MoreServicesPage extends StatelessWidget {
  const _MoreServicesPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
              child: Row(
                children: [
                  AppPressable(
                    key: const ValueKey('more-services-back'),
                    onTap: () => Navigator.pop(context),
                    semanticsLabel: '返回',
                    semanticsButton: true,
                    child: Container(
                      width: AppTouchTargets.min,
                      height: AppTouchTargets.min,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: CyberHomeColors.card,
                        boxShadow: AppShadows.cyberActionShadow,
                      ),
                      child: const LucideIcon(
                        Lucide.arrowLeft,
                        size: 20,
                        color: CyberHomeColors.inkSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '更多服务',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: CyberHomeColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: _serviceCardDecoration,
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
                    color: CyberHomeColors.line,
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
                    color: CyberHomeColors.line,
                  ),
                  _ServiceListTile(
                    icon: Lucide.help,
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

class _ServiceSectionLabel extends StatelessWidget {
  const _ServiceSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: CyberHomeColors.inkMuted,
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: _serviceCardDecoration,
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
      borderRadius: BorderRadius.circular(AppRadii.tile),
      pressedBackground: CyberHomeColors.cardMuted,
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
                color: CyberHomeColors.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(color: CyberHomeColors.line),
              ),
              child: LucideIcon(
                item.icon,
                color: CyberHomeColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CyberHomeColors.ink,
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
      borderRadius: BorderRadius.circular(AppRadii.tile),
      pressedBackground: CyberHomeColors.cardMuted,
      semanticsLabel: title,
      semanticsButton: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            Container(
              width: AppTouchTargets.min,
              height: AppTouchTargets.min,
              decoration: BoxDecoration(
                color: CyberHomeColors.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(color: CyberHomeColors.line),
              ),
              child: LucideIcon(icon, color: CyberHomeColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _serviceItemTitle),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _serviceBodyText,
                  ),
                ],
              ),
            ),
            const LucideIcon(
              Lucide.chevronRight,
              color: CyberHomeColors.inkFaint,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
