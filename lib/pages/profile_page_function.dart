part of 'profile_page.dart';

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
                color: AppColors.officialStrong,
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
              Icon(icon, size: 24, color: AppColors.officialStrong),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.officialStrong,
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
