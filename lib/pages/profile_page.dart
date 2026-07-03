import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';
import '../main.dart';
import '../services/official_cloud_service.dart';
import '../widgets/app_snack.dart';
import 'app_preferences_pages.dart';
import 'official_cloud_page.dart';
import 'ota_precheck_page.dart';
import 'vehicle_message_page.dart';

/// v8 Profile / "我的" page.
///
/// Aligns with `design_v2/profile_v8.html`.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  StreamSubscription? _cloudSub;
  late OfficialCloudState _cloudState;

  @override
  void initState() {
    super.initState();
    _cloudState = officialCloudService.state;
    _cloudSub = officialCloudService.stateStream.listen((state) {
      if (mounted) setState(() => _cloudState = state);
    });
  }

  @override
  void dispose() {
    _cloudSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _cloudState.signedIn;
    final phone = signedIn ? _cloudState.phone : null;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserHeader(nickname: null, phone: phone, signedIn: signedIn),
              const SizedBox(height: 18),
              const _DataOverview(),
              const SizedBox(height: 16),
              const _MembershipBanner(),
              const SizedBox(height: 24),
              const _ServiceSection(),
              const SizedBox(height: 24),
              const _SettingsSection(),
              const SizedBox(height: 24),
              const _LogoutButton(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── User Header ───────────────────────────────────────────────

class _UserHeader extends StatelessWidget {
  const _UserHeader({this.nickname, this.phone, this.signedIn = false});
  final String? nickname;
  final String? phone;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          // Avatar with ring + shadow
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.energyGreen, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nickname ?? '骑行爱好者',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD580), Color(0xFFF5A623)],
                        ),
                      ),
                      child: const Text(
                        '黄金会员',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF5A3A00),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _maskPhone(phone) ?? '138****8888',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Edit profile
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!signedIn) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OfficialCloudPage()),
                );
              } else {
                AppSnack.info(context, '编辑资料功能开发中');
              }
            },
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.hairline),
                    boxShadow: [AppShadows.cardShadow.first],
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 17,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _maskPhone(String? phone) {
    if (phone == null || phone.length < 11) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }
}

// ─── Data Overview ─────────────────────────────────────────────

class _DataOverview extends StatelessWidget {
  const _DataOverview();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
          boxShadow: AppShadows.elevation1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _DataItem(value: '--', unit: 'km', label: '累计里程'),
            _VerticalDividerWidget(),
            _DataItem(value: '--', unit: '次', label: '骑行次数'),
            _VerticalDividerWidget(),
            _DataItem(value: '--', unit: '天', label: '陪伴天数'),
          ],
        ),
      ),
    );
  }
}

class _DataItem extends StatelessWidget {
  const _DataItem({required this.value, this.unit, required this.label});
  final String value;
  final String? unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Text(
                unit!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _VerticalDividerWidget extends StatelessWidget {
  const _VerticalDividerWidget();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: AppColors.hairline);
  }
}

// ─── Membership Banner ─────────────────────────────────────────

class _MembershipBanner extends StatelessWidget {
  const _MembershipBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => AppSnack.info(context, '会员中心功能开发中'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF222A3A), Color(0xFF1B2230)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B2230).withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative glow
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFF5A623).withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  // Crown icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(13)),
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFD580), Color(0xFFF5A623)],
                      ),
                    ),
                    child: const Icon(
                      Icons.star,
                      color: Color(0xFF5A3A00),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '会员中心 · 即将上线',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '会员权益加载中，敬请期待',
                          style: TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '查看',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFD580),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right,
                    size: 17,
                    color: Color(0xFFFFD580),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Service Section ───────────────────────────────────────────

class _ServiceSection extends StatelessWidget {
  const _ServiceSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('我的服务'),
          const SizedBox(height: 10),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0F182740),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                _SettingTile(
                  icon: Icons.receipt_long_outlined,
                  label: '我的订单',
                  iconBg: AppColors.accentSky.withValues(alpha: 0.14),
                  iconColor: AppColors.accentSky,
                  onTap: () {},
                ),
                _DividerTile(),
                _SettingTile(
                  icon: Icons.build_outlined,
                  label: '保养预约',
                  iconBg: AppColors.energyGreen.withValues(alpha: 0.14),
                  iconColor: AppColors.primaryDark,
                  value: '附近 3 家门店',
                  onTap: () {},
                ),
                _DividerTile(),
                _SettingTile(
                  icon: Icons.shield_outlined,
                  label: '保险服务',
                  iconBg: AppColors.accentViolet.withValues(alpha: 0.14),
                  iconColor: AppColors.accentViolet,
                  onTap: () {},
                ),
                _DividerTile(),
                _SettingTile(
                  icon: Icons.card_giftcard_outlined,
                  label: '优惠券',
                  iconBg: AppColors.accentAmber.withValues(alpha: 0.14),
                  iconColor: AppColors.accentAmber,
                  badge: '3 张可用',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Settings Section ──────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('设置'),
          const SizedBox(height: 10),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0F182740),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                _SettingTile(
                  icon: Icons.notifications_outlined,
                  label: '消息通知',
                  iconBg: AppColors.surfaceContainerLow,
                  iconColor: AppColors.textSecondary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VehicleMessagePage(),
                    ),
                  ),
                ),
                _DividerTile(),
                _SettingTile(
                  icon: Icons.lock_outline,
                  label: '隐私与安全',
                  iconBg: AppColors.surfaceContainerLow,
                  iconColor: AppColors.textSecondary,
                  onTap: () {},
                ),
                _DividerTile(),
                _SettingTile(
                  icon: Icons.system_update_outlined,
                  label: '固件升级',
                  iconBg: AppColors.surfaceContainerLow,
                  iconColor: AppColors.textSecondary,
                  badge: '新版本',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OtaPrecheckPage()),
                  ),
                ),
                _DividerTile(),
                _SettingTile(
                  icon: Icons.help_outline,
                  label: '帮助与反馈',
                  iconBg: AppColors.surfaceContainerLow,
                  iconColor: AppColors.textSecondary,
                  onTap: () {},
                ),
                _DividerTile(),
                _SettingTile(
                  icon: Icons.info_outline,
                  label: '关于台铃',
                  iconBg: AppColors.surfaceContainerLow,
                  iconColor: AppColors.textSecondary,
                  value: 'v8.0.1',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutAppPage()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─── Logout Button ─────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          showDialog(
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
        },
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF182740).withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '退出登录',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.energyRed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Reusable Tile ─────────────────────────────────────────────

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    required this.iconBg,
    required this.iconColor,
    this.value,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconBg;
  final Color iconColor;
  final String? value;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.energyRed,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (value != null)
              Text(
                value!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right,
              size: 17,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DividerTile extends StatelessWidget {
  const _DividerTile();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 18,
      endIndent: 18,
      thickness: 0.5,
      color: AppColors.outlineVariant,
    );
  }
}
