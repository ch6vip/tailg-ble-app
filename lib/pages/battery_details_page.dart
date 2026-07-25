import 'dart:async';

import 'package:flutter/material.dart';

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
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/lucide_icon.dart';
import 'replace_battery_page.dart';

const _batteryCardDecoration = BoxDecoration(
  color: CyberHomeColors.card,
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.tile)),
  border: Border.fromBorderSide(BorderSide(color: CyberHomeColors.line)),
);

const _batterySectionTitle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  color: CyberHomeColors.ink,
);

const _batteryItemTitle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: CyberHomeColors.ink,
);

const _batteryBodyText = TextStyle(
  fontSize: 13,
  height: 1.45,
  color: CyberHomeColors.inkMuted,
);

const _batterySmallText = TextStyle(
  fontSize: 12,
  color: CyberHomeColors.inkMuted,
);

const _batteryCaptionText = TextStyle(
  fontSize: 12,
  color: CyberHomeColors.inkFaint,
);

final _batteryFilledButtonStyle = FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(48),
  backgroundColor: CyberHomeColors.primary,
  foregroundColor: CyberHomeColors.white,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.tile),
  ),
);

final _batteryOutlinedButtonStyle = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(48),
  foregroundColor: CyberHomeColors.inkSecondary,
  side: const BorderSide(color: CyberHomeColors.lineStrong),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.tile),
  ),
);

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
          backgroundColor: CyberHomeColors.pageBg,
          body: SafeArea(
            child: Column(
              children: [
                _BatteryHeader(
                  loading:
                      cloudState.batteryInfoLoading ||
                      cloudState.bmsInfoLoading,
                  canRefresh: cloudState.signedIn,
                  canCorrect: cloudState.signedIn,
                  onRefresh: () => unawaited(_refreshAllBatteryData(context)),
                  onCorrect: () => _showCorrectBatterySheet(context),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _refreshAllBatteryData(context),
                    color: CyberHomeColors.primary,
                    backgroundColor: CyberHomeColors.card,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      children: [
                        _BatteryHero(snapshot: data),
                        const SizedBox(height: 14),
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
                ),
              ],
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
        backgroundColor: CyberHomeColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
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
                          color: CyberHomeColors.lineStrong,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(title, style: _batterySectionTitle),
                    const SizedBox(height: 12),
                    for (final section in sections) ...[
                      Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: CyberHomeColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(section.body, style: _batteryBodyText),
                      const SizedBox(height: 14),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: _batteryFilledButtonStyle,
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
        backgroundColor: CyberHomeColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
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
                        color: CyberHomeColors.lineStrong,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(title, style: _batterySectionTitle),
                  const SizedBox(height: 10),
                  Text(body, style: _batteryBodyText),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: _batteryFilledButtonStyle,
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

class _BatteryHeader extends StatelessWidget {
  const _BatteryHeader({
    required this.loading,
    required this.canRefresh,
    required this.canCorrect,
    required this.onRefresh,
    required this.onCorrect,
  });

  final bool loading;
  final bool canRefresh;
  final bool canCorrect;
  final VoidCallback onRefresh;
  final VoidCallback onCorrect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          _BatteryHeaderAction(
            key: const ValueKey('battery-details-back'),
            icon: Lucide.arrowLeft,
            label: '返回',
            filled: true,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '电池信息',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: CyberHomeColors.ink,
              ),
            ),
          ),
          _BatteryHeaderAction(
            key: const ValueKey('battery-details-refresh'),
            icon: Lucide.refresh,
            label: '刷新',
            loading: loading,
            enabled: canRefresh && !loading,
            onTap: onRefresh,
          ),
          _BatteryHeaderAction(
            key: const ValueKey('battery-details-correct'),
            icon: Lucide.edit,
            label: '更正电池',
            enabled: canCorrect,
            onTap: onCorrect,
          ),
        ],
      ),
    );
  }
}

class _BatteryHeaderAction extends StatelessWidget {
  const _BatteryHeaderAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.filled = false,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool filled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: AppPressable(
        onTap: onTap,
        enabled: enabled,
        semanticsLabel: label,
        semanticsButton: true,
        semanticsEnabled: enabled,
        child: SizedBox(
          width: AppTouchTargets.min,
          height: AppTouchTargets.min,
          child: Center(
            child: Container(
              width: filled ? AppTouchTargets.min : 36,
              height: filled ? AppTouchTargets.min : 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filled
                    ? CyberHomeColors.card
                    : CyberHomeColors.transparent,
                shape: BoxShape.circle,
                boxShadow: filled ? AppShadows.cyberActionShadow : const [],
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: CyberHomeColors.primary,
                      ),
                    )
                  : LucideIcon(
                      icon,
                      size: 20,
                      color: enabled
                          ? CyberHomeColors.inkSecondary
                          : CyberHomeColors.inkFaint,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BatteryHero extends StatelessWidget {
  final BatterySnapshot snapshot;

  const _BatteryHero({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final percent = snapshot.percent;
    final color = _batteryColor(percent);
    return Container(
      key: const ValueKey('battery-details-hero'),
      height: 300,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: _batteryCardDecoration.copyWith(
        boxShadow: AppShadows.cyberCardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _vehicleName(snapshot),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: CyberHomeColors.inkSecondary,
                  ),
                ),
              ),
              Text(
                snapshot.healthLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: snapshot.faults.isEmpty
                      ? CyberHomeColors.success
                      : CyberHomeColors.danger,
                ),
              ),
            ],
          ),
          const Spacer(),
          _BatteryGlyph(percent: percent, color: color),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                percent == null ? '--' : '$percent',
                style: TextStyle(
                  fontSize: 68,
                  fontWeight: FontWeight.w300,
                  color: percent == null
                      ? CyberHomeColors.inkFaint
                      : CyberHomeColors.ink,
                  height: 0.92,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: percent == null ? 4 : 7),
                child: Text(
                  '%',
                  style: TextStyle(
                    fontSize: 21,
                    color: percent == null
                        ? CyberHomeColors.inkFaint
                        : CyberHomeColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            '当前电量',
            style: TextStyle(fontSize: 12, color: CyberHomeColors.inkMuted),
          ),
        ],
      ),
    );
  }

  static Color _batteryColor(int? percent) {
    if (percent == null) return CyberHomeColors.inkFaint;
    if (percent > 60) return CyberHomeColors.success;
    if (percent > 20) return CyberHomeColors.warning;
    return CyberHomeColors.danger;
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
        ..color = CyberHomeColors.shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(shell, Paint()..color = CyberHomeColors.cardMuted);
    canvas.drawRRect(
      shell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = CyberHomeColors.white,
    );
    canvas.drawRRect(cap, Paint()..color = CyberHomeColors.card);

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
              : CyberHomeColors.controlStrong,
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
        color: CyberHomeColors.card,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: CyberHomeColors.line),
      ),
      child: Row(
        children: [
          const LucideIcon(
            Lucide.refresh,
            size: AppIconSizes.sm,
            color: CyberHomeColors.inkFaint,
          ),
          const SizedBox(width: 8),
          const Text('最后同步', style: _batterySmallText),
          const Spacer(),
          Text(
            sync,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: CyberHomeColors.inkMuted,
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
        ? CyberHomeColors.warning
        : loading
        ? CyberHomeColors.primary
        : CyberHomeColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: color.withValues(alpha: 0.18)),
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
            LucideIcon(
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
                Text(subtitle, style: _batterySmallText),
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
      decoration: _batteryCardDecoration,
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
                          left: BorderSide(color: CyberHomeColors.line),
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
                height: 112,
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
            color: metric.value == '待读取'
                ? CyberHomeColors.inkFaint
                : CyberHomeColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          metric.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: CyberHomeColors.inkFaint),
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
      decoration: _batteryCardDecoration,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: CyberHomeColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: LucideIcon(
              metric.icon,
              color: CyberHomeColors.primary,
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
                      child: Text(metric.label, style: _batteryCaptionText),
                    ),
                    if (metric.onHelp != null) ...[
                      const SizedBox(width: 2),
                      AppPressable(
                        onTap: metric.onHelp,
                        semanticsLabel: '${metric.label}说明',
                        semanticsButton: true,
                        child: const SizedBox(
                          width: AppTouchTargets.min,
                          height: AppTouchTargets.min,
                          child: Center(
                            child: LucideIcon(
                              Lucide.help,
                              size: 16,
                              color: CyberHomeColors.inkFaint,
                            ),
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
                    style: _batterySectionTitle,
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(
                      width: 56,
                      height: 16,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: CyberHomeColors.controlStrong,
                          borderRadius: BorderRadius.all(
                            Radius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
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

class _FaultCard extends StatelessWidget {
  final BatterySnapshot snapshot;
  const _FaultCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final faults = snapshot.faults;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _batteryCardDecoration,
      child: Row(
        children: [
          LucideIcon(
            faults.isEmpty ? Lucide.checkCircle : Lucide.alertCircle,
            color: faults.isEmpty
                ? CyberHomeColors.success
                : CyberHomeColors.danger,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              faults.isEmpty ? '未发现电池相关故障' : faults.join('、'),
              style: const TextStyle(fontSize: 14, color: CyberHomeColors.ink),
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
      decoration: _batteryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const LucideIcon(
                  Lucide.list,
                  color: CyberHomeColors.primary,
                  size: AppIconSizes.md,
                ),
                const SizedBox(width: 8),
                const Expanded(child: Text('BMS 详情', style: _batteryItemTitle)),
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
                          ? CyberHomeColors.success
                          : (error == null
                                ? CyberHomeColors.inkFaint
                                : CyberHomeColors.warning),
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
                style: const TextStyle(
                  fontSize: 12,
                  color: CyberHomeColors.warning,
                ),
              ),
            ),
          ...List.generate(fields.length, (index) {
            final field = fields[index];
            return Column(
              children: [
                _BmsFieldRow(field: field),
                if (index != fields.length - 1)
                  const Divider(
                    height: 1,
                    indent: 16,
                    color: CyberHomeColors.line,
                  ),
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
        ? CyberHomeColors.ink
        : CyberHomeColors.inkFaint;
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
                    color: CyberHomeColors.ink,
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
      return const _SourceChip('待同步', CyberHomeColors.warning);
    }
    return switch (field.source) {
      BatteryDataSource.officialVehicle => const _SourceChip(
        '车辆状态',
        CyberHomeColors.success,
      ),
      BatteryDataSource.officialBattery => const _SourceChip(
        '电池服务',
        CyberHomeColors.success,
      ),
      BatteryDataSource.officialBms => const _SourceChip(
        'BMS 服务',
        CyberHomeColors.success,
      ),
      BatteryDataSource.bmsReserved => const _SourceChip(
        '待同步',
        CyberHomeColors.warning,
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
      decoration: _batteryCardDecoration,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LucideIcon(
                Lucide.lock,
                size: AppIconSizes.sm,
                color: CyberHomeColors.inkMuted,
              ),
              SizedBox(width: 8),
              Text('电池服务说明', style: _batteryItemTitle),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '当前页面用于查看电量、电压、温度、健康状态和 BMS 信息。涉及电池校准、更换和升级的操作，请通过官方服务渠道完成。',
            style: _batteryBodyText,
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
      decoration: _batteryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LucideIcon(
                Lucide.battery,
                color: CyberHomeColors.primary,
                size: AppIconSizes.md,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('库仑计', style: _batteryItemTitle)),
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch.adaptive(
                  value: _enabled == true,
                  activeThumbColor: CyberHomeColors.white,
                  activeTrackColor: CyberHomeColors.primary,
                  inactiveThumbColor: CyberHomeColors.white,
                  inactiveTrackColor: CyberHomeColors.controlStrong,
                  onChanged: !_bleReady || _enabled == null
                      ? null
                      : (v) => unawaited(_toggle(v)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('开启后可自学习电量（锂电不可用）', style: _batteryBodyText),
          const SizedBox(height: 8),
          if (!_bleReady)
            const Text(
              '需先近场连接并完成协议登录',
              style: TextStyle(fontSize: 12, color: CyberHomeColors.warning),
            )
          else if (_message != null)
            Text(
              _message!,
              style: const TextStyle(
                fontSize: 12,
                color: CyberHomeColors.warning,
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppTouchTargets.min),
                foregroundColor: CyberHomeColors.primary,
              ),
              onPressed: _busy || !_bleReady
                  ? null
                  : () => unawaited(_query(silent: false)),
              icon: const LucideIcon(Lucide.refresh, size: 18),
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
      decoration: _batteryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('电池绑定信息', style: _batteryItemTitle),
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
          SizedBox(width: 88, child: Text(label, style: _batteryCaptionText)),
          Expanded(
            child: Text(
              value,
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
      decoration: _batteryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('官方页面分流', style: _batteryItemTitle),
          const SizedBox(height: 8),
          Text(
            '当前机型 modelType=${modelType ?? "--"} · isGps=${isGps ? "1" : "0"}'
            '${tlv.isEmpty ? "" : " · bmsTlvType=$tlv"}',
            style: _batteryCaptionText,
          ),
          const SizedBox(height: 6),
          Text(
            route,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CyberHomeColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '本页合并展示官方通用电池信息 + BMS 明细；C39 / TLV 专页 UI 后续按需补齐。',
            style: _batteryBodyText,
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
      decoration: _batteryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('电池服务', style: _batteryItemTitle),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: _batteryOutlinedButtonStyle,
                  onPressed: signedIn ? onCorrectBattery : null,
                  child: const Text('更正电池'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: _batteryOutlinedButtonStyle,
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
