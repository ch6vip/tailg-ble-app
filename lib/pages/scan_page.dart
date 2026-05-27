import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../theme/app_colors.dart';

const _pageBg = Color(0xFFF5F6FA);
const _primary = Color(0xFF1E88E5);
const _primaryDark = Color(0xFF1565C0);
const _textPrimary = Color(0xFF1A1A2E);
const _textTertiary = Color(0xFF999999);

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  List<ScanResult> _results = [];
  bool _scanning = false;
  StreamSubscription? _scanResultsSub;
  StreamSubscription? _isScanSub;
  Timer? _throttle;
  late AnimationController _radarController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      if (_throttle?.isActive ?? false) return;
      _throttle = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _results = results);
      });
    });
    _isScanSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!mounted) return;
      setState(() => _scanning = scanning);
      if (scanning) {
        _radarController.repeat();
      } else {
        _radarController.stop();
      }
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _throttle?.cancel();
    _scanResultsSub?.cancel();
    _isScanSub?.cancel();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    final blocked = statuses.values.any(
      (s) => s.isDenied || s.isPermanentlyDenied || s.isRestricted,
    );
    if (blocked && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请授予蓝牙和定位权限后再扫描')));
    }
    return !blocked;
  }

  Future<void> _startScan() async {
    if (!await _requestPermissions()) return;
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先开启蓝牙')));
      }
      return;
    }
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    _stopScan();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在连接 ${device.platformName}...'),
        duration: const Duration(seconds: 2),
      ),
    );
    try {
      await connectionManager.connect(device);
      final profile = await vehicleStore.upsert(
        id: device.remoteId.toString(),
        name: device.platformName,
        protocol: vehicleProtocolFromBle(connectionManager.protocol),
        makeDefault: true,
        lastConnectedAt: DateTime.now(),
      );
      unawaited(locationService.recordVehicleLocation(profile.id));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('连接成功，已绑定为默认车辆')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('连接失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<BluetoothAdapterState>(
      stream: FlutterBluePlus.adapterState,
      initialData: BluetoothAdapterState.unknown,
      builder: (context, adapterSnapshot) {
        final bluetoothOn = adapterSnapshot.data == BluetoothAdapterState.on;
        return Scaffold(
          backgroundColor: _pageBg,
          body: SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(
                    bottom: AppNav.contentBottomPadding,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: Row(
                          children: [
                            Text(
                              '搜索设备',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!bluetoothOn)
                        const _ScanHintCard(
                          icon: Icons.bluetooth_disabled,
                          title: '蓝牙未开启',
                          subtitle: '开启蓝牙后即可搜索附近车辆',
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 20),
                        child: _RadarWidget(animation: _radarController),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          children: [
                            Text(
                              !bluetoothOn
                                  ? '等待蓝牙开启'
                                  : _scanning
                                  ? '正在搜索附近设备...'
                                  : '点击下方按钮开始搜索',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '请确保蓝牙已开启且靠近车辆',
                              style: TextStyle(
                                fontSize: 12,
                                color: _textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _DeviceList(results: _results, onTap: _connectDevice),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _ScanFab(
                      scanning: _scanning,
                      enabled: bluetoothOn,
                      onTap: _scanning ? _stopScan : _startScan,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScanHintCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ScanHintCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: _textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarWidget extends StatelessWidget {
  final AnimationController animation;
  const _RadarWidget({required this.animation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _RadarPainter(sweepAngle: animation.value * 2 * pi),
            child: child,
          );
        },
        child: Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primary, _primaryDark],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.bluetooth_searching,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  _RadarPainter({required this.sweepAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..color = _primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, 30, ringPaint);
    canvas.drawCircle(center, 55, ringPaint);
    canvas.drawCircle(center, 80, ringPaint);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - 1.05,
        endAngle: sweepAngle,
        colors: [Colors.transparent, _primary.withValues(alpha: 0.15)],
        transform: GradientRotation(sweepAngle - 1.05),
      ).createShader(Rect.fromCircle(center: center, radius: 80));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 80),
      sweepAngle - 1.05,
      1.05,
      true,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.sweepAngle != sweepAngle;
}

class _DeviceList extends StatelessWidget {
  final List<ScanResult> results;
  final void Function(BluetoothDevice) onTap;
  const _DeviceList({required this.results, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final r = results[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _DeviceCard(result: r, onTap: () => onTap(r.device)),
        );
      },
    );
  }
}

class _DeviceCard extends StatefulWidget {
  final ScanResult result;
  final VoidCallback onTap;
  const _DeviceCard({required this.result, required this.onTap});

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.result.device.platformName.isNotEmpty
        ? widget.result.device.platformName
        : '未知设备';
    final isTailg =
        name.toLowerCase().contains('tl') ||
        name.toLowerCase().contains('tailg');
    final rssi = widget.result.rssi;
    final strength = rssi > -60
        ? _SignalStrength.strong
        : rssi > -80
        ? _SignalStrength.medium
        : _SignalStrength.weak;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0x0A000000),
                blurRadius: _pressed ? 4 : 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isTailg
                      ? const LinearGradient(
                          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                        )
                      : null,
                  color: isTailg ? null : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isTailg ? Icons.electric_bike : Icons.bluetooth,
                  size: 22,
                  color: isTailg ? _primary : const Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.result.device.remoteId.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textTertiary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SignalBars(strength: strength),
                  const SizedBox(height: 6),
                  const Text(
                    '连接绑定',
                    style: TextStyle(fontSize: 11, color: _textTertiary),
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

enum _SignalStrength { strong, medium, weak }

class _SignalBars extends StatelessWidget {
  final _SignalStrength strength;
  const _SignalBars({required this.strength});

  @override
  Widget build(BuildContext context) {
    final heights = [6.0, 10.0, 14.0, 20.0];
    final activeCount = switch (strength) {
      _SignalStrength.strong => 4,
      _SignalStrength.medium => 3,
      _SignalStrength.weak => 2,
    };
    final activeColor = strength == _SignalStrength.weak
        ? const Color(0xFFFF9800)
        : const Color(0xFF4CAF50);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        return Container(
          width: 4,
          height: heights[i],
          margin: EdgeInsets.only(left: i > 0 ? 2 : 0),
          decoration: BoxDecoration(
            color: i < activeCount ? activeColor : const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

class _ScanFab extends StatelessWidget {
  final bool scanning;
  final bool enabled;
  final VoidCallback onTap;
  const _ScanFab({
    required this.scanning,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: !enabled
              ? const Color(0xFFBDBDBD)
              : scanning
              ? const Color(0xFF757575)
              : _primary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: !enabled
                  ? Colors.black.withValues(alpha: 0.08)
                  : scanning
                  ? Colors.black.withValues(alpha: 0.15)
                  : _primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              scanning ? Icons.stop_rounded : Icons.bluetooth_searching,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              scanning ? '停止' : '扫描',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
