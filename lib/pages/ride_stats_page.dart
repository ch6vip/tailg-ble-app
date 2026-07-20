import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/official_vehicle.dart';
import '../services/display_number_formatter.dart';
import '../services/display_time_formatter.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import 'add_vehicle_page.dart';
import 'login_page.dart';

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
      backgroundColor: AppColors.officialPageBg,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '骑行统计'),
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
      return const Center(child: CircularProgressIndicator());
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
                style: AppTextStyles.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadMonth, child: const Text('重试')),
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
            style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Text(
            month,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本月概览',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
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
                    color: AppColors.textPrimary,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
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
        color: AppColors.surfaceBrandTint,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco_outlined, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '约减排 ${carbonKg.toStringAsFixed(2)} kg CO₂',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
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
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        for (final day in sorted)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.card),
              boxShadow: AppShadows.elevation1,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    day.travelDate,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${formatDecimalDown(sumTravelMileageKm(day.records), fractionDigits: 2)} km',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${day.records.length} 次',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
