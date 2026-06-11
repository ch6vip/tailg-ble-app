import 'dart:async';

import 'package:flutter/material.dart';

import '../ble/constants.dart';
import '../main.dart';
import '../models/battery_snapshot.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';

class BatteryDetailsPage extends StatelessWidget {
  const BatteryDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BikeState?>(
      stream: connectionManager.bikeStateStream,
      initialData: connectionManager.latestBikeState,
      builder: (context, bikeSnapshot) {
        return StreamBuilder<OfficialCloudState>(
          stream: officialCloudService.stateStream,
          initialData: officialCloudService.state,
          builder: (context, cloudSnapshot) {
            final cloudState = cloudSnapshot.data ?? officialCloudService.state;
            final data = BatterySnapshot.fromSources(
              bikeState: bikeSnapshot.data,
              officialVehicle: cloudState.signedIn
                  ? cloudState.selectedVehicle
                  : null,
              officialBatteryInfo: cloudState.batteryInfo,
            );
            return Scaffold(
              backgroundColor: AppColors.pageBg,
              body: SafeArea(
                child: RefreshIndicator(
                  onRefresh: () => _refreshOfficialBattery(context),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _BatteryHero(
                        snapshot: data,
                        cloudState: cloudState,
                        onRefresh: cloudState.signedIn
                            ? () => _refreshOfficialBattery(context)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: Column(
                          children: [
                            _SourceStrip(
                              snapshot: data,
                              cloudState: cloudState,
                            ),
                            const SizedBox(height: 14),
                            _OfficialSummaryRow(snapshot: data),
                            const SizedBox(height: 14),
                            _OfficialMetricGrid(snapshot: data),
                            const SizedBox(height: 14),
                            _FaultCard(snapshot: data),
                            const SizedBox(height: 14),
                            _BmsDetailsCard(snapshot: data),
                            const SizedBox(height: 14),
                            const _BatteryReadOnlyCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _refreshOfficialBattery(BuildContext context) async {
    if (!officialCloudService.state.signedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录官方账号')));
      return;
    }
    try {
      await officialCloudService.refreshBatteryInfo();
    } catch (e) {
      logService.operation(
        '官方电池信息刷新失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _BatteryHero extends StatelessWidget {
  final BatterySnapshot snapshot;
  final OfficialCloudState cloudState;
  final VoidCallback? onRefresh;

  const _BatteryHero({
    required this.snapshot,
    required this.cloudState,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final percent = snapshot.percent;
    final color = _batteryColor(percent);
    return Container(
      height: 430,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFE9F1FF),
            Color(0xFFDDE9FF),
            AppColors.pageBg,
          ],
          stops: [0, 0.42, 0.74, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -60,
            top: 80,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.38),
              ),
            ),
          ),
          Positioned(
            right: -74,
            top: 142,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: 4,
            top: 0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
              padding: const EdgeInsets.all(16),
              tooltip: '返回',
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 14,
            child: Center(
              child: Text(
                '电池信息',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 14,
            child: TextButton(
              onPressed: cloudState.batteryInfoLoading ? null : onRefresh,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: Text(
                cloudState.batteryInfoLoading ? '刷新中' : '更正电池',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          Positioned.fill(
            top: 70,
            child: Column(
              children: [
                SizedBox(
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 188,
                        height: 104,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: Colors.white.withValues(alpha: 0.56),
                        ),
                      ),
                      _BatteryGlyph(percent: percent, color: color),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: percent == null
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      percent == null ? '--' : '$percent',
                      style: TextStyle(
                        fontSize: 88,
                        fontWeight: FontWeight.w300,
                        color: percent == null
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                        height: 0.92,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: percent == null ? 0 : 9),
                      child: Text(
                        '%',
                        style: TextStyle(
                          fontSize: 24,
                          color: percent == null
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(ReplicaRadii.pill),
                  ),
                  child: Text(
                    _vehicleName(snapshot),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  snapshot.healthLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

  static Color _batteryColor(int? percent) {
    if (percent == null) return AppColors.textTertiary;
    if (percent > 60) return AppColors.success;
    if (percent > 20) return AppColors.warning;
    return AppColors.danger;
  }

  static String _vehicleName(BatterySnapshot snapshot) {
    final vehicle = snapshot.officialVehicle;
    if (vehicle != null) return vehicle.displayName;
    final device = connectionManager.device;
    final name = device?.platformName.trim();
    if (name != null && name.isNotEmpty) return name;
    return '当前车辆';
  }
}

class _BatteryGlyph extends StatelessWidget {
  final int? percent;
  final Color color;

  const _BatteryGlyph({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    final value = percent == null ? 0.0 : percent!.clamp(0, 100) / 100;
    return CustomPaint(
      size: const Size(148, 74),
      painter: _BatteryReplicaPainter(value: value, color: color),
    );
  }
}

class _BatteryReplicaPainter extends CustomPainter {
  final double value;
  final Color color;

  const _BatteryReplicaPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final shell = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 8, size.width - 12, size.height - 16),
      const Radius.circular(18),
    );
    final cap = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width - 12,
        size.height * 0.34,
        12,
        size.height * 0.32,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      shell.shift(const Offset(0, 4)),
      Paint()
        ..color = const Color(0x22000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(
      shell,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFEFF3FA)],
        ).createShader(shell.outerRect),
    );
    canvas.drawRRect(
      shell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    canvas.drawRRect(cap, Paint()..color = Colors.white.withValues(alpha: 0.9));

    final inner = shell.deflate(10);
    const segments = 5;
    const gap = 5.0;
    final segmentWidth = (inner.width - gap * (segments - 1)) / segments;
    final activeSegments = (value * segments).ceil();
    for (var i = 0; i < segments; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          inner.left + i * (segmentWidth + gap),
          inner.top,
          segmentWidth,
          inner.height,
        ),
        const Radius.circular(8),
      );
      final active = i < activeSegments && value > 0;
      canvas.drawRRect(
        rect,
        Paint()
          ..color = active
              ? color.withValues(alpha: i == activeSegments - 1 ? 0.78 : 0.94)
              : const Color(0xFFE1E5EC),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BatteryReplicaPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

class _SourceStrip extends StatelessWidget {
  final BatterySnapshot snapshot;
  final OfficialCloudState cloudState;

  const _SourceStrip({required this.snapshot, required this.cloudState});

  @override
  Widget build(BuildContext context) {
    final signedIn = cloudState.signedIn;
    final loading = cloudState.batteryInfoLoading;
    final error = cloudState.batteryInfoError;
    final title = loading
        ? '正在刷新官方电池信息'
        : error != null
        ? '官方电池信息刷新失败'
        : signedIn
        ? '数据来源：${snapshot.dataSourceLabel}'
        : '未登录官方账号，仅显示本地 BLE 数据';
    final subtitle = error ?? '官方接口只用于只读展示；BMS 写入、校准和升级未开放';
    final color = error != null
        ? AppColors.warning
        : loading
        ? AppColors.info
        : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          if (loading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(
              error == null ? Icons.verified_outlined : Icons.info_outline,
              color: color,
              size: AppIconSizes.md,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
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

class _OfficialSummaryRow extends StatelessWidget {
  final BatterySnapshot snapshot;
  const _OfficialSummaryRow({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final bms = snapshot.bms;
    final items = [
      _Metric('预估里程', _withUnit(snapshot.remainingMileage, 'km')),
      _Metric('总里程', _withUnit(snapshot.totalMileage, 'km')),
      _Metric(
        '电压',
        snapshot.voltage == null
            ? '待读取'
            : '${snapshot.voltage!.toStringAsFixed(1)}V',
      ),
      _Metric('电池容量', bms.batteryCapacity ?? '待读取'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: ReplicaColors.darkPanel,
        borderRadius: BorderRadius.all(Radius.circular(ReplicaRadii.card)),
        boxShadow: AppShadows.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: IntrinsicHeight(
        child: Row(
          children: List.generate(items.length, (index) {
            return Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: index == 0
                      ? null
                      : const Border(
                          left: BorderSide(color: Colors.white, width: 0.5),
                        ),
                ),
                child: _CompactMetric(metric: items[index]),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _OfficialMetricGrid extends StatelessWidget {
  final BatterySnapshot snapshot;
  const _OfficialMetricGrid({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Metric(
        '今日耗电',
        _withUnit(snapshot.consumePowerPercent, '%'),
        icon: Icons.bolt_outlined,
      ),
      _Metric('循环次数', snapshot.loopCount ?? '待读取', icon: Icons.autorenew),
      _Metric(
        '当前温度',
        snapshot.temperature == null
            ? '待读取'
            : '${snapshot.temperature!.toStringAsFixed(1)}°C',
        icon: Icons.thermostat,
      ),
      _Metric(
        '电池评分',
        _withUnit(snapshot.batteryScore, '分'),
        icon: Icons.speed_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final compact = constraints.maxWidth < 330;
        final tileWidth = compact
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: tileWidth,
                height: 96,
                child: _MetricTile(metric: item),
              ),
          ],
        );
      },
    );
  }
}

class _CompactMetric extends StatelessWidget {
  final _Metric metric;
  const _CompactMetric({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          metric.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: metric.value.length > 8 ? 14 : 16,
            fontWeight: FontWeight.w700,
            color: metric.value == '待读取' ? Colors.white38 : Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          metric.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final _Metric metric;
  const _MetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    final hasValue = metric.value != '待读取';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(
              metric.icon,
              color: AppColors.primary,
              size: AppIconSizes.md,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  metric.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 5),
                if (hasValue)
                  Text(
                    metric.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: AppSkeleton(width: 56, height: 16),
                  ),
              ],
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
            child: Row(
              children: [
                Icon(
                  Icons.list_alt_outlined,
                  color: AppColors.primary,
                  size: AppIconSizes.md,
                ),
                SizedBox(width: 8),
                Text(
                  'BMS 详情',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
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
    final source = _sourceDisplay(field);
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
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: source.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    source.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: source.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              field.displayValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _SourceChip _sourceDisplay(BmsField field) {
    if (!field.hasValue) {
      return const _SourceChip('官方字段预留', AppColors.warning);
    }
    return switch (field.source) {
      BatteryDataSource.ble => const _SourceChip(
        'BLE feb3 已确认',
        AppColors.textSecondary,
      ),
      BatteryDataSource.officialVehicle => const _SourceChip(
        '官方车辆状态',
        AppColors.success,
      ),
      BatteryDataSource.officialBattery => const _SourceChip(
        '官方电池接口',
        AppColors.success,
      ),
      BatteryDataSource.bmsReserved => const _SourceChip(
        '官方字段预留',
        AppColors.warning,
      ),
    };
  }
}

class _SourceChip {
  final String label;
  final Color color;

  const _SourceChip(this.label, this.color);
}

class _BatteryReadOnlyCard extends StatelessWidget {
  const _BatteryReadOnlyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: AppIconSizes.sm,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 8),
              Text(
                '只读复刻边界',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '已复刻官方电池信息、BMS 与 C39 电池页的展示结构。刷新只读取官方电池信息；校准电池、换电池、升级电池和 BMS 写入类操作保持禁用，等真实协议和失败回滚验证完成后再开放。',
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
  final IconData icon;

  const _Metric(this.label, this.value, {this.icon = Icons.info_outline});
}

String _withUnit(String? value, String unit) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return '待读取';
  if (text.endsWith(unit)) return text;
  return '$text$unit';
}
