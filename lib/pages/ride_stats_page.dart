import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/official_ride_statistics.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/lucide_icon.dart';
import 'add_vehicle_page.dart';
import 'login_page.dart';

const _rideNotice =
    '为剔除车辆静止时的卫星信号飘移、短距离骑行、原地推车或短暂挪动等无效干扰，系统设定单次持续移动距离小于50米时，不纳入总里程累计。这确保您仪表盘上的每一公里，都真实反映您的实际骑行足迹。';

const _ridePanelDecoration = BoxDecoration(
  color: CyberHomeColors.card,
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.tile)),
  border: Border.fromBorderSide(BorderSide(color: CyberHomeColors.line)),
  boxShadow: AppShadows.cyberCardShadow,
);

const _rideBodyText = TextStyle(
  fontSize: 13,
  height: 1.45,
  color: CyberHomeColors.inkMuted,
);

final _rideFilledButtonStyle = FilledButton.styleFrom(
  minimumSize: const Size(120, 48),
  backgroundColor: CyberHomeColors.primary,
  foregroundColor: CyberHomeColors.white,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.tile),
  ),
);

class RideStatsPage extends StatefulWidget {
  const RideStatsPage({super.key});

  @override
  State<RideStatsPage> createState() => _RideStatsPageState();
}

class _RideStatsPageState extends State<RideStatsPage> {
  OfficialRidePeriod _period = OfficialRidePeriod.day;
  OfficialRideStatistics? _statistics;
  bool _loading = false;
  String? _error;
  var _loadGeneration = 0;
  _RideStatsGate _gate = _RideStatsGate.ready;

  @override
  void initState() {
    super.initState();
    final cloud = officialCloudService.state;
    if (cloud.ridePeriod == _period) {
      _statistics = cloud.rideStatistics;
    }
    unawaited(_loadStatistics());
  }

  Future<void> _loadStatistics() async {
    final generation = ++_loadGeneration;
    final period = _period;
    final cloud = officialCloudService.state;

    if (!cloud.signedIn) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _gate = _RideStatsGate.needLogin;
        _loading = false;
        _error = null;
        _statistics = null;
      });
      return;
    }
    if (cloud.selectedVehicle == null) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _gate = _RideStatsGate.needVehicle;
        _loading = false;
        _error = null;
        _statistics = null;
      });
      return;
    }

    setState(() {
      _gate = _RideStatsGate.ready;
      _loading = true;
      _error = null;
    });
    try {
      await officialCloudService.refreshRideStatistics(
        period: period,
        force: true,
      );
      if (!mounted || generation != _loadGeneration || period != _period) {
        return;
      }
      final state = officialCloudService.state;
      final requestError = state.rideStatisticsError?.trim();
      setState(() {
        _statistics = state.ridePeriod == period
            ? state.rideStatistics
            : _statistics;
        _loading = false;
        _error = requestError == null || requestError.isEmpty
            ? null
            : requestError;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration || period != _period) {
        return;
      }
      setState(() {
        _error = OfficialCloudRedactor.errorMessage(error);
        _loading = false;
      });
    }
  }

  void _selectPeriod(OfficialRidePeriod period) {
    if (_period == period) return;
    setState(() {
      _period = period;
      _statistics = null;
      _error = null;
    });
    unawaited(_loadStatistics());
  }

  void _openLogin() {
    unawaited(
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const LoginPage()))
          .then((_) => _loadStatistics()),
    );
  }

  void _openAddVehicle() {
    unawaited(
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const AddVehiclePage()))
          .then((_) => _loadStatistics()),
    );
  }

  void _showCarbonHelp() {
    _showInfoSheet(title: '节碳量说明', content: '每行驶1公里，相当于\n减排二氧化碳0.171kg');
  }

  void _showTreeHelp() {
    _showInfoSheet(title: '树木吸碳说明', content: '每棵树平均每天吸收\n二氧化碳5.023kg');
  }

  void _showStatisticsHelp() {
    _showInfoSheet(title: '轨迹记录、统计说明', content: _rideNotice);
  }

  void _showInfoSheet({required String title, required String content}) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: CyberHomeColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.tile),
          ),
        ),
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: CyberHomeColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const LucideIcon(
                        Lucide.x,
                        size: 20,
                        color: CyberHomeColors.inkMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(content, style: _rideBodyText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _RideStatsHeader(onHelp: _showStatisticsHelp),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_gate == _RideStatsGate.needLogin) {
      return _GateState(
        title: '请先登录官方账号',
        actionLabel: '去登录',
        onAction: _openLogin,
      );
    }
    if (_gate == _RideStatsGate.needVehicle) {
      return _GateState(
        title: '暂无车辆，请先同步官方车辆',
        actionLabel: '添加车辆',
        onAction: _openAddVehicle,
      );
    }
    if (_error != null && _statistics == null) {
      return _ErrorState(message: _error!, onRetry: _loadStatistics);
    }

    return Stack(
      children: [
        ListView(
          key: const ValueKey('ride-stats-content'),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            _EnvironmentalSummary(
              period: _period,
              statistics: _statistics,
              onCarbonHelp: _showCarbonHelp,
              onTreeHelp: _showTreeHelp,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PeriodSelector(selected: _period, onSelected: _selectPeriod),
                  const SizedBox(height: 16),
                  const _MileageNotice(),
                  const SizedBox(height: 12),
                  _MileageSummary(period: _period, statistics: _statistics),
                  const SizedBox(height: 14),
                  _MetricsGrid(statistics: _statistics),
                ],
              ),
            ),
          ],
        ),
        if (_loading)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: CyberHomeColors.primary,
              backgroundColor: CyberHomeColors.primarySoft,
            ),
          ),
      ],
    );
  }
}

enum _RideStatsGate { ready, needLogin, needVehicle }

class _RideStatsHeader extends StatelessWidget {
  const _RideStatsHeader({required this.onHelp});

  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            '骑行统计',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CyberHomeColors.ink,
            ),
          ),
          Positioned(
            left: 12,
            child: Tooltip(
              message: '返回',
              excludeFromSemantics: true,
              child: AppPressable(
                key: const ValueKey('ride-stats-back'),
                onTap: () => Navigator.of(context).pop(),
                semanticsLabel: '返回',
                semanticsButton: true,
                child: const SizedBox(
                  width: AppTouchTargets.min,
                  height: AppTouchTargets.min,
                  child: Center(
                    child: LucideIcon(
                      Lucide.arrowLeft,
                      size: 20,
                      color: CyberHomeColors.inkSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            child: AppPressable(
              key: const ValueKey('ride-stats-help'),
              onTap: onHelp,
              semanticsLabel: '查看统计说明',
              semanticsButton: true,
              child: const SizedBox(
                height: AppTouchTargets.min,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '统计说明',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CyberHomeColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentalSummary extends StatelessWidget {
  const _EnvironmentalSummary({
    required this.period,
    required this.statistics,
    required this.onCarbonHelp,
    required this.onTreeHelp,
  });

  final OfficialRidePeriod period;
  final OfficialRideStatistics? statistics;
  final VoidCallback onCarbonHelp;
  final VoidCallback onTreeHelp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: CyberHomeColors.card,
        border: Border(bottom: BorderSide(color: CyberHomeColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _EcoMetric(
              key: const ValueKey('ride-carbon-metric'),
              title: period.carbonTitle,
              value: OfficialRideStatistics.displayValue(
                statistics?.carbonSaving ?? '',
              ),
              unit: 'kg',
              icon: Lucide.leaf,
              accent: CyberHomeColors.success,
              tooltip: '节碳量说明',
              onHelp: onCarbonHelp,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _EcoMetric(
              key: const ValueKey('ride-tree-metric'),
              title: '树木吸碳',
              value: OfficialRideStatistics.displayValue(
                statistics?.carbonAbsorption ?? '',
              ),
              unit: '棵',
              icon: Lucide.activity,
              accent: CyberHomeColors.warning,
              tooltip: '树木吸碳说明',
              onHelp: onTreeHelp,
            ),
          ),
        ],
      ),
    );
  }
}

class _EcoMetric extends StatelessWidget {
  const _EcoMetric({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.accent,
    required this.tooltip,
    required this.onHelp,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color accent;
  final String tooltip;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LucideIcon(icon, size: 18, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CyberHomeColors.inkMuted,
                ),
              ),
            ),
            Tooltip(
              message: tooltip,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: AppTouchTargets.min,
                  height: AppTouchTargets.min,
                ),
                padding: EdgeInsets.zero,
                onPressed: onHelp,
                icon: const LucideIcon(
                  Lucide.help,
                  size: 17,
                  color: CyberHomeColors.inkFaint,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: CyberHomeColors.ink,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CyberHomeColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final OfficialRidePeriod selected;
  final ValueChanged<OfficialRidePeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: CyberHomeColors.control,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: CyberHomeColors.line),
      ),
      child: Row(
        children: [
          for (final period in OfficialRidePeriod.values)
            Expanded(
              child: AppPressable(
                key: ValueKey('ride-period-${period.name}'),
                onTap: () => onSelected(period),
                borderRadius: BorderRadius.circular(AppRadii.xs),
                semanticsLabel: '按${period.tabLabel}查看骑行统计',
                semanticsButton: true,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: AppTouchTargets.min,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == period
                        ? CyberHomeColors.card
                        : CyberHomeColors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.xs),
                    boxShadow: selected == period
                        ? AppShadows.cyberActionShadow
                        : null,
                  ),
                  child: Text(
                    period.tabLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected == period
                          ? CyberHomeColors.primary
                          : CyberHomeColors.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MileageNotice extends StatelessWidget {
  const _MileageNotice();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      const TextSpan(
        children: [
          TextSpan(
            text: '* ',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: CyberHomeColors.danger,
            ),
          ),
          TextSpan(text: _rideNotice),
        ],
      ),
      key: const ValueKey('ride-mileage-notice'),
      style: _rideBodyText.copyWith(
        fontSize: 12,
        color: CyberHomeColors.inkFaint,
      ),
    );
  }
}

class _MileageSummary extends StatelessWidget {
  const _MileageSummary({required this.period, required this.statistics});

  final OfficialRidePeriod period;
  final OfficialRideStatistics? statistics;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 102,
      decoration: _ridePanelDecoration,
      child: Row(
        children: [
          Expanded(
            child: _MileageValue(
              label: period.mileageTitle,
              value: OfficialRideStatistics.formatMileageKm(
                statistics?.mileageFor(period) ?? '',
              ),
            ),
          ),
          const SizedBox(
            height: 50,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: CyberHomeColors.line,
            ),
          ),
          Expanded(
            child: _MileageValue(
              label: '累计里程',
              value: OfficialRideStatistics.formatMileageKm(
                statistics?.totalMileage ?? '',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MileageValue extends StatelessWidget {
  const _MileageValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CyberHomeColors.inkMuted,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: CyberHomeColors.ink,
                ),
              ),
              const TextSpan(
                text: ' km',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CyberHomeColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.statistics});

  final OfficialRideStatistics? statistics;

  @override
  Widget build(BuildContext context) {
    String value(String? raw) => OfficialRideStatistics.displayValue(raw ?? '');

    return Container(
      decoration: _ridePanelDecoration,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCell(
                  label: '最快时速',
                  value: value(statistics?.maxSpeed),
                  unit: 'km/h',
                  icon: Lucide.gauge,
                  accent: CyberHomeColors.primary,
                ),
              ),
              const _GridVerticalDivider(),
              Expanded(
                child: _MetricCell(
                  label: '总时长',
                  value: value(statistics?.ridingTime),
                  unit: '分钟',
                  icon: Lucide.history,
                  accent: CyberHomeColors.warning,
                ),
              ),
            ],
          ),
          const Divider(height: 1, color: CyberHomeColors.line),
          Row(
            children: [
              Expanded(
                child: _MetricCell(
                  label: '骑行次数',
                  value: value(statistics?.ridingCount),
                  unit: '次',
                  icon: Lucide.route,
                  accent: CyberHomeColors.rideAccent,
                ),
              ),
              const _GridVerticalDivider(),
              Expanded(
                child: _MetricCell(
                  label: '平均时速',
                  value: value(statistics?.avgSpeed),
                  unit: 'km/h',
                  icon: Lucide.activity,
                  accent: CyberHomeColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridVerticalDivider extends StatelessWidget {
  const _GridVerticalDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 92,
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: CyberHomeColors.line,
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LucideIcon(icon, size: 17, color: accent),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CyberHomeColors.inkMuted,
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 31,
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: CyberHomeColors.ink,
                        ),
                      ),
                      TextSpan(
                        text: ' $unit',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CyberHomeColors.inkMuted,
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

class _GateState extends StatelessWidget {
  const _GateState({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: _rideBodyText),
            const SizedBox(height: 14),
            FilledButton(
              style: _rideFilledButtonStyle,
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: _rideBodyText),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(88, AppTouchTargets.min),
                foregroundColor: CyberHomeColors.primary,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
