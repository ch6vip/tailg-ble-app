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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _HomeMetric(
                      label: '剩余电量',
                      value: battery != null ? '$battery' : '--',
                      unit: battery != null ? '%' : '',
                      color: batteryColor,
                      placeholderHint: isBleReady
                          ? '等待数据'
                          : '连接后查看',
                      placeholderIcon: isBleReady
                          ? Icons.hourglass_empty
                          : Icons.bluetooth_searching,
                    ),
                  ),
                  const SizedBox(width: 22),
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
                  const SizedBox(width: 14),
                  _HomeChannelPill(
                    connState: connState,
                    cloudVehicle: cloudVehicle,
                  ),
                ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ReplicaColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        if (isPlaceholder)
          Semantics(
            label: '$label，$placeholderHint',
            excludeSemantics: true,
            child: Row(
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
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: value.length > 3 ? 30 : 32,
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
          ),
      ],
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
        ? '连接中'
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
