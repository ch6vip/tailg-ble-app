part of 'control_page.dart';

class _HomeQuickSection extends StatefulWidget {
  const _HomeQuickSection();

  @override
  State<_HomeQuickSection> createState() => _HomeQuickSectionState();
}

class _HomeQuickSectionState extends State<_HomeQuickSection> {
  late final ValueNotifier<OfficialCloudState> _cloudStateNotifier;
  late final ValueNotifier<List<VehicleProfile>> _vehiclesNotifier;
  late final StreamSubscription<OfficialCloudState> _cloudStateSub;
  late final StreamSubscription<List<VehicleProfile>> _vehiclesSub;

  @override
  void initState() {
    super.initState();
    _cloudStateNotifier = ValueNotifier(officialCloudService.state);
    _vehiclesNotifier = ValueNotifier(vehicleStore.vehicles);
    _cloudStateSub = officialCloudService.stateStream.listen((state) {
      if (mounted) _cloudStateNotifier.value = state;
    });
    _vehiclesSub = vehicleStore.vehiclesStream.listen((vehicles) {
      if (mounted) _vehiclesNotifier.value = vehicles;
    });
  }

  @override
  void dispose() {
    _cloudStateSub.cancel();
    _vehiclesSub.cancel();
    _cloudStateNotifier.dispose();
    _vehiclesNotifier.dispose();
    super.dispose();
  }

  void _open(BuildContext context, Widget page, {bool requireVehicle = true}) {
    if (requireVehicle && !requireCloudVehicle(context)) return;
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  void _showUnavailable(BuildContext context, String label) {
    AppSnack.featureUnavailable(context, label);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OfficialCloudState>(
      valueListenable: _cloudStateNotifier,
      builder: (context, cloudState, _) {
        return ValueListenableBuilder<List<VehicleProfile>>(
          valueListenable: _vehiclesNotifier,
          builder: (context, vehicles, __) {
            final vehicle = cloudState.selectedVehicle;
            final localVehicle = _defaultLocalVehicle(vehicles);
            final location = _resolveLocationSummary(
              cloudState: cloudState,
              localVehicle: localVehicle,
            );
            final showGpsBanner =
                cloudState.selectedVehicle?.hasGpsService != true;
            final showNavigationProjection = _supportsNavigationProjection(
              vehicle,
            );
            final showCamera = _supportsCamera(vehicle);
            final showSmartMeter = _supportsSmartMeter(vehicle);
            final showChargingStation = _supportsChargingStation(vehicle);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _OfficialMapCard(
                    location: location,
                    onTap: () => _open(context, const LocationPage()),
                  ),
                  if (showNavigationProjection) ...[
                    const SizedBox(height: 10),
                    _OfficialNavigationProjectionCard(
                      onTap: () => _showUnavailable(context, '导航投屏'),
                    ),
                  ],
                  if (showCamera) ...[
                    const SizedBox(height: 10),
                    _OfficialSimpleServiceCard(
                      title: '摄像头',
                      subtitle: '暂未开放，敬请期待',
                      icon: Icons.videocam_outlined,
                      onTap: () => _showUnavailable(context, '摄像头'),
                    ),
                  ],
                  if (showSmartMeter) ...[
                    const SizedBox(height: 10),
                    _OfficialSmartMeterCard(
                      onTap: () => _showUnavailable(context, '智能仪表'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _OfficialHistoryCard(
                    todayCount: logService
                        .byCategory(LogCategory.operation)
                        .length,
                    onTap: () => _open(
                      context,
                      const LocationPage(initialTab: LocationInitialTab.travel),
                    ),
                  ),
                  if (showGpsBanner) ...[
                    const SizedBox(height: 10),
                    _OfficialGpsBanner(
                      onTap: () => _open(
                        context,
                        const OfficialCloudPage(),
                        requireVehicle: false,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _OfficialSettingsCard(
                    onVehicleSetting: () =>
                        _open(context, const VehicleSettingsPage()),
                    onFence: () => _open(
                      context,
                      const LocationPage(initialTab: LocationInitialTab.fence),
                    ),
                    onShare: () => _showUnavailable(context, '共享车辆'),
                  ),
                  const SizedBox(height: 10),
                  _OfficialImageBanner(
                    asset:
                        'assets/official_tailg/iv_add_sound_effects_set_qgj.webp',
                    semanticsLabel: 'QGJ音效设置',
                    onTap: () => _showUnavailable(context, 'QGJ音效设置'),
                  ),
                  const SizedBox(height: 10),
                  _OfficialNfcCard(
                    onTap: () => _showUnavailable(context, 'NFC钥匙'),
                  ),
                  if (showChargingStation) ...[
                    const SizedBox(height: 10),
                    _OfficialSimpleServiceCard(
                      title: '台铃充电站',
                      subtitle: '暂未开放，敬请期待',
                      icon: Icons.electrical_services_outlined,
                      onTap: () => _showUnavailable(context, '台铃充电站'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  VehicleProfile? _defaultLocalVehicle(List<VehicleProfile> vehicles) {
    if (vehicles.isEmpty) return null;
    final defaultId = vehicleStore.defaultVehicleId;
    if (defaultId == null) return vehicles.first;
    for (final vehicle in vehicles) {
      if (vehicle.id == defaultId) return vehicle;
    }
    return vehicles.first;
  }

  _LocationSummary? _resolveLocationSummary({
    required OfficialCloudState cloudState,
    required VehicleProfile? localVehicle,
  }) {
    final cloudLocation = cloudState.vehicleLocation;
    if (cloudLocation != null) {
      final cloudLat = cloudLocation.latitude;
      final cloudLng = cloudLocation.longitude;
      if (cloudLat != null &&
          cloudLng != null &&
          !isZeroCoordinate(cloudLat, cloudLng, tolerance: 0.000001)) {
        return _LocationSummary(
          latitude: cloudLat,
          longitude: cloudLng,
          timeLabel: cloudLocation.bleConnectTime.trim(),
          address: cloudLocation.bleConnectAddress.trim(),
          source: '官方停车位置',
        );
      }
      if (cloudLocation.hasData) {
        return _LocationSummary(
          latitude: null,
          longitude: null,
          timeLabel: cloudLocation.bleConnectTime.trim(),
          address: cloudLocation.bleConnectAddress.trim(),
          source: '官方停车位置',
        );
      }
    }

    final officialVehicle = cloudState.selectedVehicle;
    final vehicleLat = double.tryParse(officialVehicle?.latitude ?? '');
    final vehicleLng = double.tryParse(officialVehicle?.longitude ?? '');
    if (vehicleLat != null &&
        vehicleLng != null &&
        !isZeroCoordinate(vehicleLat, vehicleLng, tolerance: 0.000001)) {
      return _LocationSummary(
        latitude: vehicleLat,
        longitude: vehicleLng,
        timeLabel: '',
        address: '',
        source: '官方车辆状态',
      );
    }

    final local = localVehicle?.lastLocation;
    if (local != null &&
        !isZeroCoordinate(
          local.latitude,
          local.longitude,
          tolerance: 0.000001,
        )) {
      return _LocationSummary(
        latitude: local.latitude,
        longitude: local.longitude,
        timeLabel: formatDateMinuteText(local.recordedAt),
        address: '',
        source: '本地记录',
      );
    }
    return null;
  }

  bool _supportsNavigationProjection(OfficialVehicle? vehicle) =>
      vehicle?.supportsNavigationProjection == true;
  bool _supportsCamera(OfficialVehicle? vehicle) =>
      vehicle?.supportsCamera == true;
  bool _supportsSmartMeter(OfficialVehicle? vehicle) =>
      vehicle?.supportsSmartMeter == true;
  bool _supportsChargingStation(OfficialVehicle? vehicle) =>
      vehicle?.supportsChargingStation == true;
}

// ── Official Control Lower Area ───────────────────────────────────
