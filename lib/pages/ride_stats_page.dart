import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/official_vehicle.dart';
import '../services/display_number_formatter.dart';
import '../services/display_time_formatter.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/lucide_icon.dart';
import 'add_vehicle_page.dart';
import 'login_page.dart';

const _rideCardDecoration = BoxDecoration(
  color: CyberHomeColors.card,
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.tile)),
  border: Border.fromBorderSide(BorderSide(color: CyberHomeColors.line)),
);

const _rideItemTitle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: CyberHomeColors.ink,
);

const _rideBodyText = TextStyle(
  fontSize: 13,
  height: 1.45,
  color: CyberHomeColors.inkMuted,
);

const _rideCaptionText = TextStyle(
  fontSize: 12,
  color: CyberHomeColors.inkFaint,
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
  String _month = formatMonthText(DateTime.now());
  bool _loading = false;
  String? _error;
  List<OfficialTravelDay> _days = [];
  var _loadGeneration = 0;
  _RideStatsGate _gate = _RideStatsGate.ready;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMonth());
  }

  Future<void> _loadMonth() async {
    final generation = ++_loadGeneration;
    final month = _month;
    final cloud = officialCloudService.state;

    if (!cloud.signedIn) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _gate = _RideStatsGate.needLogin;
        _loading = false;
        _error = null;
        _days = const [];
      });
      return;
    }
    if (cloud.selectedVehicle == null) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _gate = _RideStatsGate.needVehicle;
        _loading = false;
        _error = null;
        _days = const [];
      });
      return;
    }
    if (cloud.userId.trim().isEmpty) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _gate = _RideStatsGate.needRelogin;
        _loading = false;
        _error = null;
        _days = const [];
      });
      return;
    }

    setState(() {
      _gate = _RideStatsGate.ready;
      _loading = true;
      _error = null;
    });
    try {
      await officialCloudService.refreshTravelHistory(
        month: month,
        force: true,
      );
      if (!mounted || generation != _loadGeneration) return;
      final state = officialCloudService.state;
      final travelError = state.travelError?.trim();
      setState(() {
        _days = state.travelDays;
        _loading = false;
        _error = (travelError != null && travelError.isNotEmpty)
            ? travelError
            : null;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = OfficialCloudRedactor.errorMessage(e);
        _loading = false;
        _days = const [];
      });
    }
  }

  void _prevMonth() {
    final prev = shiftMonthText(_month, -1);
    if (prev == null) return;
    _month = prev;
    unawaited(_loadMonth());
  }

  void _nextMonth() {
    final next = shiftMonthText(_month, 1);
    if (next == null) return;
    _month = next;
    unawaited(_loadMonth());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const _RideStatsHeader(),
            _MonthSelector(
              month: _month,
              onPrev: _prevMonth,
              onNext: _nextMonth,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: CyberHomeColors.primary),
      );
    }
    if (_gate == _RideStatsGate.needLogin) {
      return _GateState(
        title: '请先登录官方账号',
        actionLabel: '去登录',
        onAction: () => unawaited(
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const LoginPage())),
        ),
      );
    }
    if (_gate == _RideStatsGate.needVehicle) {
      return _GateState(
        title: '暂无车辆，请先同步官方车辆',
        actionLabel: '添加车辆',
        onAction: () => unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AddVehiclePage()),
          ),
        ),
      );
    }
    if (_gate == _RideStatsGate.needRelogin) {
      return _GateState(
        title: '登录信息不完整，请重新登录后再查看骑行统计',
        actionLabel: '重新登录',
        onAction: () => unawaited(
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const LoginPage())),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: _rideBodyText,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadMonth,
              style: TextButton.styleFrom(
                minimumSize: const Size(88, 44),
                foregroundColor: CyberHomeColors.primary,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_days.isEmpty) {
      final vehicleName =
          officialCloudService.state.selectedVehicle?.displayName ?? '当前车辆';
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            '$_month · $vehicleName\n本月暂无骑行记录',
            textAlign: TextAlign.center,
            style: _rideBodyText,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _SummaryCard(days: _days),
        const SizedBox(height: 16),
        _CarbonCard(days: _days),
        const SizedBox(height: 16),
        _DayBreakdown(days: _days),
      ],
    );
  }
}

class _RideStatsHeader extends StatelessWidget {
  const _RideStatsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 8),
      child: Row(
        children: [
          Tooltip(
            message: '返回',
            excludeFromSemantics: true,
            child: AppPressable(
              key: const ValueKey('ride-stats-back'),
              onTap: () => Navigator.of(context).pop(),
              semanticsLabel: '返回',
              semanticsButton: true,
              child: Container(
                width: AppTouchTargets.min,
                height: AppTouchTargets.min,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: CyberHomeColors.card,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.cyberActionShadow,
                ),
                child: const LucideIcon(
                  Lucide.arrowLeft,
                  size: 20,
                  color: CyberHomeColors.inkSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '骑行统计',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: CyberHomeColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _RideStatsGate { ready, needLogin, needVehicle, needRelogin }

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

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final String month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Container(
        height: 48,
        decoration: _rideCardDecoration,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '上个月',
              icon: const LucideIcon(Lucide.chevronLeft),
              onPressed: onPrev,
            ),
            Expanded(
              child: Text(
                month,
                textAlign: TextAlign.center,
                style: _rideItemTitle,
              ),
            ),
            IconButton(
              tooltip: '下个月',
              icon: const LucideIcon(Lucide.chevronRight),
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.days});

  final List<OfficialTravelDay> days;

  @override
  Widget build(BuildContext context) {
    final records = days.expand((day) => day.records);
    final totalKm = sumTravelMileageKm(records);
    final totalTrips = records.length;
    final totalSeconds = sumTravelDurationSeconds(records);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _rideCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本月概览',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CyberHomeColors.inkMuted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatItem(
                // Official ride-stats always shows km (setTextViewSetMilageValue).
                value: formatDecimalDown(totalKm, fractionDigits: 2),
                unit: 'km',
                label: '总里程',
              ),
              _StatItem(value: '$totalTrips', unit: '次', label: '骑行次数'),
              _StatItem(
                value: formatCompactDuration(totalSeconds),
                unit: '',
                label: '总时长',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.unit,
    required this.label,
  });

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: CyberHomeColors.ink,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CyberHomeColors.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: _rideCaptionText),
        ],
      ),
    );
  }
}

class _CarbonCard extends StatelessWidget {
  const _CarbonCard({required this.days});

  final List<OfficialTravelDay> days;

  @override
  Widget build(BuildContext context) {
    final km = sumTravelMileageKm(days.expand((day) => day.records));
    // Simple estimate: ~0.021 kg CO2 avoided per km vs car.
    final carbonKg = km * 0.021;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyberHomeColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: CyberHomeColors.line),
      ),
      child: Row(
        children: [
          const LucideIcon(Lucide.leaf, color: CyberHomeColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '约减排 ${carbonKg.toStringAsFixed(2)} kg CO₂',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CyberHomeColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBreakdown extends StatelessWidget {
  const _DayBreakdown({required this.days});

  final List<OfficialTravelDay> days;

  @override
  Widget build(BuildContext context) {
    final sorted = [...days]
      ..sort((a, b) => b.travelDate.compareTo(a.travelDate));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '每日明细',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CyberHomeColors.inkMuted,
          ),
        ),
        const SizedBox(height: 10),
        for (final day in sorted)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: _rideCardDecoration,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    day.travelDate,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CyberHomeColors.ink,
                    ),
                  ),
                ),
                Text(
                  '${formatDecimalDown(sumTravelMileageKm(day.records), fractionDigits: 2)} km',
                  style: const TextStyle(
                    fontSize: 13,
                    color: CyberHomeColors.inkMuted,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${day.records.length} 次',
                  style: const TextStyle(
                    fontSize: 13,
                    color: CyberHomeColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
