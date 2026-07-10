import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import 'official_cloud_page.dart';

class AddVehiclePage extends StatelessWidget {
  const AddVehiclePage({super.key});

  void _openOfficialVehicles(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const OfficialCloudPage()),
    );
  }

  void _showPending(BuildContext context, String label) {
    AppSnack.info(context, '$label暂未开放，请先登录账号同步已绑定车辆');
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
            const AppSectionLabel('绑定方式'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _AddVehicleAction(
                    icon: Icons.qr_code_scanner,
                    title: '扫码绑定',
                    subtitle: '暂未开放，请先登录同步车辆',
                    onTap: () => _showPending(context, '扫码绑定'),
                  ),
                  const _InsetDivider(),
                  _AddVehicleAction(
                    icon: Icons.confirmation_number_outlined,
                    title: '输入车架号/IMEI',
                    subtitle: '暂未开放，请先登录同步车辆',
                    onTap: () => _showPending(context, '手动绑定'),
                  ),
                  const _InsetDivider(),
                  _AddVehicleAction(
                    icon: Icons.storefront_outlined,
                    title: '门店购车绑定',
                    subtitle: '暂未开放，请先登录同步车辆',
                    onTap: () => _showPending(context, '门店绑定'),
                  ),
                ],
              ),
            ),
            const AppSectionLabel('已有车辆'),
            AppCard(
              padding: EdgeInsets.zero,
              child: _AddVehicleAction(
                icon: Icons.cloud_done_outlined,
                title: '我的车辆',
                subtitle: '登录后自动显示账号下已绑定车辆',
                onTap: () => _openOfficialVehicles(context),
              ),
            ),
            const AppSectionLabel('辅助方式'),
            AppCard(
              padding: EdgeInsets.zero,
              child: _AddVehicleAction(
                icon: Icons.help_outline,
                title: '绑定帮助',
                subtitle: '暂未开放，请先登录同步车辆',
                onTap: () => _showPending(context, '绑定帮助'),
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
                Text('绑定你的台铃车辆', style: AppTextStyles.itemTitle),
                SizedBox(height: 4),
                Text(
                  '完成绑定后可使用控车、定位、轨迹、电池和车辆服务。',
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

class _InsetDivider extends StatelessWidget {
  const _InsetDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 70,
      color: AppColors.border,
    );
  }
}
