part of 'location_page.dart';

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
          child: Icon(Icons.two_wheeler, color: color, size: AppIconSizes.md),
        ),
        Icon(Icons.arrow_drop_down, color: color, size: AppIconSizes.lg),
      ],
    );
  }
}
