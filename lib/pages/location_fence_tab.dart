part of 'location_page.dart';

class _FenceTab extends StatelessWidget {
  final OfficialCloudState cloudState;
  final _ResolvedLocation? location;
  final FenceConfig? localFence;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onTabChanged;

  const _FenceTab({
    required this.cloudState,
    required this.location,
    required this.localFence,
    required this.onRefresh,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        Positioned.fill(
          child: _MapPanel(
            location: location,
            fence: cloudState.fenceData,
            points: const [],
            compact: false,
            fullBleed: true,
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          top: 4 + topPadding * 0.2,
          child: SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.88),
                    ),
                    tooltip: '返回',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '电子围栏',
                    style: AppTextStyles.sectionTitle.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: 62 + topPadding * 0.2,
          child: _FloatingSegmentedTabs(index: 2, onChanged: onTabChanged),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _OfficialFenceSheet(
            fence: cloudState.fenceData,
            localFence: localFence,
            error: cloudState.fenceError,
            loading: cloudState.fenceLoading,
            signedIn: cloudState.signedIn,
            bottomPadding: bottomPadding,
            onRefresh: onRefresh,
          ),
        ),
      ],
    );
  }
}

class _OfficialFenceSheet extends StatelessWidget {
  final OfficialFenceData? fence;
  final FenceConfig? localFence;
  final String? error;
  final bool loading;
  final bool signedIn;
  final double bottomPadding;
  final Future<void> Function() onRefresh;

  const _OfficialFenceSheet({
    required this.fence,
    required this.localFence,
    required this.error,
    required this.loading,
    required this.signedIn,
    required this.bottomPadding,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final localFence = this.localFence;
    final error = this.error;
    final enabled = fence?.enabled ?? localFence?.enabled ?? false;
    final radius = fence?.radiusMeters ?? localFence?.radiusMeters.toDouble();
    final minRadius = _radiusMeters(fence?.fenceRadiusMin) ?? 100;
    final maxRadius = _radiusMeters(fence?.fenceRadiusMax) ?? 10000;
    final progress = radius == null
        ? 0.0
        : ((radius - minRadius) / (maxRadius - minRadius)).clamp(0.0, 1.0);
    final time = fence?.timeLabel ?? '待读取';
    final source = fence?.hasData == true
        ? '围栏配置已同步'
        : signedIn
        ? '暂无围栏配置'
        : '登录后同步围栏配置';

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomPadding),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
        boxShadow: [
          BoxShadow(
            color: _locationElevatedShadow,
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '围栏设置',
                style: AppTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.help_outline,
                size: AppIconSizes.sm,
                color: AppColors.textTertiary,
              ),
              const Spacer(),
              Material(
                color: AppColors.surface,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: '刷新围栏',
                  onPressed: loading ? null : onRefresh,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: AppIconSizes.md),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _FenceSettingRow(
            title: '电子围栏',
            subtitle: source,
            trailing: _FenceSwitchPill(enabled: enabled),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('范围设置', style: AppTextStyles.bodyLarge),
                    ),
                    Text(
                      radius == null ? '待读取' : _formatDistance(radius),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: progress,
                    backgroundColor: AppColors.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      enabled ? AppColors.primary : AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _formatDistance(minRadius),
                      style: AppTextStyles.caption,
                    ),
                    const Spacer(),
                    Text(
                      _formatDistance(maxRadius),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                const Divider(height: 24, color: AppColors.outlineVariant),
                _FenceSettingRow(
                  title: '时间设置',
                  subtitle: time,
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                  dense: true,
                ),
              ],
            ),
          ),
          if (localFence != null && fence?.hasData != true) ...[
            const SizedBox(height: 8),
            Text(
              '本地围栏：${localFence.enabled ? '已开启' : '已关闭'} · ${localFence.radiusMeters}m',
              style: AppTextStyles.caption,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: const Center(
                child: Text(
                  '保存',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static double? _radiusMeters(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null) return null;
    return parsed * 100;
  }

  // Show large fence radii in km (e.g. 10000m -> 10km) so the range labels
  // stay readable; keep metres below 1km.
  static String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      final fixed = km.toStringAsFixed(1);
      final trimmed = fixed.endsWith('.0')
          ? fixed.substring(0, fixed.length - 2)
          : fixed;
      return '${trimmed}km';
    }
    return '${meters.toStringAsFixed(0)}m';
  }
}

class _FenceSettingRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  final bool dense;

  const _FenceSettingRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: dense ? AppTouchTargets.min : 56),
      padding: EdgeInsets.symmetric(horizontal: dense ? 0 : 16),
      decoration: dense
          ? null
          : BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyLarge),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class _FenceSwitchPill extends StatelessWidget {
  final bool enabled;

  const _FenceSwitchPill({required this.enabled});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.success : AppColors.textTertiary;
    return Container(
      width: 52,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: enabled ? 0.22 : 0.16),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Align(
        alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
