part of 'profile_page.dart';

class _MineHeader extends StatelessWidget {
  const _MineHeader({
    required this.signedIn,
    required this.phone,
    required this.hasUnreadMessages,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onMessageTap,
  });

  final bool signedIn;
  final String? phone;
  final bool hasUnreadMessages;
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
                showDot: hasUnreadMessages,
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
                            color: AppColors.officialInk,
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
                            color: AppColors.officialTextMuted,
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
                        color: AppColors.officialTextLight,
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
            Icon(icon, size: 24, color: AppColors.officialStrong),
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
                      color: AppColors.officialStrong,
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
                            color: AppColors.officialTextMuted,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 15,
                        color: AppColors.officialTextMuted,
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
