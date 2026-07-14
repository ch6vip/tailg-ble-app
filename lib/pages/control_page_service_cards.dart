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
    unawaited(_cloudStateSub.cancel());
    unawaited(_vehiclesSub.cancel());
    _cloudStateNotifier.dispose();
    _vehiclesNotifier.dispose();
    super.dispose();
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
          builder: (context, _, __) {
            final vehicle = cloudState.selectedVehicle;
            final localVehicle = vehicleStore.defaultVehicle;
            final location = _resolveLocationSummary(
              cloudState: cloudState,
              localVehicle: localVehicle,
            );
            final showGpsBanner =
                cloudState.selectedVehicle?.hasGpsService != true;
            final showNavigationProjection =
                vehicle?.supportsNavigationProjection == true;
            final showCamera = vehicle?.supportsCamera == true;
            final showSmartMeter = vehicle?.supportsSmartMeter == true;
            final showChargingStation =
                vehicle?.supportsChargingStation == true;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _OfficialMapCard(
                    location: location,
                    onTap: () =>
                        openCloudGatedPage(context, const LocationPage()),
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
                    todayCount: _todayTravelRecordCount(cloudState),
                    onTap: () => openCloudGatedPage(
                      context,
                      const LocationPage(initialTab: LocationInitialTab.travel),
                    ),
                  ),
                  if (showGpsBanner) ...[
                    const SizedBox(height: 10),
                    _OfficialGpsBanner(
                      onTap: () => openCloudGatedPage(
                        context,
                        const OfficialCloudPage(),
                        requireVehicle: false,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _OfficialSettingsCard(
                    onVehicleSetting: () => openCloudGatedPage(
                      context,
                      const VehicleSettingsPage(),
                    ),
                    onFence: () => openCloudGatedPage(
                      context,
                      const LocationPage(initialTab: LocationInitialTab.fence),
                    ),
                    onShare: () => _showUnavailable(context, '共享车辆'),
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

  /// Count of official travel records for "today" (local calendar day).
  /// Falls back to 0 when travel history has not been loaded yet.
  int _todayTravelRecordCount(OfficialCloudState cloudState) {
    final todayKey = formatDateText(DateTime.now());
    var total = 0;
    for (final day in cloudState.travelDays) {
      if (normalizeOfficialDateKey(day.travelDate) == todayKey) {
        total += day.records.length;
      }
    }
    return total;
  }

  _LocationSummary? _resolveLocationSummary({
    required OfficialCloudState cloudState,
    required VehicleProfile? localVehicle,
  }) {
    final resolved = resolveVehicleLocation(
      cloudState: cloudState,
      localVehicle: localVehicle,
      allowCloudMetadataWithoutCoordinate: true,
    );
    if (resolved == null) return null;
    return _LocationSummary(
      latitude: resolved.latitude,
      longitude: resolved.longitude,
      timeLabel: resolved.timeLabel,
      address: resolved.address,
      source: resolved.source,
    );
  }
}

// ── Official Control Lower Area ───────────────────────────────────
