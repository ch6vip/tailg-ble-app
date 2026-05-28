import 'package:flutter/material.dart';

import '../ble/constants.dart';
import '../main.dart';
import '../models/battery_snapshot.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';

class BatteryDetailsPage extends StatelessWidget {
  const BatteryDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BikeState?>(
      stream: connectionManager.bikeStateStream,
      initialData: connectionManager.latestBikeState,
      builder: (context, snapshot) {
        final data = BatterySnapshot.fromBikeState(snapshot.data);
        return Scaffold(
          backgroundColor: AppColors.pageBg,
          body: SafeArea(
            child: Column(
              children: [
                const AppPageHeader(title: '电池/BMS'),
                ConnectionStatusBanner(
                  state: connectionManager.state,
                  onScanTap: () => openScanTab(context),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      _BatteryHero(snapshot: data),
                      const SizedBox(height: 14),
                      _MetricsGrid(snapshot: data),
                      const SizedBox(height: 14),
                      _FaultCard(snapshot: data),
                      const SizedBox(height: 14),
                      _BmsDetailsCard(snapshot: data),
                      const SizedBox(height: 14),
                      const _BatteryNotesCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BatteryHero extends StatelessWidget {
  final BatterySnapshot snapshot;
  const _BatteryHero({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final percent = snapshot.percent;
    final color = percent == null
        ? AppColors.textTertiary
        : percent > 60
        ? AppColors.success
        : percent > 20
        ? AppColors.warning
        : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration,
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.battery_charging_full, color: color, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '电池状态',
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 4),
                Text(
                  percent == null ? '--%' : '$percent%',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  snapshot.healthLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: snapshot.faults.isEmpty
                        ? AppColors.success
                        : AppColors.danger,
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

class _MetricsGrid extends StatelessWidget {
  final BatterySnapshot snapshot;
  const _MetricsGrid({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final range = snapshot.estimatedRangeKm;
    final items = [
      _Metric(
        '电压',
        snapshot.voltage == null
            ? '--'
            : '${snapshot.voltage!.toStringAsFixed(1)}V',
      ),
      _Metric(
        '温度',
        snapshot.temperature == null
            ? '--'
            : '${snapshot.temperature!.toStringAsFixed(1)}°C',
      ),
      _Metric(
        '信号',
        snapshot.signalStrength == null
            ? '--'
            : '${snapshot.signalStrength}dBm',
      ),
      _Metric('预估续航', range == null ? '--' : '${range.toStringAsFixed(1)}km'),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 86,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => _MetricTile(metric: items[index]),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final _Metric metric;
  const _MetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            metric.label,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 6),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaultCard extends StatelessWidget {
  final BatterySnapshot snapshot;
  const _FaultCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final faults = snapshot.faults;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Row(
        children: [
          Icon(
            faults.isEmpty ? Icons.check_circle_outline : Icons.error_outline,
            color: faults.isEmpty ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              faults.isEmpty ? '未发现电池相关故障' : faults.join('、'),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BmsDetailsCard extends StatelessWidget {
  final BatterySnapshot snapshot;
  const _BmsDetailsCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final fields = snapshot.bms.fields;
    return Container(
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'BMS 详情',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ...List.generate(fields.length, (index) {
            final field = fields[index];
            return Column(
              children: [
                _BmsFieldRow(field: field),
                if (index != fields.length - 1)
                  const Divider(height: 1, indent: 16, color: AppColors.border),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _BmsFieldRow extends StatelessWidget {
  final BmsField field;
  const _BmsFieldRow({required this.field});

  @override
  Widget build(BuildContext context) {
    final color = field.hasValue
        ? AppColors.textPrimary
        : AppColors.textTertiary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '来源：${field.source}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            field.displayValue,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryNotesCard extends StatelessWidget {
  const _BatteryNotesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BMS 扩展数据',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '字段结构已按官方 TLV/BMS/C39 页面预留。当前只展示 feb3 心跳中可确认的 SOC、电压和温度；循环次数、SOH、容量、版本等仍需确认读取来源后接入。',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _Metric {
  final String label;
  final String value;
  const _Metric(this.label, this.value);
}
