import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/vehicle_profile.dart';
import '../services/location_service.dart';
import '../services/vehicle_store.dart';
import '../widgets/app_chrome.dart';

const _pageBg = Color(0xFFF5F6FA);
const _primary = Color(0xFF1E88E5);
const _textPrimary = Color(0xFF1A1A2E);
const _textTertiary = Color(0xFF999999);

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  bool _loading = false;
  String? _error;

  Future<void> _refreshLocation(VehicleProfile vehicle) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await LocationService().recordVehicleLocation(
        vehicle.id,
        requestPermission: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('位置已更新'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _copyLocation(VehicleLocation location) async {
    await Clipboard.setData(ClipboardData(text: location.coordinateText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('坐标已复制'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _openMap(VehicleLocation location) async {
    final query = '${location.latitude},${location.longitude}';
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开地图')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: StreamBuilder<List<VehicleProfile>>(
          stream: VehicleStore().vehiclesStream,
          initialData: VehicleStore().vehicles,
          builder: (context, snapshot) {
            final vehicle = VehicleStore().defaultVehicle;
            final location = vehicle?.lastLocation;
            return Column(
              children: [
                AppPageHeader(
                  title: '车辆位置',
                  actions: [
                    IconButton(
                      tooltip: '刷新位置',
                      onPressed: vehicle == null || _loading
                          ? null
                          : () => _refreshLocation(vehicle),
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      _MapPanel(location: location),
                      const SizedBox(height: 14),
                      _LocationDetailCard(
                        vehicle: vehicle,
                        location: location,
                        error: _error,
                        loading: _loading,
                        onRefresh: vehicle == null
                            ? null
                            : () => _refreshLocation(vehicle),
                        onCopy: location == null
                            ? null
                            : () => _copyLocation(location),
                        onOpenMap: location == null
                            ? null
                            : () => _openMap(location),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MapPanel extends StatelessWidget {
  final VehicleLocation? location;
  const _MapPanel({required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
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
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GridMapPainter(hasLocation: location != null),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  location == null ? Icons.map_outlined : Icons.location_on,
                  size: 64,
                  color: location == null ? Colors.grey.shade300 : _primary,
                ),
                const SizedBox(height: 10),
                Text(
                  location == null ? '等待定位数据' : '已记录最后位置',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: location == null ? _textTertiary : _textPrimary,
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

class _LocationDetailCard extends StatelessWidget {
  final VehicleProfile? vehicle;
  final VehicleLocation? location;
  final String? error;
  final bool loading;
  final VoidCallback? onRefresh;
  final VoidCallback? onCopy;
  final VoidCallback? onOpenMap;

  const _LocationDetailCard({
    required this.vehicle,
    required this.location,
    required this.error,
    required this.loading,
    required this.onRefresh,
    required this.onCopy,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final title = vehicle?.displayName ?? '未绑定车辆';
    final subtitle = location == null
        ? '暂无位置记录'
        : '${location!.coordinateText}  ·  精度约 ${location!.accuracy.toStringAsFixed(0)}m';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on, color: _primary, size: 22),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (location != null) ...[
            const SizedBox(height: 12),
            Text(
              '记录时间：${_formatDate(location!.recordedAt)}',
              style: const TextStyle(fontSize: 12, color: _textTertiary),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: TextStyle(fontSize: 12, color: Colors.red.shade400),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: loading ? null : onRefresh,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(location == null ? '获取位置' : '刷新位置'),
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

  String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _GridMapPainter extends CustomPainter {
  final bool hasLocation;
  const _GridMapPainter({required this.hasLocation});

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
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      bgPaint,
    );

    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (double x = 24; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 22; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    if (!hasLocation) return;
    final center = Offset(size.width / 2, size.height / 2 - 12);
    final radiusPaint = Paint()
      ..color = _primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 72, radiusPaint);
    canvas.drawCircle(center, 42, radiusPaint);
  }

  @override
  bool shouldRepaint(_GridMapPainter oldDelegate) =>
      oldDelegate.hasLocation != hasLocation;
}
