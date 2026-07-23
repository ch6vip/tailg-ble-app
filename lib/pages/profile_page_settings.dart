part of 'profile_page.dart';

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.onUnavailable});

  final ValueChanged<String> onUnavailable;

  @override
  Widget build(BuildContext context) {
    return _MineSectionShell(
      child: Column(
        children: [
          _MineListTile(
            icon: Lucide.message,
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
            icon: Lucide.lock,
            title: '隐私与安全',
            onTap: () => onUnavailable('隐私与安全'),
          ),
          const _MineDivider(),
          _MineListTile(
            icon: Lucide.download,
            title: '固件升级',
            onTap: () => onUnavailable('固件升级'),
          ),
          const _MineDivider(),
          _MineListTile(
            icon: Lucide.help,
            title: '帮助与反馈',
            onTap: () => onUnavailable('帮助与反馈'),
          ),
          const _MineDivider(),
          _MineListTile(
            icon: Lucide.info,
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
                child: Icon(icon, size: 28, color: AppColors.officialStrong),
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
                    color: AppColors.officialStrong,
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
                    color: AppColors.officialTextMuted,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (trailingHelp) ...[
                const Icon(
                  Lucide.help,
                  size: 22,
                  color: AppColors.officialTextMuted,
                ),
                const SizedBox(width: 12),
              ],
              const Icon(
                Lucide.chevronRight,
                size: 20,
                color: AppColors.officialTextMuted,
              ),
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
      unawaited(HapticFeedback.mediumImpact());
      unawaited(
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
                onPressed: () async {
                  await officialCloudService.logout();
                  if (ctx.mounted) Navigator.pop(ctx);
                  AppNavigation.focusVehicleTabAfterSignOut();
                },
                child: const Text('确定'),
              ),
            ],
          ),
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
