import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/official_vehicle.dart';
import '../models/vehicle_profile.dart';
import '../services/location_service.dart';
import '../services/official_cloud_service.dart';
import '../services/replica_feature_store.dart';
import '../services/vehicle_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';

enum LocationInitialTab { map, travel, fence }

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
      _showSnack('本地位置已更新');
    } catch (e) {
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
      if (!silent) _showSnack('官方地图数据已刷新');
    } catch (e) {
      if (!silent && mounted) setState(() => _localError = _errorMessage(e));
    }
  }

  Future<void> _refreshTravelHistory({String? month}) async {
    try {
      await OfficialCloudService().refreshTravelHistory(month: month);
    } catch (e) {
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
                    AppPageHeader(
                      title: '地图/轨迹/围栏',
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: _SegmentedTabs(
                        index: _tabIndex,
                        onChanged: (value) => setState(() => _tabIndex = value),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final active = index == i;
          final item = items[i];
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 38,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
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
            ),
          );
        }),
      ),
    );
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
              '已接入官方车辆状态和停车位置只读数据，并保留本地定位兜底。当前未嵌入高德地图 SDK，地图区域使用轻量预览和外部地图打开。',
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
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          _TravelSummaryCard(
            cloudState: cloudState,
            records: records,
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
            ...records.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TravelRecordCard(
                  record: record,
                  pointCount:
                      cloudState.travelDetails[record.deviceTravelId]?.length,
                  loading: cloudState.travelDetailLoading,
                  onTap: () => onOpenDetail(record),
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

  const _FenceTab({
    required this.cloudState,
    required this.location,
    required this.localFence,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          _MapPanel(
            location: location,
            fence: cloudState.fenceData,
            points: const [],
            compact: true,
          ),
          const SizedBox(height: 14),
          _FenceStatusCard(
            fence: cloudState.fenceData,
            localFence: localFence,
            error: cloudState.fenceError,
            loading: cloudState.fenceLoading,
            signedIn: cloudState.signedIn,
          ),
          const SizedBox(height: 14),
          const _ReadOnlyNotice(
            title: '围栏写入暂禁用',
            subtitle:
                '已复刻官方围栏开关、半径、时间段的只读展示。`updFenceData` 和 `fenceConfig` 会修改服务端配置，未做真机回滚验证前不开放。',
          ),
        ],
      ),
    );
  }
}

class _MapPanel extends StatelessWidget {
  final _ResolvedLocation? location;
  final OfficialFenceData? fence;
  final List<OfficialTravelPoint> points;
  final bool compact;

  const _MapPanel({
    required this.location,
    required this.fence,
    required this.points,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 260 : 340,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GridMapPainter(
                  hasLocation: location != null,
                  hasFence: fence?.hasData == true,
                  pointCount: points.length,
                ),
              ),
            ),
            if (points.length >= 2)
              Positioned.fill(
                child: CustomPaint(
                  painter: _TrackPreviewPainter(points: points),
                ),
              ),
            if (fence?.hasData == true)
              Positioned.fill(
                child: CustomPaint(
                  painter: _FencePreviewPainter(enabled: fence!.enabled),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    location == null ? Icons.map_outlined : Icons.location_on,
                    size: compact ? 48 : 58,
                    color: location == null
                        ? Colors.grey.shade300
                        : AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    location == null ? '等待定位数据' : location!.source,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: location == null
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (location != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      location!.coordinateText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 14,
              top: 14,
              child: _MapChip(
                icon: Icons.layers_outlined,
                label: points.length >= 2 ? '轨迹预览' : '位置预览',
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
          ],
        ),
      ),
    );
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

class _TravelSummaryCard extends StatelessWidget {
  final OfficialCloudState cloudState;
  final List<OfficialTravelRecord> records;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;

  const _TravelSummaryCard({
    required this.cloudState,
    required this.records,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final mileage = records.fold<double>(0, (sum, record) {
      return sum + (double.tryParse(record.mileage) ?? 0);
    });
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CircleIcon(icon: Icons.route_outlined, color: AppColors.info),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cloudState.travelMonth.isEmpty
                      ? '本月轨迹'
                      : cloudState.travelMonth,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: '上个月',
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left, size: 18),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: '下个月',
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  label: '轨迹次数',
                  value: '${records.length}',
                  unit: '次',
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  label: '累计里程',
                  value: mileage == 0 ? '--' : mileage.toStringAsFixed(1),
                  unit: 'km',
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  label: '天数',
                  value: '${cloudState.travelDays.length}',
                  unit: '天',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TravelRecordCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.travelDate.isEmpty ? '官方轨迹' : record.travelDate,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${record.startTime.isEmpty ? '--' : record.startTime} - ${record.endTime.isEmpty ? '--' : record.endTime}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _MiniMetric('里程', record.mileageLabel)),
                  Expanded(child: _MiniMetric('均速', record.averageSpeedLabel)),
                  Expanded(
                    child: _MiniMetric(
                      '轨迹点',
                      pointCount == null ? '点击读取' : '$pointCount',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    _MapPanel(
                      location: points.isEmpty
                          ? null
                          : _ResolvedLocation(
                              latitude: points.first.latitude!,
                              longitude: points.first.longitude!,
                              accuracy: 0,
                              timeLabel: points.first.reportTime,
                              address: '',
                              source: '轨迹起点',
                            ),
                      fence: null,
                      points: points,
                      compact: true,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: cardDecoration,
                      child: Column(
                        children: [
                          _InfoRow('轨迹点', '${points.length}'),
                          _InfoRow('里程', record.mileageLabel),
                          _InfoRow('均速', record.averageSpeedLabel),
                          _InfoRow('最高速度', record.maxSpeedLabel),
                          _InfoRow('用时', record.durationLabel),
                        ],
                      ),
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
}

class _FenceStatusCard extends StatelessWidget {
  final OfficialFenceData? fence;
  final FenceConfig? localFence;
  final String? error;
  final bool loading;
  final bool signedIn;

  const _FenceStatusCard({
    required this.fence,
    required this.localFence,
    required this.error,
    required this.loading,
    required this.signedIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CircleIcon(
                icon: Icons.radar_outlined,
                color: fence?.enabled == true
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fence == null ? '官方电子围栏' : fence!.statusLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      signedIn ? '官方围栏配置只读展示' : '登录后读取官方围栏',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow('官方半径', fence?.radiusLabel ?? '待读取'),
          _InfoRow('时间段', fence?.timeLabel ?? '待读取'),
          _InfoRow('最小半径', _radiusValue(fence?.fenceRadiusMin)),
          _InfoRow('最大半径', _radiusValue(fence?.fenceRadiusMax)),
          if (localFence != null) ...[
            const Divider(height: 24, color: AppColors.border),
            _InfoRow('本地围栏', localFence!.enabled ? '已开启' : '已关闭'),
            _InfoRow('本地半径', '${localFence!.radiusMeters}m'),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }

  static String _radiusValue(String? value) {
    if (value == null || value.isEmpty) return '待读取';
    final parsed = double.tryParse(value);
    if (parsed == null) return value;
    return '${(parsed * 100).toStringAsFixed(0)}m';
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

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
      ],
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

class _ReadOnlyNotice extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ReadOnlyNotice({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
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

class _GridMapPainter extends CustomPainter {
  final bool hasLocation;
  final bool hasFence;
  final int pointCount;

  const _GridMapPainter({
    required this.hasLocation,
    required this.hasFence,
    required this.pointCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: hasLocation
            ? const [Color(0xFFE3F2FD), Color(0xFFF7FAFF)]
            : const [Color(0xFFF7F8FA), Color(0xFFFFFFFF)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (double x = 20; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 20; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final roadPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.72)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.62,
        size.width * 0.30,
        size.height * 0.28,
        size.width * 0.58,
        size.height * 0.34,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.38,
        size.width * 0.72,
        size.height * 0.70,
        size.width * 0.94,
        size.height * 0.62,
      );
    canvas.drawPath(path, roadPaint);

    if (!hasLocation && pointCount == 0 && !hasFence) return;
    final center = Offset(size.width / 2, size.height / 2 - 10);
    final radiusPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 76, radiusPaint);
    canvas.drawCircle(center, 42, radiusPaint);
  }

  @override
  bool shouldRepaint(_GridMapPainter oldDelegate) =>
      oldDelegate.hasLocation != hasLocation ||
      oldDelegate.hasFence != hasFence ||
      oldDelegate.pointCount != pointCount;
}

class _TrackPreviewPainter extends CustomPainter {
  final List<OfficialTravelPoint> points;

  const _TrackPreviewPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path();
    final count = math.min(points.length, 36);
    for (var i = 0; i < count; i++) {
      final t = count == 1 ? 0.0 : i / (count - 1);
      final x = size.width * (0.12 + 0.76 * t);
      final y =
          size.height * (0.66 - math.sin(t * math.pi * 1.4) * 0.26 + t * 0.06);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final shadow = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final line = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, shadow);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_TrackPreviewPainter oldDelegate) =>
      oldDelegate.points.length != points.length;
}

class _FencePreviewPainter extends CustomPainter {
  final bool enabled;

  const _FencePreviewPainter({required this.enabled});

  @override
  void paint(Canvas canvas, Size size) {
    final color = enabled ? AppColors.success : AppColors.warning;
    final center = Offset(size.width / 2, size.height / 2 - 10);
    final fill = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, math.min(size.width, size.height) * 0.34, fill);
    canvas.drawCircle(center, math.min(size.width, size.height) * 0.34, stroke);
  }

  @override
  bool shouldRepaint(_FencePreviewPainter oldDelegate) =>
      oldDelegate.enabled != enabled;
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
