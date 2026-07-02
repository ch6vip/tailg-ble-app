import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import '../ble/constants.dart';
import '../main.dart';
import '../services/ble_connection_snapshot_guard.dart';
import '../models/vehicle_profile.dart';
import '../services/log_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final _resultsNotifier = ValueNotifier<List<ScanResult>>(<ScanResult>[]);
  final _connectionSnapshotGuard = const BleConnectionSnapshotGuard();
  bool _scanning = false;
  String? _connectingRemoteId;
  StreamSubscription? _scanResultsSub;
  StreamSubscription? _isScanSub;
  Timer? _throttle;
  List<ScanResult>? _pendingResults;
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
      _pendingResults = results;
      if (_throttle?.isActive ?? false) return;
      _throttle = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final next = _pendingResults;
        _pendingResults = null;
        if (next != null) {
          _resultsNotifier.value = next;
        }
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
    _resultsNotifier.dispose();
    _scanResultsSub?.cancel();
    _isScanSub?.cancel();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    final result = await permissionService.requestBleScanPermissions();
    if (!mounted) return false;
    if (!result.granted) {
      AppSnack.error(context, result.message ?? '请授予蓝牙和定位权限后再扫描');
    }
    return result.granted;
  }

  Future<void> _startScan() async {
    if (!await _requestPermissions()) return;
    if (!mounted) return;
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (!mounted) return;
    if (adapterState != BluetoothAdapterState.on) {
      AppSnack.info(context, '请先开启蓝牙');
      return;
    }
    await FlutterBluePlus.startScan(timeout: BleTimings.manualScanTimeout);
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    if (_connectingRemoteId != null) return;
    final manager = connectionManager;
    final deviceId = device.remoteId.toString();
    setState(() => _connectingRemoteId = deviceId);
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
      await manager.connect(device);
      if (!_connectionSnapshotGuard.allowsReadyTarget(
        startManager: manager,
        currentManager: connectionManager,
        startDevice: device,
        currentDevice: manager.device,
        currentDeviceId: manager.device?.remoteId.toString(),
        expectedDeviceId: deviceId,
        currentState: manager.state,
      )) {
        logService.ble(
          '连接绑定设备跳过',
          detail: '目标设备已变化 device=$deviceId',
          level: LogLevel.warning,
        );
        return;
      }
      final profile = await vehicleStore.upsert(
        id: deviceId,
        name: device.platformName,
        protocol: vehicleProtocolFromBle(manager.protocol),
        makeDefault: true,
        lastConnectedAt: DateTime.now(),
      );
      applyVehicleBleCredentials(profile);
      unawaited(locationService.recordVehicleLocation(profile.id));
      if (mounted) {
        AppSnack.success(context, '连接成功，已绑定为默认车辆');
      }
    } catch (e) {
      logService.ble('连接绑定设备失败', detail: e.toString(), level: LogLevel.error);
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
                            Text('搜索设备', style: AppTextStyles.pageTitle),
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
                              style: AppTextStyles.itemTitle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('请确保蓝牙已开启且靠近车辆', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<List<ScanResult>>(
                        valueListenable: _resultsNotifier,
                        builder: (context, results, _) {
                          return _DeviceList(
                            results: results,
                            connectingRemoteId: _connectingRemoteId,
                            onTap: _connectDevice,
                          );
                        },
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: AppShadows.elevation1,
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
            child: Icon(icon, color: AppColors.primary, size: AppIconSizes.md),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
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
    return RepaintBoundary(
      child: SizedBox(
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
                size: AppIconSizes.md,
              ),
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
          key: ValueKey(remoteId),
          padding: const EdgeInsets.only(bottom: 10),
          child: _DeviceEntrance(
            child: _DeviceCard(
              result: r,
              connecting: connecting,
              disabled: disabled,
              onTap: () => onTap(r.device),
            ),
          ),
        );
      },
    );
  }
}

/// Plays a one-shot fade + slide-up animation when a device card first appears
/// in the list. Keyed by the device id upstream so each newly discovered device
/// animates in once and existing cards stay put on subsequent scan updates.
class _DeviceEntrance extends StatefulWidget {
  final Widget child;
  const _DeviceEntrance({required this.child});

  @override
  State<_DeviceEntrance> createState() => _DeviceEntranceState();
}

class _DeviceEntranceState extends State<_DeviceEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
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

    return AppPressable(
      enabled: interactive,
      onTap: widget.onTap,
      pressedScale: 0.98,
      haptic: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: widget.disabled ? const Color(0xFFF8F8F8) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: widget.disabled
              ? AppShadows.elevation1
              : AppShadows.elevation1,
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
                isTailg ? Icons.electric_bike : Icons.bluetooth_outlined,
                size: AppIconSizes.md,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.itemTitle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.result.device.remoteId.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '连接中',
                    style: AppTextStyles.caption.copyWith(fontSize: 11.0),
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
                    style: AppTextStyles.caption.copyWith(fontSize: 11.0),
                  ),
                ],
              ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: !enabled
              ? const Color(0xFFBDBDBD)
              : scanning
              ? const Color(0xFF757575)
              : AppColors.primary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: !enabled
              ? AppShadows.elevation1
              : scanning
              ? AppShadows.elevation2
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              scanning ? Icons.stop_rounded : Icons.bluetooth_searching,
              color: Colors.white,
              size: AppIconSizes.md,
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
