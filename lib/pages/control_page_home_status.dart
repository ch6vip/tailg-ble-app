part of 'control_page.dart';

class _StatusSection extends StatelessWidget {
  final ble.ConnectionState connState;
  const _StatusSection({required this.connState});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BikeState?>(
      stream: connectionManager.bikeStateStream,
      initialData: connectionManager.latestBikeState,
      builder: (context, snapshot) {
        final bike = snapshot.data;
        return StreamBuilder<OfficialCloudState>(
          stream: officialCloudService.stateStream,
          initialData: officialCloudService.state,
          builder: (context, cloudSnapshot) {
            final cloudState = cloudSnapshot.data ?? officialCloudService.state;
            final cloudVehicle = cloudState.signedIn
                ? cloudState.selectedVehicle
                : null;
            final isBleReady = connState == ble.ConnectionState.ready;
            final battery = _normalizePercent(
              isBleReady
                  ? bike?.batteryPercent ?? cloudVehicle?.electricQuantity
                  : cloudVehicle?.electricQuantity,
            );
            final batteryColor = battery == null
                ? Colors.grey
                : battery > 60
                ? Colors.green
                : battery > 20
                ? Colors.orange
                : Colors.red;
            final mileage = cloudVehicle?.mileage;
            final rangeText = mileage != null
                ? _formatMetricNumber(mileage)
                : battery != null
                ? '${(battery * _kmPerPercent).round()}'
                : '--';
            final rangeLabel = mileage != null ? '累计里程' : '预估里程';

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 330;
                  final metricGap = compact ? 14.0 : 22.0;
                  final channelGap = compact ? 8.0 : 14.0;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _HomeMetric(
                          label: '剩余电量',
                          value: battery != null ? '$battery' : '--',
                          unit: battery != null ? '%' : '',
                          color: batteryColor,
                          placeholderHint: isBleReady ? '等待数据' : '连接后查看',
                          placeholderIcon: isBleReady
                              ? Icons.hourglass_empty
                              : Icons.bluetooth_searching,
                        ),
                      ),
                      SizedBox(width: metricGap),
                      Expanded(
                        child: _HomeMetric(
                          label: rangeLabel,
                          value: rangeText,
                          unit: rangeText == '--' ? '' : 'km',
                          placeholderHint: mileage != null
                              ? null
                              : isBleReady
                              ? '等待数据'
                              : '连接后查看',
                          placeholderIcon: Icons.hourglass_empty,
                        ),
                      ),
                      SizedBox(width: channelGap),
                      _HomeChannelPill(
                        connState: connState,
                        cloudVehicle: cloudVehicle,
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _HomeMetric extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final String? placeholderHint;
  final IconData? placeholderIcon;

  const _HomeMetric({
    required this.label,
    required this.value,
    required this.unit,
    this.color = ReplicaColors.ink,
    this.placeholderHint,
    this.placeholderIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = value == '--' && placeholderHint != null;
    return Semantics(
      label: '$label${isPlaceholder ? '，$placeholderHint' : '，$value$unit'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ReplicaColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          if (isPlaceholder)
            Row(
              children: [
                Icon(
                  placeholderIcon ?? Icons.hourglass_empty,
                  size: 16,
                  color: ReplicaColors.muted,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    placeholderHint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ReplicaColors.muted,
                    ),
                  ),
                ),
              ],
            )
          else
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: _animatedMetricValue(value)),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, animated, _) {
                final display = _formatAnimated(value, animated);
                final fontSize = display.length > 4
                    ? 26.0
                    : display.length > 3
                    ? 30.0
                    : 32.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSize,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    if (unit.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          unit,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ReplicaColors.ink,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _HomeChannelPill extends StatelessWidget {
  final ble.ConnectionState connState;
  final OfficialVehicle? cloudVehicle;

  const _HomeChannelPill({required this.connState, required this.cloudVehicle});

  @override
  Widget build(BuildContext context) {
    final ready = connState == ble.ConnectionState.ready;
    final connecting =
        connState == ble.ConnectionState.connecting ||
        connState == ble.ConnectionState.reconnecting;
    final cloudReady = cloudVehicle != null;
    final color = ready
        ? AppColors.success
        : connecting
        ? AppColors.warning
        : cloudReady
        ? ReplicaColors.blue
        : ReplicaColors.muted;
    final text = ready
        ? 'BLE'
        : connecting
        ? connState.label
        : cloudReady
        ? '云端'
        : '离线';
    final icon = ready
        ? Icons.bluetooth_connected
        : connecting
        ? Icons.sync
        : cloudReady
        ? Icons.cloud_done_outlined
        : Icons.bluetooth_disabled;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(ReplicaRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 把当前的 metric 字符串解析成 double，用于 TweenAnimationBuilder 的目标值。
/// 不是数字的（如预留字符串）直接返回 0，避免动画跳到随机数。
double _animatedMetricValue(String value) {
  final parsed = num.tryParse(value);
  return parsed?.toDouble() ?? 0;
}

/// 根据 TweenAnimationBuilder 传入的当前动画值渲染最终展示字符串。
/// 整数 metric 始终保持整数显示；带小数的 metric 保留 1 位小数。
String _formatAnimated(String target, double animatedValue) {
  final parsed = num.tryParse(target);
  if (parsed == null) return target;
  if (!_hasFraction(target)) return animatedValue.round().toString();
  return animatedValue.toStringAsFixed(1);
}

bool _hasFraction(String value) => value.contains('.');
