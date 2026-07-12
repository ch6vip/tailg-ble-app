import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_pressable.dart';
import 'official_cloud_page.dart';

class AddVehiclePage extends StatelessWidget {
  const AddVehiclePage({super.key});

  void _openOfficialVehicles(BuildContext context) {
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const OfficialCloudPage()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppNav.contentBottomPadding),
          children: [
            const AppPageHeader(title: '添加车辆'),
            const SizedBox(height: 10),
            const _AddVehicleHero(),
            const AppSectionLabel('已有车辆'),
            AppCard(
              padding: EdgeInsets.zero,
              child: _AddVehicleAction(
                icon: Icons.cloud_done_outlined,
                title: '我的车辆',
                subtitle: '登录官方账号后同步账号下已绑定车辆',
                onTap: () => _openOfficialVehicles(context),
              ),
            ),
            const SizedBox(height: 14),
            const AppCard(
              child: Text(
                '当前仅支持通过官方账号同步已绑定车辆，不再提供扫码、IMEI 或门店绑定入口。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddVehicleHero extends StatelessWidget {
  const _AddVehicleHero();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.two_wheeler,
              color: AppColors.primary,
              size: AppIconSizes.lg,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('同步你的台铃车辆', style: AppTextStyles.itemTitle),
                SizedBox(height: 4),
                Text(
                  '登录官方账号后，可使用控车、定位、轨迹、电池和车辆服务。',
                  style: AppTextStyles.smallText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddVehicleAction extends StatelessWidget {
  const _AddVehicleAction({
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
      haptic: false,
      semanticsLabel: '$title，$subtitle',
      semanticsButton: true,
      semanticsEnabled: true,
      pressedBackground: AppColors.primary.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.itemTitle),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: AppIconSizes.md,
            ),
          ],
        ),
      ),
    );
  }
}
