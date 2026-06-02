part of 'control_page.dart';

class _ControlTipBar extends StatelessWidget {
  final bool enabled;
  final bool isLocked;
  final bool isPowerOn;
  final OfficialControlChannel channel;
  final bool canUseBle;
  final bool canUseCloud;
  final String? vehicleName;
  final String? disabledReason;

  const _ControlTipBar({
    required this.enabled,
    required this.isLocked,
    required this.isPowerOn,
    required this.channel,
    required this.canUseBle,
    required this.canUseCloud,
    required this.vehicleName,
    required this.disabledReason,
  });

  @override
  Widget build(BuildContext context) {
    final effective = switch (channel) {
      OfficialControlChannel.ble => 'BLE',
      OfficialControlChannel.officialCloud => '云端',
      OfficialControlChannel.automatic =>
        canUseBle
            ? 'BLE'
            : canUseCloud
            ? '云端'
            : '待连接',
    };
    final status = enabled
        ? '${isPowerOn ? '已启动' : '未启动'} · ${isLocked ? '已设防' : '未设防'}'
        : disabledReason ?? '请连接车辆后控车';
    final effectiveColor = switch (effective) {
      'BLE' => AppColors.success,
      '云端' => ReplicaColors.blue,
      _ => ReplicaColors.muted,
    };
    final effectiveIcon = switch (effective) {
      'BLE' => Icons.bluetooth_connected,
      '云端' => Icons.cloud_done_outlined,
      _ => Icons.link_off,
    };
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: AppShadows.cardShadow,
          ),
          child: const Icon(
            Icons.smart_toy_outlined,
            size: 22,
            color: ReplicaColors.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OfficialCloudPage()),
              ),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: effectiveColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(effectiveIcon, size: 13, color: effectiveColor),
                          const SizedBox(width: 4),
                          Text(
                            effective,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: effectiveColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ReplicaColors.muted,
                        ),
                      ),
                    ),
                    if (vehicleName != null && canUseCloud) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          vehicleName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ReplicaColors.subtle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _ManualModePill(enabled: enabled),
      ],
    );
  }
}
