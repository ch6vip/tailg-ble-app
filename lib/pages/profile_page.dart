import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';

/// v8 Profile / "我的" page.
///
/// Aligns with `design_v2/profile_v8.html`.
/// Sections: user header, data overview, membership banner,
/// service groups, settings groups, logout.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _UserHeader(),
              const SizedBox(height: 16),
              const _DataOverview(),
              const SizedBox(height: 16),
              const _MembershipBanner(),
              const SizedBox(height: 20),
              const _ServiceSection(),
              const SizedBox(height: 20),
              const _SettingsSection(),
              const SizedBox(height: 24),
              const _LogoutButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── User Header ─────────────────────────────────────────────────

class _UserHeader extends StatelessWidget {
  const _UserHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.energyGreen, AppColors.accentTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '骑行爱好者',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '138****8888',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
              ),
            ),
            child: const Text(
              '黄金会员',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data Overview ───────────────────────────────────────────────

class _DataOverview extends StatelessWidget {
  const _DataOverview();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: cardDecoration,
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const [
            _DataItem(value: '1,286', label: '累计里程\n(km)'),
            _VerticalDividerWidget(),
            _DataItem(value: '342', label: '骑行次数'),
            _VerticalDividerWidget(),
            _DataItem(value: '186', label: '陪伴天数'),
          ],
        ),
      ),
    );
  }
}

class _DataItem extends StatelessWidget {
  const _DataItem({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _VerticalDividerWidget extends StatelessWidget {
  const _VerticalDividerWidget();

  @override
  Widget build(BuildContext context) {
    return Container(width: 0.5, height: 40, color: AppColors.outlineVariant);
  }
}

// ─── Membership Banner ───────────────────────────────────────────

class _MembershipBanner extends StatelessWidget {
  const _MembershipBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B2230), Color(0xFF2A3342)],
          ),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Row(
          children: [
            const Icon(Icons.star, color: Color(0xFFFFD700), size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '黄金会员',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '享免费保养、优先客服、专属优惠',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: const Text(
                '立即升级',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2230),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Service Section ─────────────────────────────────────────────

class _ServiceSection extends StatelessWidget {
  const _ServiceSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '我的服务',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: cardDecoration,
            child: Column(
              children: [
                _SettingTile(
                  icon: Icons.receipt_long_outlined,
                  label: '我的订单',
                  color: AppColors.accentSky,
                  showDot: true,
                  onTap: () {},
                ),
                _DividerTile(),
                _SettingTile(
                  icon: Icons.build_outlined,
                  label: '保养预约',
                  color: AppColors.energyAmber,
                  onTap: () {},
                ),
                _DividerTile(),
                _SettingTile(
                  icon: Icons.shield_outlined,
                  label: '保险服务',
                  color: AppColors.energyGreen,
                  onTap: () {},
                ),
                _DividerTile(),
                _SettingTile(
                  icon: Icons.card_giftcard_outlined,
                  label: '优惠券',
                  color: AppColors.accentViolet,
                  showDot: true,
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

// ─── Settings Section ────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '设置',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: cardDecoration,
            child: Column(
              children: [
                _SettingTile(
                  icon: Icons.notifications_outlined,
                  label: '消息通知',
                  color: AppColors.textSecondary,
                  showDot: true,
                  onTap: () {},
                ),
                _DividerTile(),
                _SettingTile(
                  icon: Icons.lock_outline,
                  label: '隐私',
                  color: AppColors.textTertiary,
                  onTap: () {},
                ),
                _DividerTile(),
                _SettingTile(
                  icon: Icons.system_update_outlined,
                  label: '固件升级',
                  color: AppColors.accentSky,
                  value: 'v1.2.0',
                  onTap: () {},
                ),
                _DividerTile(),
                _SettingTile(
                  icon: Icons.help_outline,
                  label: '帮助',
                  color: AppColors.textTertiary,
                  onTap: () {},
                ),
                _DividerTile(),
                _SettingTile(
                  icon: Icons.info_outline,
                  label: '关于',
                  color: AppColors.textTertiary,
                  value: 'Tailg BLE',
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

// ─── Logout Button ───────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () {
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
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        },
        child: const Text(
          '退出登录',
          style: TextStyle(fontSize: 15, color: AppColors.energyRed),
        ),
      ),
    );
  }
}

// ─── Reusable Tile ────────────────────────────────────────────────

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    required this.color,
    this.value,
    this.showDot = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? value;
  final bool showDot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            if (showDot) ...[
              const SizedBox(width: 8),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.energyRed,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 18,
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
      indent: 48,
      thickness: 0.5,
      color: AppColors.outlineVariant,
    );
  }
}
