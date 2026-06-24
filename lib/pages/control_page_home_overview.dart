part of 'control_page.dart';

/// v8 home top section: Hero + vehicle stage + status chips + control card.
///
/// Replaces the old 3-section header/status/statusline layout with
/// the v8 Ninebot-inspired two-area design (data hero + action card).
class _HomeTopSection extends StatelessWidget {
  final ble.ConnectionState connState;

  const _HomeTopSection({required this.connState});

  bool get _isReady => connState == ble.ConnectionState.ready;
  bool get _isReconnecting => connState == ble.ConnectionState.reconnecting;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      stream: connectionManager.bikeStateStream,
      initialData: connectionManager.latestBikeState,
      builder: (context, snapshot) {
        final bike = snapshot.data; // dynamic access for SOC/lock/power
        final soc = _normalizePercent(bike?.soc) ?? 0;
        final range = (soc * _kmPerPercent).round();
        final isArmed = bike?.isLocked ?? true;
        final isPowerOn = bike?.isPowerOn ?? false;
        final vehicleName =
            connectionManager.device?.platformName ??
            vehicleStore.defaultVehicle?.displayName ??
            '我的车辆';
        final connectionLabel = _isReady
            ? '蓝牙已连接'
            : _isReconnecting
            ? '重连中'
            : null;
        final cloudVehicle = officialCloudService.state.selectedVehicle;

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment(0, 0.46),
              colors: [AppColors.pageBgTop, AppColors.pageBgBot],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // v8 Hero
              ControlPageHero(
                batteryLevel: soc,
                rangeKm: range,
                healthLabel: bike != null ? '健康良好' : null,
                vehicleName: cloudVehicle?.displayName ?? vehicleName,
                connectionLabel: connectionLabel,
                onBatteryTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BatteryDetailsPage()),
                ),
              ),
              const SizedBox(height: 10),
              // v8 Vehicle stage SVG
              VehicleStage(batteryLevel: soc / 100.0, height: 180),
              // v8 Status chips row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    StatusBadge(
                      type: isArmed
                          ? StatusBadgeType.armed
                          : StatusBadgeType.idle,
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      type: isPowerOn
                          ? StatusBadgeType.online
                          : StatusBadgeType.idle,
                      label: isPowerOn ? '已通电' : '未通电',
                    ),
                    const SizedBox(width: 8),
                    if (_isReady) const StatusBadge(type: StatusBadgeType.ble),
                    if (_isReconnecting)
                      const StatusBadge(
                        type: StatusBadgeType.offline,
                        label: '重连中',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // v8 Floating control card (visual only — controls wired below)
              ControlCard(
                powered: isPowerOn,
                onMore: () => showAllFunctionsSheet(context),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
