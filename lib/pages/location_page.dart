import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/map_tile_config.dart';
import '../models/official_vehicle.dart';
import '../models/vehicle_profile.dart';
import '../services/location_service.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../services/replica_feature_store.dart';
import '../services/vehicle_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/cached_tile_provider.dart';

enum LocationInitialTab { map, travel, fence }

const _officialPressedBg = Color(0xFFE5E5E5);

class LocationPage extends StatefulWidget {
  final LocationInitialTab initialTab;

  const LocationPage({super.key, this.initialTab = LocationInitialTab.map});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  late int _tabIndex;
  bool _localLoading = false;
  String? _localError;
  FenceConfig? _localFence;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab.index;
    _loadLocalFence();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshOfficial(silent: true);
    });
  }

  Future<void> _loadLocalFence() async {
    final config = await ReplicaFeatureStore().loadFenceConfig();
    if (!mounted) return;
    setState(() => _localFence = config);
  }

  Future<void> _refreshLocalLocation(VehicleProfile vehicle) async {
    if (_localLoading) return;
    setState(() {
      _localLoading = true;
      _localError = null;
    });
    try {
      await LocationService().recordVehicleLocation(
        vehicle.id,
        requestPermission: true,
      );
      if (!mounted) return;
      _showSnack('本地位置已更新');
    } catch (e) {
      LogService().operation(
        '本地车辆位置刷新失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (mounted) setState(() => _localError = _errorMessage(e));
    } finally {
      if (mounted) setState(() => _localLoading = false);
    }
  }

  Future<void> _refreshOfficial({bool silent = false}) async {
    final service = OfficialCloudService();
    if (!service.state.signedIn) return;
    try {
      await service.refreshVehicles(
        silent: silent,
        refreshReplicaDetails: false,
      );
      await Future.wait([
        service.refreshVehicleLocation(silent: silent),
        service.refreshFenceData(silent: silent),
        service.refreshTravelHistory(silent: silent),
      ]);
      if (!silent && mounted) _showSnack('官方地图数据已刷新');
    } catch (e) {
      LogService().operation(
        '官云地图数据刷新失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (!silent && mounted) setState(() => _localError = _errorMessage(e));
    }
  }

  Future<void> _refreshTravelHistory({String? month}) async {
    try {
      await OfficialCloudService().refreshTravelHistory(month: month);
    } catch (e) {
      LogService().operation(
        '官云行程历史刷新失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (mounted) _showSnack(_errorMessage(e));
    }
  }

  Future<void> _changeTravelMonth(int delta) async {
    final state = OfficialCloudService().state;
    final current = _parseMonth(state.travelMonth) ?? DateTime.now();
    final next = DateTime(current.year, current.month + delta);
    await _refreshTravelHistory(month: _monthText(next));
  }

  Future<void> _refreshFenceData() async {
    try {
      await OfficialCloudService().refreshFenceData();
    } catch (e) {
      LogService().operation(
        '官云电子围栏刷新失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (mounted) _showSnack(_errorMessage(e));
    }
  }

  Future<void> _refreshAll(VehicleProfile? localVehicle) async {
    if (localVehicle != null && _tabIndex == LocationInitialTab.map.index) {
      await _refreshLocalLocation(localVehicle);
    }
    await _refreshOfficial();
  }

  Future<void> _copyLocation(_ResolvedLocation location) async {
    await Clipboard.setData(ClipboardData(text: location.coordinateText));
    _showSnack('坐标已复制');
  }

  Future<void> _openMap(_ResolvedLocation location) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${location.latitude},${location.longitude}',
    });
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) _showSnack('无法打开地图');
  }

  Future<void> _openTravelDetail(OfficialTravelRecord record) async {
    final travelId = record.deviceTravelId;
    if (travelId.isEmpty) {
      _showSnack('当前轨迹缺少官方 ID');
      return;
    }
    try {
      if (!OfficialCloudService().state.travelDetails.containsKey(travelId)) {
        await OfficialCloudService().refreshTravelDetail(travelId);
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _TravelDetailSheet(record: record),
      );
    } catch (e) {
      LogService().operation(
        '官云行程详情加载失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (mounted) _showSnack(_errorMessage(e));
    }
  }

  String _errorMessage(Object e) {
    if (e is OfficialCloudApiException) return e.message;
    return e.toString();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  _ResolvedLocation? _resolveLocation({
    required VehicleProfile? localVehicle,
    required OfficialCloudState cloudState,
  }) {
    final officialVehicle = cloudState.selectedVehicle;
    final cloudLocation = cloudState.vehicleLocation;
    final cloudLat = cloudLocation?.latitude;
    final cloudLng = cloudLocation?.longitude;
    if (cloudLat != null && cloudLng != null && !_isZero(cloudLat, cloudLng)) {
      return _ResolvedLocation(
        latitude: cloudLat,
        longitude: cloudLng,
        accuracy: 0,
        timeLabel: cloudLocation!.bleConnectTime,
        address: cloudLocation.bleConnectAddress,
        source: '官方停车位置',
      );
    }

    final vehicleLat = double.tryParse(officialVehicle?.latitude ?? '');
    final vehicleLng = double.tryParse(officialVehicle?.longitude ?? '');
    if (vehicleLat != null &&
        vehicleLng != null &&
        !_isZero(vehicleLat, vehicleLng)) {
      return _ResolvedLocation(
        latitude: vehicleLat,
        longitude: vehicleLng,
        accuracy: 0,
        timeLabel: '',
        address: '',
        source: '官方车辆状态',
      );
    }

    final local = localVehicle?.lastLocation;
    if (local != null) {
      return _ResolvedLocation(
        latitude: local.latitude,
        longitude: local.longitude,
        accuracy: local.accuracy,
        timeLabel: _formatDate(local.recordedAt),
        address: '',
        source: '本地记录',
      );
    }
    return null;
  }

  bool _isZero(double latitude, double longitude) =>
      latitude == 0 && longitude == 0;

  @override
  Widget build(BuildContext context) {
    final title = switch (_tabIndex) {
      0 => '地图/轨迹/围栏',
      1 => '历史轨迹',
      _ => '电子围栏',
    };
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: StreamBuilder<List<VehicleProfile>>(
          stream: VehicleStore().vehiclesStream,
          initialData: VehicleStore().vehicles,
          builder: (context, snapshot) {
            return StreamBuilder<OfficialCloudState>(
              stream: OfficialCloudService().stateStream,
              initialData: OfficialCloudService().state,
              builder: (context, cloudSnapshot) {
                final cloudState =
                    cloudSnapshot.data ?? OfficialCloudService().state;
                final localVehicle = VehicleStore().defaultVehicle;
                final cloudVehicle = cloudState.signedIn
                    ? cloudState.selectedVehicle
                    : null;
                final location = _resolveLocation(
                  localVehicle: localVehicle,
                  cloudState: cloudState,
                );
                final loading =
                    _localLoading ||
                    cloudState.loading ||
                    cloudState.vehicleLocationLoading ||
                    cloudState.travelLoading ||
                    cloudState.fenceLoading;

                return Column(
                  children: [
                    if (_tabIndex != LocationInitialTab.fence.index)
                      AppPageHeader(
                        title: title,
                        actions: [
                          AppHeaderAction(
                            icon: Icons.refresh,
                            tooltip: '刷新地图数据',
                            onTap: loading
                                ? null
                                : () => _refreshAll(localVehicle),
                          ),
                        ],
                      ),
                    if (_tabIndex != LocationInitialTab.fence.index)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: _SegmentedTabs(
                          index: _tabIndex,
                          onChanged: (value) =>
                              setState(() => _tabIndex = value),
                        ),
                      ),
                    Expanded(
                      child: IndexedStack(
                        index: _tabIndex,
                        children: [
                          _MapTab(
                            vehicleName:
                                localVehicle?.displayName ??
                                cloudVehicle?.displayName,
                            location: location,
                            cloudState: cloudState,
                            error: _localError,
                            loading: loading,
                            onRefresh: () => _refreshAll(localVehicle),
                            onCopy: location == null
                                ? null
                                : () => _copyLocation(location),
                            onOpenMap: location == null
                                ? null
                                : () => _openMap(location),
                          ),
                          _TravelTab(
                            cloudState: cloudState,
                            onRefresh: () => _refreshTravelHistory(),
                            onChangeMonth: _changeTravelMonth,
                            onOpenDetail: _openTravelDetail,
                          ),
                          _FenceTab(
                            cloudState: cloudState,
                            location: location,
                            localFence: _localFence,
                            onRefresh: _refreshFenceData,
                            onTabChanged: (value) =>
                                setState(() => _tabIndex = value),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _SegmentedTabs({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = [
      _TabItem(Icons.location_on_outlined, '位置'),
      _TabItem(Icons.route_outlined, '轨迹'),
      _TabItem(Icons.radar_outlined, '围栏'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.elevation1,
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final active = index == i;
          final item = items[i];
          return Expanded(
            child: _OfficialTabButton(
              active: active,
              onTap: () => onChanged(i),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    size: 17,
                    color: active ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _OfficialTabButton extends StatefulWidget {
  final bool active;
  final VoidCallback onTap;
  final Widget child;

  const _OfficialTabButton({
    required this.active,
    required this.onTap,
    required this.child,
  });

  @override
  State<_OfficialTabButton> createState() => _OfficialTabButtonState();
}

class _OfficialTabButtonState extends State<_OfficialTabButton> {
  static const _motionDuration = Duration(milliseconds: 150);
  static const _motionCurve = Curves.easeOutCubic;

  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? AppColors.primary
        : _pressed
        ? _officialPressedBg
        : Colors.transparent;
    return AnimatedScale(
      duration: _motionDuration,
      curve: _motionCurve,
      scale: _pressed ? 0.97 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ReplicaRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.05),
          onTap: () {
            _setPressed(false);
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          borderRadius: BorderRadius.circular(ReplicaRadii.card),
          child: AnimatedContainer(
            duration: _motionDuration,
            curve: _motionCurve,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(ReplicaRadii.card),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _FloatingSegmentedTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _FloatingSegmentedTabs({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SegmentedTabs(index: index, onChanged: onChanged);
  }
}

class _MapTab extends StatelessWidget {
  final String? vehicleName;
  final _ResolvedLocation? location;
  final OfficialCloudState cloudState;
  final String? error;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback? onCopy;
  final VoidCallback? onOpenMap;

  const _MapTab({
    required this.vehicleName,
    required this.location,
    required this.cloudState,
    required this.error,
    required this.loading,
    required this.onRefresh,
    required this.onCopy,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        _MapPanel(
          location: location,
          fence: cloudState.fenceData,
          points: _latestPoints(cloudState),
        ),
        const SizedBox(height: 14),
        _LocationDetailCard(
          vehicleName: vehicleName,
          location: location,
          error: error ?? cloudState.vehicleLocationError,
          loading: loading,
          signedIn: cloudState.signedIn,
          onRefresh: onRefresh,
          onCopy: onCopy,
          onOpenMap: onOpenMap,
        ),
        const SizedBox(height: 14),
        _ReadOnlyNotice(
          title: '官方地图复刻边界',
          subtitle:
              '已接入官方车辆状态和停车位置只读数据，并用 flutter_map 显示真实瓦片地图。未配置天地图 Token 时默认使用 OSM 瓦片兜底。',
        ),
      ],
    );
  }

  List<OfficialTravelPoint> _latestPoints(OfficialCloudState state) {
    for (final day in state.travelDays) {
      for (final record in day.records) {
        final points = state.travelDetails[record.deviceTravelId];
        if (points != null && points.isNotEmpty) return points;
      }
    }
    return const [];
  }
}

class _TravelTab extends StatelessWidget {
  final OfficialCloudState cloudState;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int delta) onChangeMonth;
  final ValueChanged<OfficialTravelRecord> onOpenDetail;

  const _TravelTab({
    required this.cloudState,
    required this.onRefresh,
    required this.onChangeMonth,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final records = [for (final day in cloudState.travelDays) ...day.records];
    final dateGroups = cloudState.travelDays
        .where((day) => day.records.isNotEmpty || day.hasData)
        .toList(growable: false);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          _TravelMonthSelector(
            month: cloudState.travelMonth.isEmpty
                ? '本月轨迹'
                : cloudState.travelMonth,
            onPreviousMonth: cloudState.travelLoading
                ? null
                : () => onChangeMonth(-1),
            onNextMonth: cloudState.travelLoading
                ? null
                : () => onChangeMonth(1),
          ),
          const SizedBox(height: 14),
          if (cloudState.travelLoading)
            const _LoadingCard(text: '正在读取官方历史轨迹')
          else if (!cloudState.signedIn)
            const _EmptyCard(
              icon: Icons.cloud_off,
              title: '未登录官方账号',
              subtitle: '登录后才能读取官方历史轨迹。',
            )
          else if (cloudState.travelError != null)
            _EmptyCard(
              icon: Icons.info_outline,
              title: '历史轨迹暂不可用',
              subtitle: cloudState.travelError!,
            )
          else if (records.isEmpty)
            const _EmptyCard(
              icon: Icons.route_outlined,
              title: '暂无轨迹记录',
              subtitle: '官方接口当前月份未返回骑行轨迹。',
            )
          else
            ...dateGroups.map(
              (day) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TravelDayCard(
                  day: day,
                  detailPointCounts: cloudState.travelDetails.map(
                    (key, value) => MapEntry(key, value.length),
                  ),
                  loading: cloudState.travelDetailLoading,
                  onOpenDetail: onOpenDetail,
                ),
              ),
            ),
          const SizedBox(height: 4),
          const _ReadOnlyNotice(
            title: '轨迹只读',
            subtitle:
                '官方删除轨迹、轨迹纠偏上报等写接口未开放。当前只读取 `deviceTravel` 与 `deviceTravelDetail` 的列表和轨迹点。',
          ),
        ],
      ),
    );
  }
}

class _FenceTab extends StatelessWidget {
  final OfficialCloudState cloudState;
  final _ResolvedLocation? location;
  final FenceConfig? localFence;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onTabChanged;

  const _FenceTab({
    required this.cloudState,
    required this.location,
    required this.localFence,
    required this.onRefresh,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        Positioned.fill(
          child: _MapPanel(
            location: location,
            fence: cloudState.fenceData,
            points: const [],
            compact: false,
            fullBleed: true,
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          top: 4 + topPadding * 0.2,
          child: SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.88),
                    ),
                    tooltip: '返回',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(ReplicaRadii.pill),
                  ),
                  child: const Text(
                    '电子围栏',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: 62 + topPadding * 0.2,
          child: _FloatingSegmentedTabs(index: 2, onChanged: onTabChanged),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _OfficialFenceSheet(
            fence: cloudState.fenceData,
            localFence: localFence,
            error: cloudState.fenceError,
            loading: cloudState.fenceLoading,
            signedIn: cloudState.signedIn,
            bottomPadding: bottomPadding,
            onRefresh: onRefresh,
          ),
        ),
      ],
    );
  }
}

class _MapPanel extends StatelessWidget {
  final _ResolvedLocation? location;
  final OfficialFenceData? fence;
  final List<OfficialTravelPoint> points;
  final bool compact;
  final bool fullBleed;

  const _MapPanel({
    required this.location,
    required this.fence,
    required this.points,
    this.compact = false,
    this.fullBleed = false,
  });

  @override
  Widget build(BuildContext context) {
    final mapPoints = _mapPoints(location, points);
    final center = _mapCenter(location, mapPoints);
    final cameraFit = mapPoints.length >= 2
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(mapPoints),
            padding: const EdgeInsets.all(48),
            maxZoom: 17,
          )
        : null;

    final radius = fullBleed ? 0.0 : ReplicaRadii.card;
    return Container(
      height: fullBleed ? null : (compact ? 260 : 340),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: fullBleed ? null : AppShadows.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: compact ? 15.5 : 16,
                initialCameraFit: cameraFit,
                minZoom: 3,
                maxZoom: 18,
                backgroundColor: const Color(0xFFE9EEF3),
              ),
              children: [
                TileLayer(
                  urlTemplate: MapTileConfig.baseUrlTemplate,
                  subdomains: MapTileConfig.subdomains,
                  userAgentPackageName: 'de.tttq.tailg_ble_app',
                  maxNativeZoom: 18,
                  tileProvider: CachedTileProvider(),
                  tileDisplay: const TileDisplay.instantaneous(),
                ),
                if (MapTileConfig.annotationUrlTemplate != null)
                  TileLayer(
                    urlTemplate: MapTileConfig.annotationUrlTemplate,
                    subdomains: MapTileConfig.subdomains,
                    userAgentPackageName: 'de.tttq.tailg_ble_app',
                    maxNativeZoom: 18,
                    tileProvider: CachedTileProvider(),
                    tileDisplay: const TileDisplay.instantaneous(),
                  ),
                if (fence?.hasData == true && location != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: center,
                        radius: fence!.radiusMeters ?? 300,
                        useRadiusInMeter: true,
                        color:
                            (fence!.enabled
                                    ? AppColors.success
                                    : AppColors.warning)
                                .withValues(alpha: 0.12),
                        borderColor:
                            (fence!.enabled
                                    ? AppColors.success
                                    : AppColors.warning)
                                .withValues(alpha: 0.55),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                if (mapPoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: mapPoints,
                        strokeWidth: 5,
                        color: AppColors.success,
                        borderStrokeWidth: 3,
                        borderColor: Colors.white.withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (location != null)
                      Marker(
                        point: center,
                        width: 48,
                        height: 58,
                        alignment: Alignment.topCenter,
                        child: _MapMarker(
                          color: fence?.enabled == false
                              ? AppColors.warning
                              : AppColors.primary,
                        ),
                      ),
                    if (mapPoints.length >= 2) ...[
                      Marker(
                        point: mapPoints.first,
                        width: 34,
                        height: 34,
                        child: const _TrackNodeMarker(
                          label: '起',
                          color: AppColors.success,
                        ),
                      ),
                      Marker(
                        point: mapPoints.last,
                        width: 34,
                        height: 34,
                        child: const _TrackNodeMarker(
                          label: '终',
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (location == null && points.isEmpty)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.76),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: compact ? 48 : 58,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '等待定位数据',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 14,
              top: 14,
              child: _MapChip(
                icon: Icons.layers_outlined,
                label: points.length >= 2
                    ? '${MapTileConfig.providerLabel} · 轨迹'
                    : '${MapTileConfig.providerLabel} · 位置',
              ),
            ),
            if (fence?.hasData == true)
              Positioned(
                right: 14,
                top: 14,
                child: _MapChip(
                  icon: Icons.radar_outlined,
                  label: fence!.statusLabel,
                ),
              ),
            if (location != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: _MapCaption(location: location!),
              ),
          ],
        ),
      ),
    );
  }

  static List<LatLng> _mapPoints(
    _ResolvedLocation? location,
    List<OfficialTravelPoint> points,
  ) {
    final result = <LatLng>[];
    for (final point in points) {
      final latitude = point.latitude;
      final longitude = point.longitude;
      if (latitude == null || longitude == null) continue;
      if (latitude == 0 && longitude == 0) continue;
      result.add(LatLng(latitude, longitude));
    }
    if (result.isEmpty && location != null) {
      result.add(LatLng(location.latitude, location.longitude));
    }
    return result;
  }

  static LatLng _mapCenter(_ResolvedLocation? location, List<LatLng> points) {
    if (location != null) return LatLng(location.latitude, location.longitude);
    if (points.isNotEmpty) return points.first;
    return const LatLng(39.9042, 116.4074);
  }
}

class _LocationDetailCard extends StatelessWidget {
  final String? vehicleName;
  final _ResolvedLocation? location;
  final String? error;
  final bool loading;
  final bool signedIn;
  final VoidCallback onRefresh;
  final VoidCallback? onCopy;
  final VoidCallback? onOpenMap;

  const _LocationDetailCard({
    required this.vehicleName,
    required this.location,
    required this.error,
    required this.loading,
    required this.signedIn,
    required this.onRefresh,
    required this.onCopy,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final title = vehicleName ?? '未绑定车辆';
    final subtitle = location == null
        ? signedIn
              ? '官方车辆暂无坐标'
              : '暂无位置记录'
        : location!.accuracy > 0
        ? '${location!.coordinateText}  ·  精度约 ${location!.accuracy.toStringAsFixed(0)}m'
        : location!.coordinateText;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CircleIcon(icon: Icons.location_on, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (location != null) ...[
            const SizedBox(height: 12),
            _InfoRow('来源', location!.source),
            _InfoRow(
              '时间',
              location!.timeLabel.isEmpty ? '待读取' : location!.timeLabel,
            ),
            _InfoRow(
              '地址',
              location!.address.isEmpty ? '待读取' : location!.address,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: loading ? null : onRefresh,
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 18),
                  label: const Text('刷新位置'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: '复制坐标',
                onPressed: onCopy,
                icon: const Icon(Icons.copy, size: 18),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: '打开地图',
                onPressed: onOpenMap,
                icon: const Icon(Icons.open_in_new, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TravelMonthSelector extends StatelessWidget {
  final String month;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;

  const _TravelMonthSelector({
    required this.month,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: cardDecoration,
      child: Row(
        children: [
          IconButton(
            tooltip: '上个月',
            onPressed: onPreviousMonth,
            icon: const Icon(Icons.chevron_left, size: 20),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    month,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.textTertiary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '下个月',
            onPressed: onNextMonth,
            icon: const Icon(Icons.chevron_right, size: 20),
          ),
        ],
      ),
    );
  }
}

class _TravelDayCard extends StatelessWidget {
  final OfficialTravelDay day;
  final Map<String, int> detailPointCounts;
  final bool loading;
  final ValueChanged<OfficialTravelRecord> onOpenDetail;

  const _TravelDayCard({
    required this.day,
    required this.detailPointCounts,
    required this.loading,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final records = day.records;
    final mileage = day.totalMileage.isNotEmpty
        ? day.totalMileage
        : _sumMileage(records);
    final duration = day.totalTime.isNotEmpty
        ? day.totalTime
        : _sumDuration(records);
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day.travelDate.isEmpty ? '官方轨迹' : day.travelDate,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 75,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(ReplicaRadii.card),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    label: '总次数',
                    value: '${records.length}',
                    unit: '次',
                  ),
                ),
                const VerticalDivider(width: 1, color: Colors.white),
                Expanded(
                  child: _SummaryValue(
                    label: '总里程',
                    value: mileage.isEmpty ? '--' : mileage,
                    unit: mileage.isEmpty ? '' : 'km',
                  ),
                ),
                const VerticalDivider(width: 1, color: Colors.white),
                Expanded(
                  child: _SummaryValue(
                    label: '总时长',
                    value: duration.isEmpty ? '--' : duration,
                    unit: '',
                  ),
                ),
              ],
            ),
          ),
          if (records.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...records.map(
              (record) => _TravelRecordCard(
                record: record,
                pointCount: detailPointCounts[record.deviceTravelId],
                loading: loading,
                onTap: () => onOpenDetail(record),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _sumMileage(List<OfficialTravelRecord> records) {
    final total = records.fold<double>(
      0,
      (sum, record) => sum + (double.tryParse(record.mileage) ?? 0),
    );
    return total == 0 ? '' : total.toStringAsFixed(1);
  }

  static String _sumDuration(List<OfficialTravelRecord> records) {
    var seconds = 0;
    for (final record in records) {
      seconds += (int.tryParse(record.hours) ?? 0) * 3600;
      seconds += (int.tryParse(record.min) ?? 0) * 60;
      seconds += int.tryParse(record.sec) ?? 0;
    }
    if (seconds <= 0) return '';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h${minutes}m';
    return '${minutes}m';
  }
}

class _TravelRecordCard extends StatefulWidget {
  final OfficialTravelRecord record;
  final int? pointCount;
  final bool loading;
  final VoidCallback onTap;

  const _TravelRecordCard({
    required this.record,
    required this.pointCount,
    required this.loading,
    required this.onTap,
  });

  @override
  State<_TravelRecordCard> createState() => _TravelRecordCardState();
}

class _TravelRecordCardState extends State<_TravelRecordCard> {
  static const _motionDuration = Duration(milliseconds: 150);
  static const _motionCurve = Curves.easeOutCubic;

  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final interactive = !widget.loading;
    return AnimatedScale(
      duration: _motionDuration,
      curve: _motionCurve,
      scale: _pressed ? 0.985 : 1,
      child: AnimatedContainer(
        duration: _motionDuration,
        curve: _motionCurve,
        decoration: BoxDecoration(
          color: _pressed ? _officialPressedBg : AppColors.surface,
          borderRadius: BorderRadius.circular(ReplicaRadii.card),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(ReplicaRadii.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            splashColor: AppColors.primary.withValues(alpha: 0.06),
            highlightColor: Colors.black.withValues(alpha: 0.025),
            onTap: interactive
                ? () {
                    _setPressed(false);
                    HapticFeedback.selectionClick();
                    widget.onTap();
                  }
                : null,
            onTapDown: interactive ? (_) => _setPressed(true) : null,
            onTapUp: interactive ? (_) => _setPressed(false) : null,
            onTapCancel: interactive ? () => _setPressed(false) : null,
            borderRadius: BorderRadius.circular(ReplicaRadii.card),
            child: SizedBox(
              height: 86,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 76,
                    child: _TrackTimeRail(record: widget.record),
                  ),
                  Container(
                    width: 1,
                    height: 46,
                    color: AppColors.outlineVariant,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.record.mileageLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.record.averageSpeedLabel}  ·  ${widget.record.durationLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      widget.pointCount == null
                          ? '点击读取'
                          : '${widget.pointCount} 点',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackTimeRail extends StatelessWidget {
  final OfficialTravelRecord record;

  const _TrackTimeRail({required this.record});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          left: 7,
          top: 29,
          bottom: 29,
          child: VerticalDivider(
            width: 1,
            thickness: 1,
            color: AppColors.outlineVariant,
          ),
        ),
        Positioned(
          left: 0,
          top: 20,
          child: _TimelineDot(color: AppColors.success),
        ),
        Positioned(
          left: 0,
          bottom: 20,
          child: _TimelineDot(color: AppColors.warning),
        ),
        Positioned(
          left: 20,
          top: 15,
          child: Text(
            record.startTime.isEmpty ? '--' : record.startTime,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ),
        Positioned(
          left: 20,
          bottom: 15,
          child: Text(
            record.endTime.isEmpty ? '--' : record.endTime,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _TimelineDot extends StatelessWidget {
  final Color color;

  const _TimelineDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

class _TravelDetailSheet extends StatelessWidget {
  final OfficialTravelRecord record;

  const _TravelDetailSheet({required this.record});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OfficialCloudState>(
      stream: OfficialCloudService().stateStream,
      initialData: OfficialCloudService().state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? OfficialCloudService().state;
        final points = state.travelDetails[record.deviceTravelId] ?? const [];
        final firstPoint = _firstResolvedPoint(points);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          decoration: const BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.travelDate.isEmpty ? '轨迹详情' : record.travelDate,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    _MapPanel(
                      location: firstPoint,
                      fence: null,
                      points: points,
                      compact: true,
                    ),
                    const SizedBox(height: 14),
                    _TrackDetailStats(
                      record: record,
                      pointCount: points.length,
                    ),
                    const SizedBox(height: 14),
                    _TrackStartEndCard(
                      record: record,
                      firstPoint: firstPoint,
                      lastPoint: _lastResolvedPoint(points),
                    ),
                    const SizedBox(height: 14),
                    if (points.isEmpty)
                      const _EmptyCard(
                        icon: Icons.route_outlined,
                        title: '未返回轨迹点',
                        subtitle: '官方详情接口未返回可绘制坐标。',
                      )
                    else
                      ...points
                          .take(12)
                          .map((point) => _PointRow(point: point)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static _ResolvedLocation? _firstResolvedPoint(
    List<OfficialTravelPoint> points,
  ) {
    for (final point in points) {
      final latitude = point.latitude;
      final longitude = point.longitude;
      if (latitude == null || longitude == null) continue;
      if (latitude == 0 && longitude == 0) continue;
      return _ResolvedLocation(
        latitude: latitude,
        longitude: longitude,
        accuracy: 0,
        timeLabel: point.reportTime,
        address: '',
        source: '轨迹起点',
      );
    }
    return null;
  }

  static _ResolvedLocation? _lastResolvedPoint(
    List<OfficialTravelPoint> points,
  ) {
    for (final point in points.reversed) {
      final latitude = point.latitude;
      final longitude = point.longitude;
      if (latitude == null || longitude == null) continue;
      if (latitude == 0 && longitude == 0) continue;
      return _ResolvedLocation(
        latitude: latitude,
        longitude: longitude,
        accuracy: 0,
        timeLabel: point.reportTime,
        address: '',
        source: '轨迹终点',
      );
    }
    return null;
  }
}

class _TrackDetailStats extends StatelessWidget {
  final OfficialTravelRecord record;
  final int pointCount;

  const _TrackDetailStats({required this.record, required this.pointCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: cardDecoration,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DetailMetric(label: '里程', value: record.mileageLabel),
              ),
              Expanded(
                child: _DetailMetric(label: '时长', value: record.durationLabel),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _DetailMetric(label: '极速', value: record.maxSpeedLabel),
              ),
              Expanded(
                child: _DetailMetric(
                  label: '均速',
                  value: record.averageSpeedLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoRow('轨迹点', '$pointCount'),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final String label;
  final String value;

  const _DetailMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TrackStartEndCard extends StatelessWidget {
  final OfficialTravelRecord record;
  final _ResolvedLocation? firstPoint;
  final _ResolvedLocation? lastPoint;

  const _TrackStartEndCard({
    required this.record,
    required this.firstPoint,
    required this.lastPoint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: cardDecoration,
      child: Column(
        children: [
          _TrackEndpointRow(
            color: AppColors.success,
            title: _endpointTitle(firstPoint, '起点'),
            time: record.startTime.isEmpty ? '--' : record.startTime,
          ),
          Container(
            height: 42,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 7),
            child: Container(width: 1, color: AppColors.outlineVariant),
          ),
          _TrackEndpointRow(
            color: AppColors.warning,
            title: _endpointTitle(lastPoint, '终点'),
            time: record.endTime.isEmpty ? '--' : record.endTime,
          ),
        ],
      ),
    );
  }

  static String _endpointTitle(_ResolvedLocation? location, String fallback) {
    if (location == null) return fallback;
    return location.coordinateText;
  }
}

class _TrackEndpointRow extends StatelessWidget {
  final Color color;
  final String title;
  final String time;

  const _TrackEndpointRow({
    required this.color,
    required this.title,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TimelineDot(color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          time,
          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _OfficialFenceSheet extends StatelessWidget {
  final OfficialFenceData? fence;
  final FenceConfig? localFence;
  final String? error;
  final bool loading;
  final bool signedIn;
  final double bottomPadding;
  final Future<void> Function() onRefresh;

  const _OfficialFenceSheet({
    required this.fence,
    required this.localFence,
    required this.error,
    required this.loading,
    required this.signedIn,
    required this.bottomPadding,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = fence?.enabled ?? localFence?.enabled ?? false;
    final radius = fence?.radiusMeters ?? localFence?.radiusMeters.toDouble();
    final minRadius = _radiusMeters(fence?.fenceRadiusMin) ?? 100;
    final maxRadius = _radiusMeters(fence?.fenceRadiusMax) ?? 10000;
    final progress = radius == null
        ? 0.0
        : ((radius - minRadius) / (maxRadius - minRadius)).clamp(0.0, 1.0);
    final time = fence?.timeLabel ?? '待读取';
    final source = fence?.hasData == true
        ? '官方围栏配置只读展示'
        : signedIn
        ? '官方围栏暂未返回配置'
        : '登录后读取官方围栏';

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomPadding),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ReplicaRadii.sheet),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '围栏设置',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.help_outline,
                size: 18,
                color: AppColors.textTertiary,
              ),
              const Spacer(),
              Material(
                color: AppColors.surface,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: '刷新围栏',
                  onPressed: loading ? null : onRefresh,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _FenceSettingRow(
            title: '电子围栏',
            subtitle: source,
            trailing: _FenceSwitchPill(enabled: enabled),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(ReplicaRadii.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '范围设置',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      radius == null ? '待读取' : _formatDistance(radius),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(ReplicaRadii.pill),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: progress,
                    backgroundColor: AppColors.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      enabled ? AppColors.primary : AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _formatDistance(minRadius),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDistance(maxRadius),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: AppColors.outlineVariant),
                _FenceSettingRow(
                  title: '时间设置',
                  subtitle: time,
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                  dense: true,
                ),
              ],
            ),
          ),
          if (localFence != null && fence?.hasData != true) ...[
            const SizedBox(height: 8),
            Text(
              '本地围栏：${localFence!.enabled ? '已开启' : '已关闭'} · ${localFence!.radiusMeters}m',
              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(ReplicaRadii.card),
              ),
              child: const Center(
                child: Text(
                  '保存',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static double? _radiusMeters(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null) return null;
    return parsed * 100;
  }

  // Show large fence radii in km (e.g. 10000m -> 10km) so the range labels
  // stay readable; keep metres below 1km.
  static String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      final fixed = km.toStringAsFixed(1);
      final trimmed = fixed.endsWith('.0')
          ? fixed.substring(0, fixed.length - 2)
          : fixed;
      return '${trimmed}km';
    }
    return '${meters.toStringAsFixed(0)}m';
  }
}

class _FenceSettingRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  final bool dense;

  const _FenceSettingRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: dense ? 44 : 56),
      padding: EdgeInsets.symmetric(horizontal: dense ? 0 : 16),
      decoration: dense
          ? null
          : BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(ReplicaRadii.card),
            ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class _FenceSwitchPill extends StatelessWidget {
  final bool enabled;

  const _FenceSwitchPill({required this.enabled});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.success : AppColors.textTertiary;
    return Container(
      width: 52,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: enabled ? 0.22 : 0.16),
        borderRadius: BorderRadius.circular(ReplicaRadii.pill),
      ),
      child: Align(
        alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
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

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _SummaryValue({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            children: [
              TextSpan(
                text: unit,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _PointRow extends StatelessWidget {
  final OfficialTravelPoint point;

  const _PointRow({required this.point});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration,
      child: Row(
        children: [
          const Icon(Icons.trip_origin, color: AppColors.info, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${point.lat}, ${point.lng}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            point.reportTime.isEmpty ? '--' : point.reportTime,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _CircleIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _MapChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MapChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final Color color;

  const _MapMarker({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(Icons.two_wheeler, color: color, size: 20),
        ),
        Icon(Icons.arrow_drop_down, color: color, size: 24),
      ],
    );
  }
}

class _TrackNodeMarker extends StatelessWidget {
  final String label;
  final Color color;

  const _TrackNodeMarker({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MapCaption extends StatelessWidget {
  final _ResolvedLocation location;

  const _MapCaption({required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${location.source} · ${location.coordinateText}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ReadOnlyNotice({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

class _LoadingCard extends StatelessWidget {
  final String text;

  const _LoadingCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration,
      child: Column(
        children: [
          const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration,
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.textTertiary),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _ResolvedLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final String timeLabel;
  final String address;
  final String source;

  const _ResolvedLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timeLabel,
    required this.address,
    required this.source,
  });

  String get coordinateText =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

class _TabItem {
  final IconData icon;
  final String label;

  const _TabItem(this.icon, this.label);
}

String _formatDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

DateTime? _parseMonth(String value) {
  final parts = value.trim().split('-');
  if (parts.length != 2) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return null;
  return DateTime(year, month);
}

String _monthText(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}';
