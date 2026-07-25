part of 'location_page.dart';

const _travelDetailPointPreviewLimit = 12;

class _TravelTab extends StatelessWidget {
  final OfficialCloudState cloudState;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int delta) onChangeMonth;
  final ValueChanged<OfficialTravelRecord> onOpenDetail;

  const _TravelTab({
    required this.cloudState,
    required this.onRefresh,
    required this.onChangeMonth,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final travelError = cloudState.travelError;
    final records = [for (final day in cloudState.travelDays) ...day.records];
    final dateGroups = cloudState.travelDays
        .where((day) => day.records.isNotEmpty || day.hasData)
        .toList(growable: false);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          _TravelMonthSelector(
            month: cloudState.travelMonth.isEmpty
                ? '本月轨迹'
                : cloudState.travelMonth,
            onPreviousMonth: cloudState.travelLoading
                ? null
                : () => onChangeMonth(-1),
            onNextMonth: cloudState.travelLoading
                ? null
                : () => onChangeMonth(1),
          ),
          const SizedBox(height: 14),
          if (cloudState.travelLoading)
            const _LoadingCard(text: '正在读取官方历史轨迹')
          else if (!cloudState.signedIn)
            const _EmptyCard(
              icon: Lucide.cloudOff,
              title: '未登录官方账号',
              subtitle: '登录官方账号后可同步本月骑行轨迹。',
            )
          else if (travelError != null)
            _EmptyCard(
              icon: Lucide.info,
              title: '历史轨迹暂不可用',
              subtitle: travelError,
            )
          else if (records.isEmpty)
            const _EmptyCard(
              icon: Lucide.route,
              title: '暂无轨迹记录',
              subtitle: '本月还没有可显示的骑行轨迹，可点右上角刷新或切换月份。',
            )
          else
            ...dateGroups.map(
              (day) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TravelDayCard(
                  day: day,
                  detailPointCounts: cloudState.travelDetails.map(
                    (key, value) => MapEntry(key, value.length),
                  ),
                  loading: cloudState.travelDetailLoading,
                  onOpenDetail: onOpenDetail,
                ),
              ),
            ),
          const SizedBox(height: 4),
          const _ReadOnlyNotice(
            title: '轨迹服务',
            subtitle: '轨迹数据会按月份同步展示，删除轨迹和纠偏等操作请前往官方服务渠道处理。',
          ),
        ],
      ),
    );
  }
}

class _TravelMonthSelector extends StatelessWidget {
  final String month;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;

  const _TravelMonthSelector({
    required this.month,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: _locationCardDecoration,
      child: Row(
        children: [
          IconButton(
            tooltip: '上个月',
            onPressed: onPreviousMonth,
            constraints: const BoxConstraints(
              minWidth: AppTouchTargets.min,
              minHeight: AppTouchTargets.min,
            ),
            padding: EdgeInsets.zero,
            icon: const LucideIcon(Lucide.chevronLeft, size: AppIconSizes.md),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    month,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _locationItemTitle.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const LucideIcon(
                    Lucide.chevronDown,
                    color: CyberHomeColors.inkFaint,
                    size: AppIconSizes.sm,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '下个月',
            onPressed: onNextMonth,
            constraints: const BoxConstraints(
              minWidth: AppTouchTargets.min,
              minHeight: AppTouchTargets.min,
            ),
            padding: EdgeInsets.zero,
            icon: const LucideIcon(Lucide.chevronRight, size: AppIconSizes.md),
          ),
        ],
      ),
    );
  }
}

class _TravelDayCard extends StatelessWidget {
  final OfficialTravelDay day;
  final Map<String, int> detailPointCounts;
  final bool loading;
  final ValueChanged<OfficialTravelRecord> onOpenDetail;

  const _TravelDayCard({
    required this.day,
    required this.detailPointCounts,
    required this.loading,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final records = day.records;
    final summedKm = sumTravelMileageKm(records);
    // Official day.totalMileage is meters (ViewAdapter.setHisListItemMilage).
    final totalMeters = day.totalMileage.trim().isNotEmpty
        ? parseTravelMileageMeters(day.totalMileage)
        : summedKm * 1000;
    final mileageParts = _travelMileageSummaryParts(totalMeters);
    final duration = day.totalTime.isNotEmpty
        ? day.totalTime
        : formatCompactDuration(
            sumTravelDurationSeconds(records),
            emptyWhenZero: true,
          );
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
      decoration: _locationCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day.travelDate.isEmpty ? '官方轨迹' : day.travelDate,
            style: _locationBodyText.copyWith(
              color: CyberHomeColors.inkMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 75,
            decoration: BoxDecoration(
              color: CyberHomeColors.control,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: CyberHomeColors.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    label: '总次数',
                    value: '${records.length}',
                    unit: '次',
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  color: CyberHomeColors.lineStrong,
                ),
                Expanded(
                  child: _SummaryValue(
                    label: '总里程',
                    value: mileageParts.$1,
                    unit: mileageParts.$2,
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  color: CyberHomeColors.lineStrong,
                ),
                Expanded(
                  child: _SummaryValue(
                    label: '总时长',
                    value: duration.isEmpty ? '--' : duration,
                    unit: '',
                  ),
                ),
              ],
            ),
          ),
          if (records.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...records.map(
              (record) => _TravelRecordCard(
                record: record,
                pointCount: detailPointCounts[record.deviceTravelId],
                loading: loading,
                onTap: () => onOpenDetail(record),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TravelRecordCard extends StatelessWidget {
  final OfficialTravelRecord record;
  final int? pointCount;
  final bool loading;
  final VoidCallback onTap;

  const _TravelRecordCard({
    required this.record,
    required this.pointCount,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final interactive = !loading;
    String fallback(String value, String fallback) =>
        value.isEmpty ? fallback : value;
    final timeLabel = record.startTime.isEmpty && record.endTime.isEmpty
        ? fallback(record.travelDate, '时间未知')
        : '${fallback(record.startTime, '--')} 至 ${fallback(record.endTime, '--')}';
    final semanticsLabel = [
      '轨迹记录',
      timeLabel,
      record.mileageLabel,
      record.averageSpeedLabel,
      record.durationLabel,
      pointCount == null ? '点击读取' : '$pointCount 点',
    ].join('，');
    return AppPressable(
      enabled: interactive,
      pressedScale: AppMotion.pressScale,
      background: CyberHomeColors.card,
      pressedBackground: CyberHomeColors.cardMuted,
      borderRadius: BorderRadius.circular(AppRadii.tile),
      haptic: false,
      semanticsLabel: semanticsLabel,
      semanticsButton: true,
      semanticsEnabled: interactive,
      semanticsContainer: true,
      onTap: () {
        unawaited(HapticFeedback.selectionClick());
        onTap();
      },
      child: SizedBox(
        height: 86,
        child: Row(
          children: [
            const SizedBox(width: 12),
            SizedBox(width: 76, child: _TrackTimeRail(record: record)),
            Container(width: 1, height: 46, color: CyberHomeColors.line),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.mileageLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _locationTitleText.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${record.averageSpeedLabel}  ·  ${record.durationLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _locationCaptionText,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 72,
              child: Text(
                pointCount == null ? '点击读取' : '$pointCount 点',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _locationCaptionText,
              ),
            ),
            const SizedBox(width: 8),
            const LucideIcon(
              Lucide.chevronRight,
              color: CyberHomeColors.inkFaint,
              size: AppIconSizes.md,
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

class _TrackTimeRail extends StatelessWidget {
  final OfficialTravelRecord record;

  const _TrackTimeRail({required this.record});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          left: 7,
          top: 29,
          bottom: 29,
          child: VerticalDivider(
            width: 1,
            thickness: 1,
            color: CyberHomeColors.line,
          ),
        ),
        Positioned(
          left: 0,
          top: 20,
          child: _TimelineDot(color: CyberHomeColors.success),
        ),
        Positioned(
          left: 0,
          bottom: 20,
          child: _TimelineDot(color: CyberHomeColors.warning),
        ),
        Positioned(
          left: 20,
          top: 15,
          child: Text(
            record.startTime.isEmpty ? '--' : record.startTime,
            style: _locationCaptionText,
          ),
        ),
        Positioned(
          left: 20,
          bottom: 15,
          child: Text(
            record.endTime.isEmpty ? '--' : record.endTime,
            style: _locationCaptionText,
          ),
        ),
      ],
    );
  }
}

class _TimelineDot extends StatelessWidget {
  final Color color;

  const _TimelineDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: CyberHomeColors.white, width: 2),
      ),
    );
  }
}

class _TravelDetailSheet extends StatelessWidget {
  final OfficialTravelRecord record;

  const _TravelDetailSheet({required this.record});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OfficialCloudState>(
      stream: officialCloudService.stateStream,
      initialData: officialCloudService.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? officialCloudService.state;
        final points = state.travelDetails[record.deviceTravelId] ?? const [];
        final firstPoint = _firstResolvedPoint(points);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          decoration: const BoxDecoration(
            color: CyberHomeColors.pageBg,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadii.sheet),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CyberHomeColors.lineStrong,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.travelDate.isEmpty ? '轨迹详情' : record.travelDate,
                        style: _locationTitleText,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const LucideIcon(Lucide.x),
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    _MapPanel(
                      location: firstPoint,
                      fence: null,
                      points: points,
                      compact: true,
                    ),
                    const SizedBox(height: 14),
                    _TrackDetailStats(
                      record: record,
                      pointCount: points.length,
                    ),
                    const SizedBox(height: 14),
                    _TrackStartEndCard(
                      record: record,
                      firstPoint: firstPoint,
                      lastPoint: _lastResolvedPoint(points),
                    ),
                    const SizedBox(height: 14),
                    if (points.isEmpty)
                      const _EmptyCard(
                        icon: Lucide.route,
                        title: '未返回轨迹点',
                        subtitle: '该行程暂时没有可绘制的坐标。',
                      )
                    else
                      ...points
                          .take(_travelDetailPointPreviewLimit)
                          .map((point) => _PointRow(point: point)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static _ResolvedLocation? _firstResolvedPoint(
    List<OfficialTravelPoint> points,
  ) {
    for (final point in points) {
      final latitude = point.latitude;
      final longitude = point.longitude;
      if (latitude == null || longitude == null) continue;
      if (latitude == 0 && longitude == 0) continue;
      return _ResolvedLocation(
        latitude: latitude,
        longitude: longitude,
        accuracy: 0,
        timeLabel: point.reportTime,
        address: '',
        source: '轨迹起点',
      );
    }
    return null;
  }

  static _ResolvedLocation? _lastResolvedPoint(
    List<OfficialTravelPoint> points,
  ) {
    for (var index = points.length - 1; index >= 0; index--) {
      final point = points[index];
      final latitude = point.latitude;
      final longitude = point.longitude;
      if (latitude == null || longitude == null) continue;
      if (latitude == 0 && longitude == 0) continue;
      return _ResolvedLocation(
        latitude: latitude,
        longitude: longitude,
        accuracy: 0,
        timeLabel: point.reportTime,
        address: '',
        source: '轨迹终点',
      );
    }
    return null;
  }
}

class _TrackDetailStats extends StatelessWidget {
  final OfficialTravelRecord record;
  final int pointCount;

  const _TrackDetailStats({required this.record, required this.pointCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: _locationCardDecoration,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DetailMetric(label: '里程', value: record.mileageLabel),
              ),
              Expanded(
                child: _DetailMetric(label: '时长', value: record.durationLabel),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _DetailMetric(label: '极速', value: record.maxSpeedLabel),
              ),
              Expanded(
                child: _DetailMetric(
                  label: '均速',
                  value: record.averageSpeedLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoRow('轨迹点', '$pointCount'),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final String label;
  final String value;

  const _DetailMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _locationCaptionText),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _locationItemTitle.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _TrackStartEndCard extends StatelessWidget {
  final OfficialTravelRecord record;
  final _ResolvedLocation? firstPoint;
  final _ResolvedLocation? lastPoint;

  const _TrackStartEndCard({
    required this.record,
    required this.firstPoint,
    required this.lastPoint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: _locationCardDecoration,
      child: Column(
        children: [
          _TrackEndpointRow(
            color: CyberHomeColors.success,
            title: _endpointTitle(firstPoint, '起点'),
            time: record.startTime.isEmpty ? '--' : record.startTime,
          ),
          Container(
            height: 42,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 7),
            child: Container(width: 1, color: CyberHomeColors.line),
          ),
          _TrackEndpointRow(
            color: CyberHomeColors.warning,
            title: _endpointTitle(lastPoint, '终点'),
            time: record.endTime.isEmpty ? '--' : record.endTime,
          ),
        ],
      ),
    );
  }

  static String _endpointTitle(_ResolvedLocation? location, String fallback) {
    if (location == null) return fallback;
    return location.coordinateText;
  }
}

class _TrackEndpointRow extends StatelessWidget {
  final Color color;
  final String title;
  final String time;

  const _TrackEndpointRow({
    required this.color,
    required this.title,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TimelineDot(color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _locationBodyText.copyWith(
              color: CyberHomeColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(time, style: _locationCaptionText),
      ],
    );
  }
}

/// Day-card summary: split number + unit the way `_SummaryValue` expects.
/// Official still converts meters→km at 1000 (`setHisListItemMilage`).
(String, String) _travelMileageSummaryParts(double meters) {
  if (meters <= 0 || meters.isNaN || meters.isInfinite) {
    return ('--', '');
  }
  final intMeters = meters.abs().truncate();
  if (intMeters < 1000) {
    return ('$intMeters', 'm');
  }
  return (formatDecimalDown(intMeters / 1000.0, fractionDigits: 2), 'km');
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _SummaryValue({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: value,
            style: _locationTitleText,
            children: [
              TextSpan(
                text: unit,
                style: const TextStyle(
                  fontSize: 11,
                  color: CyberHomeColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: CyberHomeColors.inkFaint),
        ),
      ],
    );
  }
}

class _PointRow extends StatelessWidget {
  final OfficialTravelPoint point;

  const _PointRow({required this.point});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _locationCardDecoration,
      child: Row(
        children: [
          const LucideIcon(
            Lucide.tripOrigin,
            color: CyberHomeColors.primary,
            size: AppIconSizes.sm,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${point.lat}, ${point.lng}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _locationBodyText.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            point.reportTime.isEmpty ? '--' : point.reportTime,
            style: const TextStyle(
              fontSize: 11,
              color: CyberHomeColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String text;

  const _LoadingCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _locationCardDecoration,
      child: Column(
        children: [
          const CircularProgressIndicator(
            strokeWidth: 2,
            color: CyberHomeColors.primary,
          ),
          const SizedBox(height: 12),
          Text(text, style: _locationBodyText),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _locationCardDecoration,
      child: Column(
        children: [
          LucideIcon(
            icon,
            size: AppIconSizes.xl,
            color: CyberHomeColors.inkFaint,
          ),
          const SizedBox(height: 10),
          Text(title, style: _locationItemTitle),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: _locationCaptionText,
          ),
        ],
      ),
    );
  }
}
