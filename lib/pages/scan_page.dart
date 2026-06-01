import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../ble/constants.dart';
import '../main.dart';
import '../models/vehicle_profile.dart';
import '../services/permission_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snack.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  List<ScanResult> _results = [];
  bool _scanning = false;
  String? _connectingRemoteId;
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
    final result = await AppPermissionService().requestBleScanPermissions();
    if (!result.granted && mounted) {
      AppSnack.error(context, result.message ?? '请授予蓝牙和定位权限后再扫描');
    }
    return result.granted;
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
    await FlutterBluePlus.startScan(timeout: BleTimings.manualScanTimeout);
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    if (_connectingRemoteId != null) return;
    setState(() => _connectingRemoteId = device.remoteId.toString());
    _stopScan();
    if (!mounted) return;
    AppSnack.info(context, '正在连接 ${device.platformName}...');
    try {
      VehicleProfile? existingProfile;
      for (final vehicle in vehicleStore.vehicles) {
        if (vehicle.id == device.remoteId.toString()) {
          existingProfile = vehicle;
          break;
        }
      }
      applyVehicleBleCredentials(existingProfile);
      await connectionManager.connect(device);
      final profile = await vehicleStore.upsert(
        id: device.remoteId.toString(),
        name: device.platformName,
        protocol: vehicleProtocolFromBle(connectionManager.protocol),
        makeDefault: true,
        lastConnectedAt: DateTime.now(),
      );
      applyVehicleBleCredentials(profile);
      unawaited(locationService.recordVehicleLocation(profile.id));
      if (mounted) {
        AppSnack.success(context, '连接成功，已绑定为默认车辆');
      }
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, '连接失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _connectingRemoteId = null);
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
          backgroundColor: AppColors.pageBg,
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
                                color: AppColors.textPrimary,
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
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '请确保蓝牙已开启且靠近车辆',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _DeviceList(
                        results: _results,
                        connectingRemoteId: _connectingRemoteId,
                        onTap: _connectDevice,
                      ),
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
        boxShadow: AppShadows.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
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
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
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
      ..color = AppColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, 30, ringPaint);
    canvas.drawCircle(center, 55, ringPaint);
    canvas.drawCircle(center, 80, ringPaint);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - 1.05,
        endAngle: sweepAngle,
        colors: [Colors.transparent, AppColors.primary.withValues(alpha: 0.15)],
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
  final String? connectingRemoteId;
  final void Function(BluetoothDevice) onTap;
  const _DeviceList({
    required this.results,
    required this.connectingRemoteId,
    required this.onTap,
  });

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
        final remoteId = r.device.remoteId.toString();
        final connecting = connectingRemoteId == remoteId;
        final disabled = connectingRemoteId != null && !connecting;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _DeviceCard(
            result: r,
            connecting: connecting,
            disabled: disabled,
            onTap: () => onTap(r.device),
          ),
        );
      },
    );
  }
}

class _DeviceCard extends StatefulWidget {
  final ScanResult result;
  final bool connecting;
  final bool disabled;
  final VoidCallback onTap;
  const _DeviceCard({
    required this.result,
    required this.connecting,
    required this.disabled,
    required this.onTap,
  });

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

    final interactive = !widget.disabled && !widget.connecting;

    return GestureDetector(
      onTapDown: interactive ? (_) => setState(() => _pressed = true) : null,
      onTapUp: interactive ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: interactive ? () => setState(() => _pressed = false) : null,
      onTap: interactive ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.disabled ? const Color(0xFFF8F8F8) : Colors.white,
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
                  color: isTailg ? AppColors.primary : const Color(0xFF9E9E9E),
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
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.result.device.remoteId.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.connecting)
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '连接中',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SignalBars(strength: strength),
                    const SizedBox(height: 6),
                    Text(
                      widget.disabled ? '等待' : '连接绑定',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
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
            color: i < activeCount ? activeColor : AppColors.border,
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
              : AppColors.primary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: !enabled
                  ? Colors.black.withValues(alpha: 0.08)
                  : scanning
                  ? Colors.black.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.35),
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
