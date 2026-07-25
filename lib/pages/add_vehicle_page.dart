import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/lucide_icon.dart';
import 'bind_imei_page.dart';
import 'official_cloud_page.dart';

const _addVehicleCardDecoration = BoxDecoration(
  color: CyberHomeColors.card,
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.tile)),
  border: Border.fromBorderSide(BorderSide(color: CyberHomeColors.line)),
);

const _addVehicleTitle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: CyberHomeColors.ink,
);

const _addVehicleBody = TextStyle(
  fontSize: 13,
  height: 1.45,
  color: CyberHomeColors.inkMuted,
);

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

  void _openImeiBind(BuildContext context) {
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const BindImeiPage()),
      ),
    );
  }

  void _openBleScan(BuildContext context) {
    openScanTab(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            const _AddVehicleHeader(),
            const SizedBox(height: 10),
            const _AddVehicleHero(),
            const SizedBox(height: 18),
            const _AddVehicleSectionLabel('已有车辆'),
            const SizedBox(height: 8),
            Container(
              decoration: _addVehicleCardDecoration,
              child: _AddVehicleAction(
                icon: Lucide.cloud,
                title: '我的车辆',
                subtitle: '登录官方账号后同步账号下已绑定车辆',
                onTap: () => _openOfficialVehicles(context),
              ),
            ),
            const SizedBox(height: 18),
            const _AddVehicleSectionLabel('绑定新车'),
            const SizedBox(height: 8),
            Container(
              decoration: _addVehicleCardDecoration,
              child: _AddVehicleAction(
                icon: Lucide.pin,
                title: 'IMEI 绑车',
                subtitle: '手写/粘贴坐垫二维码中的设备 IMEI（官方 bikeBind）',
                onTap: () => _openImeiBind(context),
              ),
            ),
            const SizedBox(height: 18),
            const _AddVehicleSectionLabel('蓝牙车辆'),
            const SizedBox(height: 8),
            Container(
              decoration: _addVehicleCardDecoration,
              child: _AddVehicleAction(
                icon: Lucide.bluetoothSearching,
                title: '扫描附近车辆',
                subtitle: '通过蓝牙扫描并连接本地车辆',
                onTap: () => _openBleScan(context),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CyberHomeColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadii.tile),
                border: Border.all(color: CyberHomeColors.line),
              ),
              child: const Text(
                '支持官方云端同步、IMEI 绑定与本地蓝牙直连。蓝牙连接成功后会绑定为默认本地车辆，控车优先走 BLE。',
                style: _addVehicleBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddVehicleHeader extends StatelessWidget {
  const _AddVehicleHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
      child: Row(
        children: [
          Tooltip(
            message: '返回',
            excludeFromSemantics: true,
            child: AppPressable(
              key: const ValueKey('add-vehicle-back'),
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
                  color: CyberHomeColors.inkSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '添加车辆',
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

class _AddVehicleSectionLabel extends StatelessWidget {
  const _AddVehicleSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: CyberHomeColors.inkMuted,
      ),
    );
  }
}

class _AddVehicleHero extends StatelessWidget {
  const _AddVehicleHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _addVehicleCardDecoration,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: CyberHomeColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const LucideIcon(
              Lucide.vehicle,
              color: CyberHomeColors.primary,
              size: AppIconSizes.lg,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('同步你的台铃车辆', style: _addVehicleTitle),
                SizedBox(height: 4),
                Text('登录官方账号后，可使用控车、定位、轨迹、电池和车辆服务。', style: _addVehicleBody),
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
      pressedBackground: CyberHomeColors.cardMuted,
      borderRadius: BorderRadius.circular(AppRadii.tile),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: CyberHomeColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              child: LucideIcon(icon, color: CyberHomeColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _addVehicleTitle),
                  const SizedBox(height: 3),
                  Text(subtitle, style: _addVehicleBody),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const LucideIcon(
              Lucide.chevronRight,
              color: CyberHomeColors.inkFaint,
              size: AppIconSizes.md,
            ),
          ],
        ),
      ),
    );
  }
}
