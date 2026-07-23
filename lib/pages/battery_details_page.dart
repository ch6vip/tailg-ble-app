import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/lucide_icon.dart';

import '../ble/connection_manager.dart' as ble;
import '../main.dart';
import '../models/battery_snapshot.dart';
import '../models/official_vehicle.dart';
import '../services/battery_help_copy.dart';
import '../services/coulomb_meter_service.dart';
import '../services/display_time_formatter.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_void.dart';
import '../widgets/app_chrome.dart';
import '../widgets/void_canvas.dart';
import '../widgets/void_typography.dart';
import '../widgets/app_snack.dart';
import 'replace_battery_page.dart';

class BatteryDetailsPage extends StatelessWidget {
  const BatteryDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OfficialCloudState>(
      stream: officialCloudService.stateStream,
      initialData: officialCloudService.state,
      builder: (context, cloudSnapshot) {
        final cloudState = cloudSnapshot.data ?? officialCloudService.state;
        final vehicle = cloudState.signedIn ? cloudState.selectedVehicle : null;
        final data = BatterySnapshot.fromSources(
          officialVehicle: vehicle,
          officialBatteryInfo: cloudState.batteryInfo,
          officialBmsInfo: cloudState.bmsInfo,
        );
        return Scaffold(
          backgroundColor: VoidColors.voidDeep,
          body: VoidCanvas(
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: () => _refreshAllBatteryData(context),
                color: VoidColors.energy,
                backgroundColor: VoidColors.voidPanel,
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
                          ? () => unawaited(_refreshAllBatteryData(context))
                          : null,
                      onCorrectBattery: cloudState.signedIn
                          ? () => _showCorrectBatterySheet(context)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Column(
                        children: [
                          _SourceStrip(snapshot: data, cloudState: cloudState),
                          const SizedBox(height: 14),
                          _BatterySyncCard(cloudState: cloudState),
                          if (vehicle != null) ...[
                            const SizedBox(height: 14),
                            _VehicleBatteryMetaCard(vehicle: vehicle),
                          ],
                          const SizedBox(height: 14),
                          _CoulombMeterCard(vehicle: vehicle),
                          const SizedBox(height: 14),
                          _OfficialSummaryRow(snapshot: data),
                          const SizedBox(height: 14),
                          _OfficialMetricGrid(
                            snapshot: data,
                            onCycleHelp: () => _showBatteryHelpSheet(
                              context,
                              title: BatteryHelpCopy.cycleTitle,
                              sections: BatteryHelpCopy.cycleSections,
                            ),
                            onScoreHelp: () => _showBatteryHelpSheet(
                              context,
                              title: BatteryHelpCopy.scoreTitle,
                              sections: BatteryHelpCopy.scoreSections,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _FaultCard(snapshot: data),
                          const SizedBox(height: 14),
                          _BmsDetailsCard(
                            snapshot: data,
                            loading: cloudState.bmsInfoLoading,
                            error: cloudState.bmsInfoError,
                          ),
                          const SizedBox(height: 14),
                          _BatteryRouteHintCard(vehicle: vehicle),
                          const SizedBox(height: 14),
                          _BatteryActionsCard(
                            signedIn: cloudState.signedIn,
                            shareCar: vehicle?.shareCarFlag == true,
                            onSwapService: () => _showInfoSheet(
                              context,
                              title: BatteryHelpCopy.swapServiceTitle,
                              body: BatteryHelpCopy.swapServiceBody,
                            ),
                            onCorrectBattery: () =>
                                _showCorrectBatterySheet(context),
                          ),
                          const SizedBox(height: 14),
                          const _BatteryReadOnlyCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshAllBatteryData(BuildContext context) async {
    if (!officialCloudService.state.signedIn) {
      AppSnack.info(context, OfficialCloudMessages.signInRequired);
      return;
    }
    try {
      await Future.wait<void>([
        officialCloudService.refreshBatteryInfo(force: true),
        officialCloudService.refreshBmsInfo(force: true, silent: true),
      ]);
      if (!context.mounted) return;
      final info = officialCloudService.state.batteryInfo;
      final bms = officialCloudService.state.bmsInfo;
      if (info?.hasData == true || bms?.hasData == true) {
        AppSnack.success(context, '电池信息已同步');
      } else {
        AppSnack.info(context, '已同步，当前暂无电池明细');
      }
    } catch (e) {
      logService.operation(
        '官方电池信息刷新失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (!context.mounted) return;
      AppSnack.error(
        context,
        OfficialCloudRedactor.errorMessage(e),
        actionLabel: '重试',
        onAction: () {
          unawaited(_refreshAllBatteryData(context));
        },
      );
    }
  }

  void _showCorrectBatterySheet(BuildContext context) {
    if (!officialCloudService.state.signedIn) {
      AppSnack.info(context, OfficialCloudMessages.signInRequired);
      return;
    }
    if (officialCloudService.state.selectedVehicle == null) {
      AppSnack.info(context, '请先选择车辆');
      return;
    }
    unawaited(
      Navigator.of(context)
          .push<bool>(
            MaterialPageRoute<bool>(builder: (_) => const ReplaceBatteryPage()),
          )
          .then((changed) {
            if (changed == true && context.mounted) {
              unawaited(_refreshAllBatteryData(context));
            }
          }),
    );
  }

  void _showBatteryHelpSheet(
    BuildContext context, {
    required String title,
    required List<({String title, String body})> sections,
  }) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.lg),
          ),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(title, style: AppTextStyles.sectionTitle),
                    const SizedBox(height: 12),
                    for (final section in sections) ...[
                      Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(section.body, style: AppTextStyles.bodySmall),
                      const SizedBox(height: 14),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('知道了'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showInfoSheet(
    BuildContext context, {
    required String title,
    required String body,
    String primaryLabel = '知道了',
    VoidCallback? onPrimary,
  }) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.lg),
          ),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(title, style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 10),
                  Text(body, style: AppTextStyles.bodySmall),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onPrimary ?? () => Navigator.pop(sheetContext),
                      child: Text(primaryLabel),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BatteryHero extends StatelessWidget {
  final BatterySnapshot snapshot;
  final OfficialCloudState cloudState;
  final VoidCallback? onRefresh;
  final VoidCallback? onCorrectBattery;

  const _BatteryHero({
    required this.snapshot,
    required this.cloudState,
    required this.onRefresh,
    required this.onCorrectBattery,
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
              icon: const Icon(
                Lucide.arrowLeft,
                color: AppColors.textPrimary,
                semanticLabel: '返回',
              ),
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
              child: KineticType(
                '电池信息',
                mode: KineticTypeMode.word,
                staggerDelay: 30,
                duration: Duration(milliseconds: 400),
                style: AppTextStyles.sectionTitle,
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppTouchTargets.min,
                  ),
                  child: TextButton(
                    onPressed:
                        (cloudState.batteryInfoLoading ||
                            cloudState.bmsInfoLoading)
                        ? null
                        : onRefresh,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: Text(
                      (cloudState.batteryInfoLoading ||
                              cloudState.bmsInfoLoading)
                          ? '刷新中'
                          : '刷新',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppTouchTargets.min,
                  ),
                  child: TextButton(
                    onPressed: onCorrectBattery,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const Text('更正电池', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
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
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    _vehicleName(snapshot),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium,
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
    return '当前车辆';
  }
}

class _BatteryGlyph extends StatelessWidget {
  final int? percent;
  final Color color;

  const _BatteryGlyph({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    final percent = this.percent;
    final value = percent == null ? 0.0 : percent.clamp(0, 100) / 100;
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
      const Radius.circular(AppRadii.sheet),
    );
    final cap = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width - 12,
        size.height * 0.34,
        12,
        size.height * 0.32,
      ),
      const Radius.circular(AppRadii.xs),
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
        const Radius.circular(AppRadii.tile),
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

class _BatterySyncCard extends StatelessWidget {
  final OfficialCloudState cloudState;

  const _BatterySyncCard({required this.cloudState});

  @override
  Widget build(BuildContext context) {
    if (!cloudState.signedIn) {
      return const SizedBox.shrink();
    }
    final sync = formatRelativeSyncText(
      officialCloudService.lastBatteryRefreshAt,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Lucide.refresh,
            size: AppIconSizes.sm,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 8),
          const Text('最后同步', style: AppTextStyles.smallText),
          const Spacer(),
          Text(
            sync,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
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
        ? '正在刷新电池信息'
        : error != null
        ? '电池信息刷新失败'
        : signedIn
        ? '电池数据已同步'
        : '登录官方账号后可同步更多电池数据';
    final subtitle =
        error ??
        (loading
            ? '正在向官方电池服务请求最新数据'
            : signedIn
            ? '电量、电压、温度来自官方电池接口；维护、校准请前往官方服务渠道'
            : '登录后可读取电量、电压、温度与 BMS 明细');
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
              error == null ? Lucide.badgeCheck : Lucide.info,
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
                Text(subtitle, style: AppTextStyles.smallText),
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
    final voltage = snapshot.voltage;
    final items = [
      _Metric('预估里程', _withUnit(snapshot.remainingMileage, 'km')),
      _Metric('总里程', _withUnit(snapshot.totalMileage, 'km')),
      _Metric('电压', voltage == null ? '待读取' : '${voltage.toStringAsFixed(1)}V'),
      _Metric('电池容量', bms.batteryCapacity ?? '待读取'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
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
  final VoidCallback onCycleHelp;
  final VoidCallback onScoreHelp;
  const _OfficialMetricGrid({
    required this.snapshot,
    required this.onCycleHelp,
    required this.onScoreHelp,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _Metric(
        '今日耗电',
        BatterySnapshot.displayMetric(snapshot.consumePowerPercent, unit: '%'),
        icon: Lucide.zap,
      ),
      _Metric(
        '循环次数',
        BatterySnapshot.displayMetric(snapshot.loopCount),
        icon: Lucide.rotateCcw,
        onHelp: onCycleHelp,
      ),
      _Metric('当前温度', _temperatureDisplay(snapshot), icon: Lucide.thermometer),
      _Metric(
        '电池评分',
        BatterySnapshot.displayMetric(snapshot.batteryScore, unit: '分'),
        icon: Lucide.gauge,
        onHelp: onScoreHelp,
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
                Row(
                  children: [
                    Flexible(
                      child: Text(metric.label, style: AppTextStyles.caption),
                    ),
                    if (metric.onHelp != null) ...[
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: metric.onHelp,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Lucide.help,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                if (hasValue)
                  Text(
                    metric.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sectionTitle,
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
            faults.isEmpty ? Lucide.checkCircle : Lucide.alertCircle,
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
  final bool loading;
  final String? error;
  const _BmsDetailsCard({
    required this.snapshot,
    required this.loading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final fields = snapshot.bms.fields;
    final hasBms = snapshot.hasOfficialBmsInfo;
    return Container(
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Lucide.list,
                  color: AppColors.primary,
                  size: AppIconSizes.md,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('BMS 详情', style: AppTextStyles.itemTitle),
                ),
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    hasBms ? '已同步' : (error == null ? '待同步' : '同步失败'),
                    style: TextStyle(
                      fontSize: 12,
                      color: hasBms
                          ? AppColors.success
                          : (error == null
                                ? AppColors.textTertiary
                                : AppColors.warning),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (error != null && !hasBms)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                error!,
                style: const TextStyle(fontSize: 12, color: AppColors.warning),
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
                    borderRadius: BorderRadius.circular(AppRadii.pill),
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
      return const _SourceChip('待同步', AppColors.warning);
    }
    return switch (field.source) {
      BatteryDataSource.officialVehicle => const _SourceChip(
        '车辆状态',
        AppColors.success,
      ),
      BatteryDataSource.officialBattery => const _SourceChip(
        '电池服务',
        AppColors.success,
      ),
      BatteryDataSource.officialBms => const _SourceChip(
        'BMS 服务',
        AppColors.success,
      ),
      BatteryDataSource.bmsReserved => const _SourceChip(
        '待同步',
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
                Lucide.lock,
                size: AppIconSizes.sm,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 8),
              Text('电池服务说明', style: AppTextStyles.itemTitle),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '当前页面用于查看电量、电压、温度、健康状态和 BMS 信息。涉及电池校准、更换和升级的操作，请通过官方服务渠道完成。',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Official TLV page "库仑计" switch (BLE FBB2 D0018A*).
class _CoulombMeterCard extends StatefulWidget {
  final OfficialVehicle? vehicle;
  const _CoulombMeterCard({required this.vehicle});

  @override
  State<_CoulombMeterCard> createState() => _CoulombMeterCardState();
}

class _CoulombMeterCardState extends State<_CoulombMeterCard> {
  StreamSubscription<ble.ConnectionState>? _bleSub;
  bool _busy = false;
  bool? _enabled; // null = unknown / need power+query
  String? _message;

  bool get _supported {
    final v = widget.vehicle;
    if (v == null) return false;
    return CoulombMeterService.isSupported(
      modelType: v.modelType,
      bmsTlvType: v.bmsTlvType,
    );
  }

  bool get _bleReady => connectionManager.isProtocolLoggedIn;

  @override
  void initState() {
    super.initState();
    _bleSub = connectionManager.stateStream.listen((_) {
      if (mounted) setState(() {});
      if (_bleReady && _enabled == null && !_busy) {
        unawaited(_query(silent: true));
      }
    });
    if (_bleReady) {
      unawaited(_query(silent: true));
    }
  }

  @override
  void dispose() {
    unawaited(_bleSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _query({bool silent = false}) async {
    if (!_supported || _busy) return;
    if (!_bleReady) {
      if (!silent && mounted) {
        AppSnack.info(context, '请先连接车辆蓝牙后再操作库仑计');
      }
      setState(() {
        _message = '需 BLE 已协议登录';
        _enabled = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final on = await CoulombMeterService.instance.queryStatus();
      if (!mounted) return;
      setState(() {
        _enabled = on;
        _message = on == null ? '请点「刷新状态」：车辆上电后获取开关' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is StateError ? e.message : '查询失败';
      });
      if (!silent) {
        AppSnack.error(
          context,
          e is StateError ? e.message : OfficialCloudRedactor.errorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(bool value) async {
    if (!_supported || _busy) return;
    if (!_bleReady) {
      AppSnack.info(context, '请先连接车辆蓝牙后再操作库仑计');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final on = await CoulombMeterService.instance.setEnabled(value);
      if (!mounted) return;
      setState(() {
        _enabled = on;
        _message = null;
      });
      AppSnack.success(context, value ? '库仑计已开启' : '库仑计已关闭');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e is StateError ? e.message : '设置失败';
      });
      AppSnack.error(
        context,
        e is StateError ? e.message : OfficialCloudRedactor.errorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();
    final lithium = widget.vehicle?.bmsTlvType.trim() == '208';
    if (lithium) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Lucide.battery,
                color: AppColors.primary,
                size: AppIconSizes.md,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('库仑计', style: AppTextStyles.itemTitle),
              ),
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch.adaptive(
                  value: _enabled == true,
                  onChanged: !_bleReady || _enabled == null
                      ? null
                      : (v) => unawaited(_toggle(v)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('开启后可自学习电量（锂电不可用）', style: AppTextStyles.bodySmall),
          const SizedBox(height: 8),
          if (!_bleReady)
            const Text(
              '需先近场连接并完成协议登录',
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            )
          else if (_message != null)
            Text(
              _message!,
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy || !_bleReady
                  ? null
                  : () => unawaited(_query(silent: false)),
              icon: const Icon(Lucide.refresh, size: 18),
              label: const Text('刷新状态'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleBatteryMetaCard extends StatelessWidget {
  final OfficialVehicle vehicle;
  const _VehicleBatteryMetaCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final spec = vehicle.batterySpecLabel.trim();
    final bind = vehicle.batteryBindDate.trim();
    final typeId = vehicle.batteryTypeId.trim();
    final tlv = vehicle.bmsTlvType.trim();
    if (spec.isEmpty && bind.isEmpty && typeId.isEmpty && tlv.isEmpty) {
      return const SizedBox.shrink();
    }
    String bindLabel = bind;
    if (bind.length >= 10) bindLabel = bind.substring(0, 10);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('电池绑定信息', style: AppTextStyles.itemTitle),
          const SizedBox(height: 10),
          if (spec.isNotEmpty)
            _MetaLine(
              label: '当前使用',
              value: spec.startsWith('当前使用') ? spec : '当前使用：$spec',
            ),
          if (bindLabel.isNotEmpty)
            _MetaLine(label: '绑定日期', value: '$bindLabel 绑定'),
          if (typeId.isNotEmpty) _MetaLine(label: '电池类型 ID', value: typeId),
          if (tlv.isNotEmpty) _MetaLine(label: 'BMS TLV', value: tlv),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final String label;
  final String value;
  const _MetaLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 88, child: Text(label, style: AppTextStyles.caption)),
          Expanded(
            child: Text(
              value,
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

class _BatteryRouteHintCard extends StatelessWidget {
  final OfficialVehicle? vehicle;
  const _BatteryRouteHintCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final modelType = vehicle?.modelType;
    final tlv = vehicle?.bmsTlvType.trim() ?? '';
    final isGps = vehicle?.isGps == 1 || vehicle?.hasGpsService == true;
    final route = _officialBatteryRoute(
      modelType: modelType,
      isGps: isGps,
      bmsTlvType: tlv,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('官方页面分流', style: AppTextStyles.itemTitle),
          const SizedBox(height: 8),
          Text(
            '当前机型 modelType=${modelType ?? "--"} · isGps=${isGps ? "1" : "0"}'
            '${tlv.isEmpty ? "" : " · bmsTlvType=$tlv"}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 6),
          Text(
            route,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '本页合并展示官方通用电池信息 + BMS 明细；C39 / TLV 专页 UI 后续按需补齐。',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  static String _officialBatteryRoute({
    required int? modelType,
    required bool isGps,
    required String bmsTlvType,
  }) {
    if (modelType == 1 || modelType == 2) {
      return '官方路由：BatteryInfoActivity（KKS/YJ）';
    }
    if (modelType == 10 || modelType == 14) {
      return '官方路由：BatteryInfoC39Activity（C39）';
    }
    if (isGps &&
        (bmsTlvType == '176' || bmsTlvType == '208' || bmsTlvType == '6000')) {
      return bmsTlvType == '176'
          ? '官方路由：BmsBatteryTlvActivity'
          : '官方路由：BatteryInfoTlvActivity';
    }
    if (isGps) return '官方路由：BatteryInfoActivity（GPS 通用）';
    return '官方路由：可能进入换电/绑定流程（无 GPS）';
  }
}

class _BatteryActionsCard extends StatelessWidget {
  final bool signedIn;
  final bool shareCar;
  final VoidCallback onSwapService;
  final VoidCallback onCorrectBattery;

  const _BatteryActionsCard({
    required this.signedIn,
    required this.shareCar,
    required this.onSwapService,
    required this.onCorrectBattery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('电池服务', style: AppTextStyles.itemTitle),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: signedIn ? onCorrectBattery : null,
                  child: const Text('更正电池'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: signedIn && !shareCar ? onSwapService : null,
                  child: Text(shareCar ? '共享车不可换电' : '换电服务'),
                ),
              ),
            ],
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
  final VoidCallback? onHelp;

  const _Metric(this.label, this.value, {this.icon = Lucide.info, this.onHelp});
}

String _withUnit(String? value, String unit) {
  return BatterySnapshot.displayMetric(value, unit: unit);
}

/// Prefer parsed temperature; fall back to raw string (e.g. "31℃") if present.
String _temperatureDisplay(BatterySnapshot snapshot) {
  final parsed = snapshot.temperature;
  if (parsed != null) {
    final text = parsed == parsed.roundToDouble()
        ? parsed.toStringAsFixed(0)
        : parsed.toStringAsFixed(1);
    return '$text°C';
  }
  final raw = snapshot.officialBatteryInfo?.temperature.trim() ?? '';
  if (raw.isEmpty || raw == '--') return '待读取';
  if (raw.contains('°') || raw.contains('℃') || raw.contains('C')) {
    return raw.replaceAll('℃', '°C');
  }
  return '$raw°C';
}
