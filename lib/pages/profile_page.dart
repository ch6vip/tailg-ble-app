import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/official_vehicle.dart';
import '../models/vehicle_profile.dart';
import '../services/official_cloud_service.dart';
import '../services/sensitive_value_masker.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/vehicle_stage.dart';
import 'add_vehicle_page.dart';
import 'app_preferences_pages.dart';
import 'garage_page.dart';
import 'official_cloud_page.dart';
import 'vehicle_message_page.dart';

const _officialInk = Color(0xFF060606);
const _officialStrong = Color(0xFF1F1F1F);
const _officialMuted = Color(0xFF807E89);
const _officialLight = Color(0xFFACABB5);
const _mineCardRadius = 10.0;

/// Official-style "我的" page.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  StreamSubscription<OfficialCloudState>? _cloudSub;
  StreamSubscription<List<VehicleProfile>>? _vehicleSub;
  late OfficialCloudState _cloudState;
  late List<VehicleProfile> _vehicles;

  @override
  void initState() {
    super.initState();
    _cloudState = officialCloudService.state;
    _vehicles = vehicleStore.vehicles;
    _cloudSub = officialCloudService.stateStream.listen((state) {
      if (mounted) setState(() => _cloudState = state);
    });
    _vehicleSub = vehicleStore.vehiclesStream.listen((vehicles) {
      if (mounted) setState(() => _vehicles = vehicles);
    });
  }

  @override
  void dispose() {
    _cloudSub?.cancel();
    _vehicleSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _cloudState.signedIn;
    final officialVehicle = _cloudState.selectedVehicle;
    final localVehicle = _defaultLocalVehicle();

    return Scaffold(
      backgroundColor: AppColors.officialPageBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppNav.contentBottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MineHeader(
                signedIn: signedIn,
                phone: signedIn ? _cloudState.phone : null,
                onProfileTap: () => _handleProfileTap(signedIn),
                onSettingsTap: () => AppSnack.info(context, '设置项在下方列表'),
                onMessageTap: () => _openMessages(context),
              ),
              const _SocialStats(),
              const SizedBox(height: 10),
              _ShortcutPair(onUnavailable: _showUnavailable),
              const SizedBox(height: 10),
              _GaragePanel(
                officialVehicle: officialVehicle,
                localVehicle: localVehicle,
                onGarageTap: () => _openGarage(context),
                onAddVehicle: () => _openAddVehicle(context),
              ),
              const SizedBox(height: 10),
              _FunctionCenter(onUnavailable: _showUnavailable),
              const SizedBox(height: 10),
              _MineActionTile(
                icon: Icons.query_stats_outlined,
                title: '骑行统计',
                minHeight: 88,
                onTap: () => _showUnavailable('骑行统计'),
              ),
              const SizedBox(height: 10),
              _MineActionTile(
                icon: Icons.watch_outlined,
                title: '扫码手表控车',
                minHeight: 70,
                trailingHelp: true,
                onTap: () => _showUnavailable('扫码手表控车'),
              ),
              const SizedBox(height: 10),
              _SettingsSection(onUnavailable: _showUnavailable),
              const SizedBox(height: 14),
              const _LogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  VehicleProfile? _defaultLocalVehicle() {
    final defaultId = vehicleStore.defaultVehicleId;
    if (defaultId != null) {
      for (final vehicle in _vehicles) {
        if (vehicle.id == defaultId) return vehicle;
      }
    }
    return vehicleStore.defaultVehicle ??
        (_vehicles.isEmpty ? null : _vehicles.first);
  }

  void _handleProfileTap(bool signedIn) {
    if (!signedIn) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const OfficialCloudPage()),
      );
      return;
    }
    AppSnack.featureUnavailable(context, '资料编辑');
  }

  void _openMessages(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const VehicleMessagePage()),
    );
  }

  void _openGarage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const GaragePage()),
    );
  }

  void _openAddVehicle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const AddVehiclePage()),
    );
  }

  void _showUnavailable(String label) {
    AppSnack.featureUnavailable(context, label);
  }
}

class _MineHeader extends StatelessWidget {
  const _MineHeader({
    required this.signedIn,
    required this.phone,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onMessageTap,
  });

  final bool signedIn;
  final String? phone;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onMessageTap;

  @override
  Widget build(BuildContext context) {
    final name = signedIn ? '台铃用户' : '立即登录';
    final subtitle = signedIn ? (_maskPhone(phone) ?? '已登录') : '登录后同步车辆和消息';
    final semanticsLabel = signedIn ? '编辑资料' : '登录 / 查看车辆';

    return Container(
      height: 176,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7F9FF), AppColors.officialPageBg],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _HeaderIconButton(
                icon: Icons.settings_outlined,
                label: '设置',
                onTap: onSettingsTap,
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.notifications_none_outlined,
                label: '消息中心',
                showDot: true,
                onTap: onMessageTap,
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppPressable(
            onTap: onProfileTap,
            haptic: false,
            semanticsLabel: semanticsLabel,
            semanticsButton: true,
            semanticsEnabled: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _officialInk,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _officialMuted,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      backgroundColor: Color(0xFFE9EDF4),
                      child: Icon(
                        Icons.person,
                        color: _officialLight,
                        size: 44,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      haptic: false,
      semanticsLabel: label,
      semanticsButton: true,
      semanticsEnabled: true,
      child: SizedBox(
        width: AppTouchTargets.min,
        height: AppTouchTargets.min,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 24, color: _officialStrong),
            if (showDot)
              Positioned(
                right: 11,
                top: 11,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.brandRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SocialStats extends StatelessWidget {
  const _SocialStats();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Row(
        children: [
          Expanded(
            child: _SocialStat(value: '0', label: '发帖'),
          ),
          _StatDivider(),
          Expanded(
            child: _SocialStat(value: '0', label: '关注'),
          ),
          _StatDivider(),
          Expanded(
            child: _SocialStat(value: '0', label: '粉丝'),
          ),
        ],
      ),
    );
  }
}

class _SocialStat extends StatelessWidget {
  const _SocialStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          key: ValueKey('mine-stat-value-$label'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _officialStrong,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: _officialMuted,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 24, color: const Color(0xFFDCDCDC));
  }
}

class _ShortcutPair extends StatelessWidget {
  const _ShortcutPair({required this.onUnavailable});

  final ValueChanged<String> onUnavailable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _ShortcutCard(
              icon: Icons.toll_outlined,
              title: '我的积分',
              subtitle: '赚更多积分',
              color: AppColors.accentAmber,
              onTap: () => onUnavailable('我的积分'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ShortcutCard(
              icon: Icons.event_available_outlined,
              title: '签到中心',
              subtitle: '连续签到抽盲盒',
              color: AppColors.brandRed,
              onTap: () => onUnavailable('签到中心'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      haptic: false,
      semanticsLabel: '$title，$subtitle',
      semanticsButton: true,
      semanticsEnabled: true,
      borderRadius: BorderRadius.circular(_mineCardRadius),
      child: Container(
        height: 70,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_mineCardRadius),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _officialStrong,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _officialMuted,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 15,
                        color: _officialMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(icon, color: color, size: 32),
          ],
        ),
      ),
    );
  }
}

class _GaragePanel extends StatelessWidget {
  const _GaragePanel({
    required this.officialVehicle,
    required this.localVehicle,
    required this.onGarageTap,
    required this.onAddVehicle,
  });

  final OfficialVehicle? officialVehicle;
  final VehicleProfile? localVehicle;
  final VoidCallback onGarageTap;
  final VoidCallback onAddVehicle;

  bool get _hasVehicle => officialVehicle != null || localVehicle != null;

  @override
  Widget build(BuildContext context) {
    final vehicleName =
        officialVehicle?.displayName ?? localVehicle?.displayName ?? '暂无车辆数据';
    final battery = officialVehicle?.electricQuantity;
    final mileage = officialVehicle?.mileage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 184,
        child: Stack(
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.brandRed,
                borderRadius: BorderRadius.circular(_mineCardRadius),
              ),
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '我的车库',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0,
                    ),
                  ),
                  const Spacer(),
                  AppPressable(
                    onTap: onAddVehicle,
                    haptic: false,
                    semanticsLabel: '添加设备',
                    semanticsButton: true,
                    semanticsEnabled: true,
                    child: const SizedBox(
                      height: AppTouchTargets.min,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 17, color: Colors.white),
                          SizedBox(width: 2),
                          Text(
                            '添加设备',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 45,
              child: AppPressable(
                onTap: onGarageTap,
                haptic: false,
                semanticsLabel: '我的车库，$vehicleName',
                semanticsButton: true,
                semanticsEnabled: true,
                borderRadius: BorderRadius.circular(_mineCardRadius),
                child: Container(
                  height: 139,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_mineCardRadius),
                  ),
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 154,
                            height: 139,
                            child: Padding(
                              padding: const EdgeInsets.all(13),
                              child: _VehicleArtwork(hasVehicle: _hasVehicle),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 24, 18, 0),
                              child: _GarageInfo(
                                hasVehicle: _hasVehicle,
                                vehicleName: vehicleName,
                                battery: battery,
                                mileage: mileage,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_hasVehicle)
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.brandRed,
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(_mineCardRadius),
                                bottomLeft: Radius.circular(_mineCardRadius),
                              ),
                            ),
                            child: const Text(
                              '使用中',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleArtwork extends StatelessWidget {
  const _VehicleArtwork({required this.hasVehicle});

  final bool hasVehicle;

  @override
  Widget build(BuildContext context) {
    if (!hasVehicle) {
      return CustomPaint(
        painter: VehicleStagePainter(batteryLevel: 0.0),
        size: Size(128, 86),
      );
    }
    return Image.asset(
      'assets/official_tailg/vehicle.png',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => CustomPaint(
        painter: VehicleStagePainter(batteryLevel: 0.7),
        size: Size(128, 86),
      ),
    );
  }
}

class _GarageInfo extends StatelessWidget {
  const _GarageInfo({
    required this.hasVehicle,
    required this.vehicleName,
    required this.battery,
    required this.mileage,
  });

  final bool hasVehicle;
  final String vehicleName;
  final int? battery;
  final double? mileage;

  @override
  Widget build(BuildContext context) {
    final mileage = this.mileage;
    if (!hasVehicle) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '暂无车辆数据',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _officialMuted,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 14),
          Text(
            '门店购买或绑定后查看',
            style: TextStyle(
              fontSize: 14,
              color: _officialLight,
              letterSpacing: 0,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                vehicleName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _officialInk,
                  letterSpacing: 0,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: _officialMuted),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _VehicleMetric(
              value: battery == null ? '--' : '$battery',
              unit: '%',
              label: '剩余电量',
            ),
            const SizedBox(width: 28),
            _VehicleMetric(
              value: mileage == null ? '--' : mileage.toStringAsFixed(0),
              unit: 'km',
              label: '预估里程',
            ),
          ],
        ),
      ],
    );
  }
}

class _VehicleMetric extends StatelessWidget {
  const _VehicleMetric({
    required this.value,
    required this.unit,
    required this.label,
  });

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _officialInk,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _officialInk,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: _officialLight,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _FunctionCenter extends StatelessWidget {
  const _FunctionCenter({required this.onUnavailable});

  final ValueChanged<String> onUnavailable;

  @override
  Widget build(BuildContext context) {
    return _MineSectionShell(
      height: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 14, 12, 0),
            child: Text(
              '功能中心',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _officialStrong,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                _FunctionEntry(
                  icon: Icons.collections_bookmark_outlined,
                  label: '我的收藏',
                  onTap: () => onUnavailable('我的收藏'),
                ),
                _FunctionEntry(
                  icon: Icons.assignment_outlined,
                  label: '任务中心',
                  onTap: () => onUnavailable('任务中心'),
                ),
                _FunctionEntry(
                  icon: Icons.receipt_long_outlined,
                  label: '我的订单',
                  onTap: () => onUnavailable('我的订单'),
                ),
                _FunctionEntry(
                  icon: Icons.person_add_alt_outlined,
                  label: '邀请好友',
                  onTap: () => onUnavailable('邀请好友'),
                ),
                _FunctionEntry(
                  icon: Icons.confirmation_number_outlined,
                  label: '优惠券',
                  onTap: () => onUnavailable('优惠券'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FunctionEntry extends StatelessWidget {
  const _FunctionEntry({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppPressable(
        onTap: onTap,
        haptic: false,
        semanticsLabel: label,
        semanticsButton: true,
        semanticsEnabled: true,
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: _officialStrong),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: _officialStrong,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MineActionTile extends StatelessWidget {
  const _MineActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.minHeight,
    this.trailingHelp = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final double minHeight;
  final bool trailingHelp;

  @override
  Widget build(BuildContext context) {
    return _MineSectionShell(
      child: _MineListTile(
        icon: icon,
        title: title,
        minHeight: minHeight,
        trailingHelp: trailingHelp,
        onTap: onTap,
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.onUnavailable});

  final ValueChanged<String> onUnavailable;

  @override
  Widget build(BuildContext context) {
    return _MineSectionShell(
      child: Column(
        children: [
          _MineListTile(
            icon: Icons.notifications_none_outlined,
            title: '消息通知',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const VehicleMessagePage(),
              ),
            ),
          ),
          const _MineDivider(),
          _MineListTile(
            icon: Icons.lock_outline,
            title: '隐私与安全',
            onTap: () => onUnavailable('隐私与安全'),
          ),
          const _MineDivider(),
          _MineListTile(
            icon: Icons.system_update_outlined,
            title: '固件升级',
            onTap: () => onUnavailable('固件升级'),
          ),
          const _MineDivider(),
          _MineListTile(
            icon: Icons.help_outline,
            title: '帮助与反馈',
            onTap: () => onUnavailable('帮助与反馈'),
          ),
          const _MineDivider(),
          _MineListTile(
            icon: Icons.info_outline,
            title: '关于台铃',
            value: 'v8.0.1',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const AboutAppPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MineSectionShell extends StatelessWidget {
  const _MineSectionShell({required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_mineCardRadius),
        ),
        child: child,
      ),
    );
  }
}

class _MineListTile extends StatelessWidget {
  const _MineListTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.trailingHelp = false,
    this.minHeight = 70,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? value;
  final bool trailingHelp;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final semanticsLabel = [
      title,
      if (value != null && value.isNotEmpty) value,
    ].join('，');

    return AppPressable(
      onTap: onTap,
      haptic: false,
      semanticsLabel: semanticsLabel,
      semanticsButton: true,
      semanticsEnabled: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: Icon(icon, size: 28, color: _officialStrong),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _officialStrong,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (value != null) ...[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _officialMuted,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (trailingHelp) ...[
                const Icon(Icons.help_outline, size: 22, color: _officialMuted),
                const SizedBox(width: 12),
              ],
              const Icon(Icons.chevron_right, size: 20, color: _officialMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _MineDivider extends StatelessWidget {
  const _MineDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 18,
      endIndent: 18,
      thickness: 0.5,
      color: Color(0xFFE7E7EA),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    void confirmLogout() {
      HapticFeedback.mediumImpact();
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('退出登录'),
          content: const Text('确定要退出当前账号吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                officialCloudService.logout();
                Navigator.pop(ctx);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppPressable(
        onTap: confirmLogout,
        haptic: false,
        semanticsLabel: '退出登录',
        semanticsButton: true,
        semanticsEnabled: true,
        borderRadius: BorderRadius.circular(_mineCardRadius),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_mineCardRadius),
          ),
          child: const Center(
            child: Text(
              '退出登录',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.brandRed,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _maskPhone(String? phone) {
  if (phone == null || phone.isEmpty) return null;
  return SensitiveValueMasker.phone(phone, minMaskLength: 11);
}
