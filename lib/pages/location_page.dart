import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart'; // P0-6: service locator getters

import '../config/map_tile_config.dart';
import '../models/official_vehicle.dart';
import '../models/vehicle_profile.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../services/replica_feature_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/cached_tile_provider.dart';

part 'location_map_tab.dart';
part 'location_travel_tab.dart';
part 'location_fence_tab.dart';

enum LocationInitialTab { map, travel, fence }

const _officialPressedBg = Color(0xFFE5E5E5);

class LocationPage extends StatefulWidget {
  final LocationInitialTab initialTab;

  /// When hosted as a bottom-nav tab there is no route to pop back to, so the
  /// header back button is hidden. Pushed instances keep the default back arrow.
  final bool embedded;

  const LocationPage({
    super.key,
    this.initialTab = LocationInitialTab.map,
    this.embedded = false,
  });

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  late int _tabIndex;
  bool _localLoading = false;
  String? _localError;
  FenceConfig? _localFence;

  late final StreamSubscription<List<VehicleProfile>> _vehiclesSub;
  late final StreamSubscription<OfficialCloudState> _cloudStateSub;
  // P0-5: 用 ValueNotifier 驱动需要刷新的子树，避免空 setState 重建含 FlutterMap 的整页
  late final ValueNotifier<OfficialCloudState> _cloudStateNotifier;
  late final ValueNotifier<List<VehicleProfile>> _vehiclesNotifier;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab.index;
    _loadLocalFence();

    // P0-5: 流回调只更新 ValueNotifier，不调 setState，避免 FlutterMap 重建
    _cloudStateNotifier = ValueNotifier(officialCloudService.state);
    _vehiclesNotifier = ValueNotifier(vehicleStore.vehicles);
    _vehiclesSub = vehicleStore.vehiclesStream.listen((v) {
      if (mounted) _vehiclesNotifier.value = v;
    });
    _cloudStateSub = officialCloudService.stateStream.listen((c) {
      if (mounted) _cloudStateNotifier.value = c;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshOfficial(silent: true);
    });
  }

  @override
  void dispose() {
    _vehiclesSub.cancel();
    _cloudStateSub.cancel();
    _cloudStateNotifier.dispose();
    _vehiclesNotifier.dispose();
    super.dispose();
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
      await locationService.recordVehicleLocation(
        vehicle.id,
        requestPermission: true,
      );
      if (!mounted) return;
      _showSnack('本地位置已更新');
    } catch (e) {
      logService.operation(
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
    final service = officialCloudService;
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
      logService.operation(
        '官云地图数据刷新失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (!silent && mounted) setState(() => _localError = _errorMessage(e));
    }
  }

  Future<void> _refreshTravelHistory({String? month}) async {
    try {
      await officialCloudService.refreshTravelHistory(month: month);
    } catch (e) {
      logService.operation(
        '官云行程历史刷新失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (mounted) _showSnack(_errorMessage(e), isError: true);
    }
  }

  Future<void> _changeTravelMonth(int delta) async {
    final state = officialCloudService.state;
    final current = _parseMonth(state.travelMonth) ?? DateTime.now();
    final next = DateTime(current.year, current.month + delta);
    await _refreshTravelHistory(month: _monthText(next));
  }

  Future<void> _refreshFenceData() async {
    try {
      await officialCloudService.refreshFenceData();
    } catch (e) {
      logService.operation(
        '官云电子围栏刷新失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (mounted) _showSnack(_errorMessage(e), isError: true);
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
    if (!launched && mounted) _showSnack('无法打开地图', isError: true);
  }

  Future<void> _openTravelDetail(OfficialTravelRecord record) async {
    final travelId = record.deviceTravelId;
    if (travelId.isEmpty) {
      _showSnack('当前轨迹缺少官方 ID', isError: true);
      return;
    }
    try {
      if (!officialCloudService.state.travelDetails.containsKey(travelId)) {
        await officialCloudService.refreshTravelDetail(travelId);
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _TravelDetailSheet(record: record),
      );
    } catch (e) {
      logService.operation(
        '官云行程详情加载失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (mounted) _showSnack(_errorMessage(e), isError: true);
    }
  }

  String _errorMessage(Object e) {
    if (e is OfficialCloudApiException) return e.message;
    return e.toString();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppSnack.error(context, message);
    } else {
      AppSnack.info(context, message);
    }
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
        // P0-5: 用 ValueListenableBuilder 替代 Builder + 直接读取，
        // 仅在 cloudState/vehicles 变化时重建依赖子树，FlutterMap 被 RepaintBoundary 隔离
        child: ValueListenableBuilder<OfficialCloudState>(
          valueListenable: _cloudStateNotifier,
          builder: (context, cloudState, _) {
            return ValueListenableBuilder<List<VehicleProfile>>(
              valueListenable: _vehiclesNotifier,
              builder: (context, vehicles, _) {
                final localVehicle = vehicleStore.defaultVehicle;
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
                        showBack: !widget.embedded,
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
                          // P0-5: RepaintBoundary 隔离 FlutterMap，避免父级 rebuild 时地图重绘
                          RepaintBoundary(
                            child: _MapTab(
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
                    size: AppIconSizes.sm,
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

class _OfficialTabButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final Widget child;

  const _OfficialTabButton({
    required this.active,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : Colors.transparent;
    return AppPressable(
      onTap: onTap,
      pressedScale: 0.97,
      background: color,
      pressedBackground: active ? AppColors.primary : _officialPressedBg,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: SizedBox(height: 38, child: child),
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

    final radius = fullBleed ? 0.0 : AppRadii.card;
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
                          size: compact ? AppIconSizes.xl : 58,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '等待定位数据',
                          style: AppTextStyles.bodyLarge.copyWith(
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
    final hasLocation = location != null;
    final addressText = !hasLocation
        ? (signedIn ? '官方车辆暂无坐标' : '暂无位置记录')
        : location!.address.isNotEmpty
        ? location!.address
        : location!.coordinateText;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 头部:teal 图标 + 车名 + 地址 + GPS 状态 tag ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: AppColors.primary,
                  size: AppIconSizes.lg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      addressText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(height: 1.35),
                    ),
                    if (hasLocation) ...[
                      const SizedBox(height: 8),
                      _LocationStatusTag(source: location!.source),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (hasLocation) ...[
            const SizedBox(height: 16),
            // ── 三个数据格:来源 / 时间 / 精度（全部真实字段）──
            Row(
              children: [
                Expanded(
                  child: _LocationMetaBox(
                    value: location!.source,
                    label: '定位来源',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LocationMetaBox(
                    value: location!.timeLabel.isEmpty
                        ? '待读取'
                        : location!.timeLabel,
                    label: '最近更新',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LocationMetaBox(
                    value: location!.accuracy > 0
                        ? '±${location!.accuracy.toStringAsFixed(0)}m'
                        : '—',
                    label: '定位精度',
                  ),
                ),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
          const SizedBox(height: 16),
          // ── 操作:刷新（ghost）+ 复制 + 导航（深色 primary）──
          Row(
            children: [
              Expanded(
                child: _LocationActionButton(
                  icon: Icons.my_location,
                  label: '刷新',
                  loading: loading,
                  onTap: loading ? null : onRefresh,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LocationActionButton(
                  icon: Icons.copy_outlined,
                  label: '复制',
                  onTap: onCopy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LocationActionButton(
                  icon: Icons.navigation_outlined,
                  label: '导航',
                  primary: true,
                  onTap: onOpenMap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// v8 定位状态 tag：teal 圆点 + 来源文案。
class _LocationStatusTag extends StatelessWidget {
  final String source;

  const _LocationStatusTag({required this.source});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            source,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// v8 数据格：大号数值 + 小标签，浅灰底圆角。
class _LocationMetaBox extends StatelessWidget {
  final String value;
  final String label;

  const _LocationMetaBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// v8 定位操作按钮：ghost（浅底）/ primary（深墨）两态。
class _LocationActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final bool loading;
  final VoidCallback? onTap;

  const _LocationActionButton({
    required this.icon,
    required this.label,
    this.primary = false,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = primary ? AppColors.dark : AppColors.surfaceContainerLow;
    final fg = primary ? Colors.white : AppColors.textPrimary;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: primary
                ? null
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                else
                  Icon(icon, size: AppIconSizes.sm, color: fg),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
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
          SizedBox(width: 76, child: Text(label, style: AppTextStyles.caption)),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTextStyles.valueText,
            ),
          ),
        ],
      ),
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
          const Icon(
            Icons.location_on_outlined,
            color: AppColors.primary,
            size: AppIconSizes.sm,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${location.source} · ${location.coordinateText}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.smallText.copyWith(
                fontWeight: FontWeight.w700,
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
          const Icon(
            Icons.lock_outline,
            color: AppColors.info,
            size: AppIconSizes.sm,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyLarge),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.smallText),
              ],
            ),
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
