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

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  void _showUnavailable(BuildContext context, String label) {
    AppSnack.info(context, '$label暂未开放');
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
            final showBleRenewal = _supportsBleRenewal(vehicle);
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
                      subtitle: '记录车辆周围环境',
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
                      onTap: () => _open(context, const OfficialCloudPage()),
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
                    onShare: () => _open(context, const ShareBikePage()),
                  ),
                  const SizedBox(height: 10),
                  _OfficialImageBanner(
                    asset:
                        'assets/official_tailg/iv_add_sound_effects_set_qgj.webp',
                    semanticsLabel: 'QGJ音效设置',
                    onTap: () => _open(context, const QgjSoundEffectsPage()),
                  ),
                  const SizedBox(height: 10),
                  _OfficialNfcCard(
                    onTap: () => _open(context, const NfcKeyPage()),
                  ),
                  if (showBleRenewal) ...[
                    const SizedBox(height: 10),
                    _OfficialSimpleServiceCard(
                      title: '蓝牙续费',
                      subtitle: '充值后智能控车',
                      icon: Icons.bluetooth_connected,
                      onTap: () => _open(context, const OfficialCloudPage()),
                    ),
                  ],
                  if (showChargingStation) ...[
                    const SizedBox(height: 10),
                    _OfficialSimpleServiceCard(
                      title: '台铃充电站',
                      subtitle: '查看附近可用充电站',
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
    final cloudLat = cloudLocation?.latitude;
    final cloudLng = cloudLocation?.longitude;
    if (cloudLat != null &&
        cloudLng != null &&
        !isZeroCoordinate(cloudLat, cloudLng, tolerance: 0.000001)) {
      return _LocationSummary(
        latitude: cloudLat,
        longitude: cloudLng,
        timeLabel: cloudLocation!.bleConnectTime.trim(),
        address: cloudLocation.bleConnectAddress.trim(),
        source: '官方停车位置',
      );
    }
    if (cloudLocation?.hasData == true) {
      return _LocationSummary(
        latitude: null,
        longitude: null,
        timeLabel: cloudLocation!.bleConnectTime.trim(),
        address: cloudLocation.bleConnectAddress.trim(),
        source: '官方停车位置',
      );
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
        timeLabel: _formatLocationDate(local.recordedAt),
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
  bool _supportsBleRenewal(OfficialVehicle? vehicle) =>
      vehicle?.supportsBleRenewal == true;
  bool _supportsChargingStation(OfficialVehicle? vehicle) =>
      vehicle?.supportsChargingStation == true;
}

// ── Official Control Lower Area ───────────────────────────────────

class _OfficialCardSurface extends StatelessWidget {
  const _OfficialCardSurface({
    required this.child,
    this.height,
    this.onTap,
    this.semanticLabel,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double? height;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F1F1F).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    if (onTap == null) return card;
    return AppPressable(
      onTap: onTap,
      haptic: false,
      semanticsLabel: semanticLabel,
      semanticsButton: true,
      semanticsEnabled: true,
      child: card,
    );
  }
}

class _OfficialMapCard extends StatelessWidget {
  const _OfficialMapCard({required this.location, required this.onTap});

  final _LocationSummary? location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OfficialCardSurface(
      height: 238,
      onTap: onTap,
      semanticLabel: '车辆定位',
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '车辆定位',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              _OfficialArrow(),
            ],
          ),
          const SizedBox(height: 10),
          _OfficialLocationMeta(location: location),
          const SizedBox(height: 10),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/official_tailg/iv_control_map_bg.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFE7E8EF),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.map_outlined,
                        color: AppColors.officialTextMuted,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(color: const Color(0x0F000000)),
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.location_on,
                    size: 34,
                    color: AppColors.brandRed,
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

class _OfficialLocationMeta extends StatelessWidget {
  const _OfficialLocationMeta({required this.location});

  final _LocationSummary? location;

  @override
  Widget build(BuildContext context) {
    final hasLocation = location != null;
    final time = location?.timeLabel.trim() ?? '';
    final address = location?.displayText.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          time.isEmpty
              ? hasLocation
                    ? '定位时间待读取'
                    : '暂无定位时间'
              : time,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.officialTextMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          address.isEmpty ? '暂无车辆定位' : address,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LocationSummary {
  const _LocationSummary({
    required this.latitude,
    required this.longitude,
    required this.timeLabel,
    required this.address,
    required this.source,
  });

  final double? latitude;
  final double? longitude;
  final String timeLabel;
  final String address;
  final String source;

  String get coordinateText {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return '';
    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  String get displayText {
    final trimmedAddress = address.trim();
    if (trimmedAddress.isNotEmpty) return trimmedAddress;
    final coordinates = coordinateText;
    if (coordinates.isNotEmpty) return coordinates;
    return '';
  }
}

String _formatLocationDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

class _OfficialNavigationProjectionCard extends StatelessWidget {
  const _OfficialNavigationProjectionCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OfficialCardSurface(
      height: 132,
      onTap: onTap,
      semanticLabel: '导航投屏',
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Container(
            width: 76,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.officialPageBg,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: const Icon(
              Icons.screen_share_outlined,
              color: AppColors.brandRed,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  '导航投屏',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '调节仪表显示连接二维码，扫码投屏导航',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.officialTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _OfficialArrow(),
        ],
      ),
    );
  }
}

class _OfficialSmartMeterCard extends StatelessWidget {
  const _OfficialSmartMeterCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OfficialCardSurface(
      height: 172,
      onTap: onTap,
      semanticLabel: '智能仪表',
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  '智能仪表',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _OfficialArrow(),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              _MeterStatusChip('权限检测'),
              SizedBox(width: 8),
              _MeterStatusChip('WiFi'),
              SizedBox(width: 8),
              _MeterStatusChip('蓝牙'),
            ],
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.officialPageBg,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: const Text(
              '地图导航设置',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.officialTextMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeterStatusChip extends StatelessWidget {
  const _MeterStatusChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.officialPageBg,
          borderRadius: BorderRadius.circular(AppRadii.tile),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.officialTextMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _OfficialSimpleServiceCard extends StatelessWidget {
  const _OfficialSimpleServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OfficialCardSurface(
      height: 100,
      onTap: onTap,
      semanticLabel: title,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 76,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.officialPageBg,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, color: AppColors.brandRed),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.officialTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const _OfficialArrow(),
        ],
      ),
    );
  }
}

class _OfficialHistoryCard extends StatelessWidget {
  const _OfficialHistoryCard({required this.todayCount, required this.onTap});

  final int todayCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OfficialCardSurface(
      height: 100,
      onTap: onTap,
      semanticLabel: '历史轨迹',
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 84,
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD7B3).withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Image.asset(
              'assets/official_tailg/iv_control_histroy_bg.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.route_outlined, color: AppColors.brandRed),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: Text(
                        '历史轨迹',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _OfficialArrow(),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '今日骑行记录',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.officialTextMuted,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      todayCount.toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF060606),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      '条',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.officialTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialGpsBanner extends StatelessWidget {
  const _OfficialGpsBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OfficialImageBanner(
      asset: 'assets/official_tailg/iv_add_intelligence_control.png',
      semanticsLabel: '可添加GPS',
      onTap: onTap,
      fallback: _GpsFallback(),
    );
  }
}

class _OfficialImageBanner extends StatelessWidget {
  const _OfficialImageBanner({
    required this.asset,
    required this.semanticsLabel,
    required this.onTap,
    this.fallback,
  });

  final String asset;
  final String semanticsLabel;
  final VoidCallback onTap;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      haptic: false,
      semanticsLabel: semanticsLabel,
      semanticsButton: true,
      semanticsEnabled: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Image.asset(
          asset,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          errorBuilder: (_, __, ___) =>
              fallback ??
              Container(
                height: 100,
                color: AppColors.surface,
                alignment: Alignment.center,
                child: Text(semanticsLabel),
              ),
        ),
      ),
    );
  }
}

class _GpsFallback extends StatelessWidget {
  const _GpsFallback();

  @override
  Widget build(BuildContext context) {
    return _OfficialCardSurface(
      height: 132,
      padding: const EdgeInsets.only(left: 130, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text(
            '可添加GPS',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '可定位 防盗通知 远程控车等',
            style: TextStyle(fontSize: 14, color: AppColors.officialTextMuted),
          ),
        ],
      ),
    );
  }
}

class _OfficialSettingsCard extends StatelessWidget {
  const _OfficialSettingsCard({
    required this.onVehicleSetting,
    required this.onFence,
    required this.onShare,
  });

  final VoidCallback onVehicleSetting;
  final VoidCallback onFence;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return _OfficialCardSurface(
      height: 158,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '功能设置',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _OfficialSettingAction(
                    asset: 'assets/official_tailg/iv_control_setting_set.png',
                    label: '车辆设置',
                    onTap: onVehicleSetting,
                  ),
                ),
                Expanded(
                  child: _OfficialSettingAction(
                    asset: 'assets/official_tailg/iv_control_setting_el.png',
                    label: '电子围栏',
                    onTap: onFence,
                  ),
                ),
                Expanded(
                  child: _OfficialSettingAction(
                    asset: 'assets/official_tailg/iv_control_setting_share.png',
                    label: '分享用车',
                    onTap: onShare,
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

class _OfficialSettingAction extends StatelessWidget {
  const _OfficialSettingAction({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      haptic: false,
      semanticsLabel: label,
      semanticsButton: true,
      semanticsEnabled: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            asset,
            width: 38,
            height: 38,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.settings_outlined, color: AppColors.brandRed),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.officialTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialNfcCard extends StatelessWidget {
  const _OfficialNfcCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OfficialCardSurface(
      height: 132,
      onTap: onTap,
      semanticLabel: 'NFC钥匙',
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Image.asset(
            'assets/official_tailg/ic_control_nfc.png',
            width: 88,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.nfc, size: 46, color: AppColors.brandRed),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: const [
                    Expanded(
                      child: Text(
                        'NFC钥匙',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _OfficialArrow(),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  '刷卡骑行新体验',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.officialTextMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: const [_NfcNote('手机如何添加'), _NfcNote('智能手表如何添加')],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NfcNote extends StatelessWidget {
  const _NfcNote(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEEFF),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0xFF1F1DF1)),
      ),
    );
  }
}

class _OfficialArrow extends StatelessWidget {
  const _OfficialArrow();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/official_tailg/ic_right_go.png',
      width: 14,
      height: 14,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.chevron_right,
        size: 18,
        color: AppColors.officialTextMuted,
      ),
    );
  }
}
