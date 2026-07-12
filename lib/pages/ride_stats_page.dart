import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/official_vehicle.dart';
import '../services/display_time_formatter.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(_loadMonth());
  }

  Future<void> _loadMonth() async {
    final generation = ++_loadGeneration;
    final month = _month;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await officialCloudService.refreshTravelHistory(month: month);
      if (!mounted || generation != _loadGeneration) return;
      final state = officialCloudService.state;
      setState(() {
        _days = state.travelDays;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = '加载失败';
        _loading = false;
      });
    }
  }

  void _prevMonth() {
    final date = parseMonthText(_month);
    if (date == null) return;
    final prev = DateTime(date.year, date.month - 1);
    _month = formatMonthText(prev);
    unawaited(_loadMonth());
  }

  void _nextMonth() {
    final date = parseMonthText(_month);
    if (date == null) return;
    final next = DateTime(date.year, date.month + 1);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    _month = formatMonthText(next);
    unawaited(_loadMonth());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.officialPageBg,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: '骑行统计'),
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
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadMonth, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_days.isEmpty) {
      return const Center(
        child: Text('本月暂无骑行记录', style: AppTextStyles.bodyMedium),
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
    double totalKm = 0;
    int totalTrips = 0;
    int totalSeconds = 0;

    for (final day in days) {
      for (final record in day.records) {
        final km = double.tryParse(record.mileage) ?? 0;
        totalKm += km;
        totalTrips++;
        totalSeconds +=
            (int.tryParse(record.hours) ?? 0) * 3600 +
            (int.tryParse(record.min) ?? 0) * 60 +
            (int.tryParse(record.sec) ?? 0);
      }
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

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
                value: totalKm.toStringAsFixed(1),
                unit: 'km',
                label: '总里程',
              ),
              _StatItem(value: '$totalTrips', unit: '次', label: '骑行次数'),
              _StatItem(
                value: hours > 0 ? '${hours}h${minutes}m' : '${minutes}m',
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
          SizedBox(
            height: 31,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
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
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _CarbonCard extends StatelessWidget {
  const _CarbonCard({required this.days});

  final List<OfficialTravelDay> days;

  static const _kgCo2PerKm = 0.12;

  @override
  Widget build(BuildContext context) {
    double totalKm = 0;
    for (final day in days) {
      for (final record in day.records) {
        totalKm += double.tryParse(record.mileage) ?? 0;
      }
    }
    final carbonSaved = totalKm * _kgCo2PerKm;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco, color: AppColors.primary, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '碳减排贡献',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${carbonSaved.toStringAsFixed(1)} kg CO₂',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '相比驾车出行，本月骑行减少碳排放',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            '每日明细',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ...days.map((day) => _DayTile(day: day)),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day});

  final OfficialTravelDay day;

  @override
  Widget build(BuildContext context) {
    final tripCount = day.records.length;
    final mileage = day.totalMileage;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              day.travelDate,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text('$tripCount次', style: AppTextStyles.caption),
          const SizedBox(width: 12),
          Text(
            '$mileage km',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
