part of 'location_page.dart';

class _FenceTab extends StatelessWidget {
  final OfficialCloudState cloudState;
  final _ResolvedLocation? location;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onTabChanged;

  const _FenceTab({
    required this.cloudState,
    required this.location,
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
                      Lucide.arrowLeft,
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

class _OfficialFenceSheet extends StatefulWidget {
  final OfficialFenceData? fence;
  final String? error;
  final bool loading;
  final bool signedIn;
  final double bottomPadding;
  final Future<void> Function() onRefresh;

  const _OfficialFenceSheet({
    required this.fence,
    required this.error,
    required this.loading,
    required this.signedIn,
    required this.bottomPadding,
    required this.onRefresh,
  });

  @override
  State<_OfficialFenceSheet> createState() => _OfficialFenceSheetState();
}

class _OfficialFenceSheetState extends State<_OfficialFenceSheet> {
  late bool _enabled;
  late double _radiusValue;
  late String _timeFrom;
  late String _timeTo;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _syncFromFence(widget.fence);
  }

  @override
  void didUpdateWidget(_OfficialFenceSheet old) {
    super.didUpdateWidget(old);
    if (!_dirty && widget.fence != old.fence) {
      _syncFromFence(widget.fence);
    }
  }

  void _syncFromFence(OfficialFenceData? fence) {
    _enabled = fence?.enabled ?? false;
    final rawRadius = fence?.fenceRadius.trim();
    _radiusValue = (double.tryParse(rawRadius ?? '') ?? 1).clamp(
      double.tryParse(fence?.fenceRadiusMin ?? '') ?? 1,
      double.tryParse(fence?.fenceRadiusMax ?? '') ?? 100,
    );
    _timeFrom = fence?.fenceTimeFr ?? '08:00';
    _timeTo = fence?.fenceTimeTo ?? '22:00';
  }

  double get _minRadius =>
      double.tryParse(widget.fence?.fenceRadiusMin ?? '') ?? 1;
  double get _maxRadius =>
      double.tryParse(widget.fence?.fenceRadiusMax ?? '') ?? 100;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await officialCloudService.updateFenceData(
        enabled: _enabled,
        radiusValue: _radiusValue.round(),
        timeFrom: _timeFrom,
        timeTo: _timeTo,
      );
      if (mounted) {
        setState(() {
          _dirty = false;
          _saving = false;
        });
        AppSnack.success(context, '围栏设置已保存');
      }
    } on Exception {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, '保存失败，请重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    final radius = _radiusValue * 100;
    final minRadius = _minRadius * 100;
    final maxRadius = _maxRadius * 100;
    final source = widget.fence?.hasData == true
        ? '围栏配置已同步'
        : widget.signedIn
        ? '暂无围栏配置'
        : '登录后同步围栏配置';

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + widget.bottomPadding),
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
                Lucide.help,
                size: AppIconSizes.sm,
                color: AppColors.textTertiary,
              ),
              const Spacer(),
              Material(
                color: AppColors.surface,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: '刷新围栏',
                  onPressed: widget.loading ? null : widget.onRefresh,
                  icon: widget.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Lucide.refresh, size: AppIconSizes.md),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _enabled = !_enabled;
                _dirty = true;
              });
            },
            child: _FenceSettingRow(
              title: '电子围栏',
              subtitle: source,
              trailing: _FenceSwitchPill(enabled: _enabled),
            ),
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
                      formatDistanceMeters(radius),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _enabled
                        ? AppColors.primary
                        : AppColors.textTertiary,
                    inactiveTrackColor: AppColors.surface,
                    thumbColor: _enabled
                        ? AppColors.primary
                        : AppColors.textTertiary,
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: _radiusValue,
                    min: _minRadius,
                    max: _maxRadius,
                    onChanged: (v) {
                      setState(() {
                        _radiusValue = v;
                        _dirty = true;
                      });
                    },
                  ),
                ),
                Row(
                  children: [
                    Text(
                      formatDistanceMeters(minRadius),
                      style: AppTextStyles.caption,
                    ),
                    const Spacer(),
                    Text(
                      formatDistanceMeters(maxRadius),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                const Divider(height: 24, color: AppColors.outlineVariant),
                GestureDetector(
                  onTap: () => _pickTimeRange(context),
                  child: _FenceSettingRow(
                    title: '时间设置',
                    subtitle: '$_timeFrom - $_timeTo',
                    trailing: const Icon(
                      Lucide.chevronRight,
                      color: AppColors.textTertiary,
                    ),
                    dense: true,
                  ),
                ),
              ],
            ),
          ),
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
            child: ElevatedButton(
              onPressed: (_dirty && !_saving && !widget.loading) ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.35,
                ),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '保存',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTimeRange(BuildContext context) async {
    final fromParts = _timeFrom.split(':');
    final startHour = int.tryParse(fromParts[0]) ?? 8;
    final startMin = fromParts.length > 1 ? int.tryParse(fromParts[1]) ?? 0 : 0;

    final from = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: startHour, minute: startMin),
      helpText: '开始时间',
    );
    if (from == null || !context.mounted) return;

    final toParts = _timeTo.split(':');
    final endHour = int.tryParse(toParts[0]) ?? 22;
    final endMin = toParts.length > 1 ? int.tryParse(toParts[1]) ?? 0 : 0;

    final to = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: endHour, minute: endMin),
      helpText: '结束时间',
    );
    if (to == null || !context.mounted) return;

    setState(() {
      _timeFrom = formatHourMinuteText(from.hour, from.minute);
      _timeTo = formatHourMinuteText(to.hour, to.minute);
      _dirty = true;
    });
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
