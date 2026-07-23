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
          title: '车辆位置服务',
          subtitle: '优先显示官方停车位置；无坐标时显示“暂无位置”。可点刷新重新同步。',
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
                color: _locationElevatedShadow,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(Lucide.vehicle, color: color, size: AppIconSizes.md),
        ),
        Icon(Lucide.chevronDown, color: color, size: AppIconSizes.lg),
      ],
    );
  }
}
