part of 'profile_page.dart';

class _GaragePanel extends StatelessWidget {
  const _GaragePanel({
    required this.officialVehicle,
    required this.localVehicle,
    required this.onGarageTap,
    required this.onAddVehicle,
  });

  final OfficialVehicle? officialVehicle;
  final VehicleProfile? localVehicle;
  final VoidCallback onGarageTap;
  final VoidCallback onAddVehicle;

  bool get _hasVehicle => officialVehicle != null || localVehicle != null;

  @override
  Widget build(BuildContext context) {
    final vehicleName =
        officialVehicle?.displayName ?? localVehicle?.displayName ?? '暂无车辆数据';
    final battery = officialVehicle?.electricQuantity;
    final mileage = officialVehicle?.mileage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 184,
        child: Stack(
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.brandRed,
                borderRadius: BorderRadius.circular(_mineCardRadius),
              ),
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '我的车库',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0,
                    ),
                  ),
                  const Spacer(),
                  AppPressable(
                    onTap: onAddVehicle,
                    haptic: false,
                    semanticsLabel: '添加设备',
                    semanticsButton: true,
                    semanticsEnabled: true,
                    child: const SizedBox(
                      height: AppTouchTargets.min,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 17, color: Colors.white),
                          SizedBox(width: 2),
                          Text(
                            '添加设备',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 45,
              child: AppPressable(
                onTap: onGarageTap,
                haptic: false,
                semanticsLabel: '我的车库，$vehicleName',
                semanticsButton: true,
                semanticsEnabled: true,
                borderRadius: BorderRadius.circular(_mineCardRadius),
                child: Container(
                  height: 139,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_mineCardRadius),
                  ),
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 154,
                            height: 139,
                            child: Padding(
                              padding: const EdgeInsets.all(13),
                              child: _VehicleArtwork(hasVehicle: _hasVehicle),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 24, 18, 0),
                              child: _GarageInfo(
                                hasVehicle: _hasVehicle,
                                vehicleName: vehicleName,
                                battery: battery,
                                mileage: mileage,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_hasVehicle)
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.brandRed,
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(_mineCardRadius),
                                bottomLeft: Radius.circular(_mineCardRadius),
                              ),
                            ),
                            child: const Text(
                              '使用中',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleArtwork extends StatelessWidget {
  const _VehicleArtwork({required this.hasVehicle});

  final bool hasVehicle;

  @override
  Widget build(BuildContext context) {
    if (!hasVehicle) {
      return CustomPaint(
        painter: VehicleStagePainter(batteryLevel: 0.0),
        size: Size(128, 86),
      );
    }
    return Image.asset(
      'assets/official_tailg/vehicle.png',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => CustomPaint(
        painter: VehicleStagePainter(batteryLevel: 0.7),
        size: Size(128, 86),
      ),
    );
  }
}

class _GarageInfo extends StatelessWidget {
  const _GarageInfo({
    required this.hasVehicle,
    required this.vehicleName,
    required this.battery,
    required this.mileage,
  });

  final bool hasVehicle;
  final String vehicleName;
  final int? battery;
  final double? mileage;

  @override
  Widget build(BuildContext context) {
    final mileage = this.mileage;
    if (!hasVehicle) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '暂无车辆数据',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _officialMuted,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 14),
          Text(
            '门店购买或绑定后查看',
            style: TextStyle(
              fontSize: 14,
              color: _officialLight,
              letterSpacing: 0,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                vehicleName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _officialInk,
                  letterSpacing: 0,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: _officialMuted),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _VehicleMetric(
              value: battery == null ? '--' : '$battery',
              unit: '%',
              label: '剩余电量',
            ),
            const SizedBox(width: 28),
            _VehicleMetric(
              value: mileage == null ? '--' : mileage.toStringAsFixed(0),
              unit: 'km',
              label: '预估里程',
            ),
          ],
        ),
      ],
    );
  }
}

class _VehicleMetric extends StatelessWidget {
  const _VehicleMetric({
    required this.value,
    required this.unit,
    required this.label,
  });

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _officialInk,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _officialInk,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: _officialLight,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
