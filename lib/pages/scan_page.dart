import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import '../ble/constants.dart';
import '../main.dart';
import '../services/ble_connection_snapshot_guard.dart';
import '../models/vehicle_profile.dart';
import '../services/log_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/motion_policy.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/lucide_icon.dart';

const _scanCardDecoration = BoxDecoration(
  color: CyberHomeColors.card,
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.tile)),
  border: Border.fromBorderSide(BorderSide(color: CyberHomeColors.line)),
);

const _scanItemTitle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: CyberHomeColors.ink,
);

const _scanCaptionText = TextStyle(
  fontSize: 12,
  color: CyberHomeColors.inkFaint,
);

class ScanPage extends StatefulWidget {
  final DateTime Function()? clock;

  const ScanPage({super.key, this.clock});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final _resultsNotifier = ValueNotifier<List<ScanResult>>(<ScanResult>[]);
  final _connectionSnapshotGuard = const BleConnectionSnapshotGuard();
  bool _scanning = false;
  String? _connectingRemoteId;
  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  StreamSubscription<bool>? _isScanSub;
  Timer? _throttle;
  List<ScanResult>? _pendingResults;
  late AnimationController _radarController;
  bool _radarMotionEnabled = true;

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
          _resultsNotifier.value = _stabilizeScanResults(next);
        }
      });
    });
    _isScanSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!mounted) return;
      setState(() => _scanning = scanning);
      _syncRadarAnimation();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = MotionPolicy.loopsEnabled(context);
    if (_radarMotionEnabled == enabled) return;
    _radarMotionEnabled = enabled;
    _syncRadarAnimation();
  }

  void _syncRadarAnimation() {
    if (_scanning && _radarMotionEnabled) {
      if (!_radarController.isAnimating) {
        unawaited(_radarController.repeat());
      }
      return;
    }
    _radarController
      ..stop()
      ..value = 0.08;
  }

  List<ScanResult> _stabilizeScanResults(List<ScanResult> results) {
    final byId = <String, ScanResult>{};
    for (final result in results) {
      final id = result.device.remoteId.toString();
      final current = byId[id];
      if (current == null || result.rssi > current.rssi) byId[id] = result;
    }
    final stable = <ScanResult>[];
    for (final previous in _resultsNotifier.value) {
      final id = previous.device.remoteId.toString();
      final latest = byId.remove(id);
      if (latest != null) stable.add(latest);
    }
    final newcomers = byId.values.toList()
      ..sort((a, b) {
        final strength = b.rssi.compareTo(a.rssi);
        if (strength != 0) return strength;
        return a.device.remoteId.toString().compareTo(
          b.device.remoteId.toString(),
        );
      });
    return List.unmodifiable([...stable, ...newcomers]);
  }

  @override
  void dispose() {
    _throttle?.cancel();
    unawaited(_scanResultsSub?.cancel());
    unawaited(_isScanSub?.cancel());
    _resultsNotifier.dispose();
    _radarController.dispose();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    final result = await permissionService.requestBleScanPermissions();
    if (!mounted) return false;
    if (!result.granted) {
      if (result.openSettingsRecommended) {
        AppSnack.error(
          context,
          result.message ?? '请到系统设置开启蓝牙和定位权限',
          actionLabel: '去设置',
          onAction: () {
            unawaited(permissionService.openSystemSettings());
          },
        );
      } else {
        AppSnack.error(context, result.message ?? '请授予蓝牙和定位权限后再扫描');
      }
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
    try {
      await FlutterBluePlus.startScan(
        timeout: BleTimings.manualScanTimeout,
        androidUsesFineLocation: true,
      );
    } on PlatformException catch (e) {
      logService.ble('手动扫描启动失败', detail: e.toString(), level: LogLevel.warning);
      if (!mounted) return;
      AppSnack.error(
        context,
        '扫描启动失败，请检查蓝牙权限',
        actionLabel: '去设置',
        onAction: () {
          unawaited(permissionService.openSystemSettings());
        },
      );
    } catch (e) {
      logService.ble('手动扫描启动失败', detail: e.toString(), level: LogLevel.warning);
      if (!mounted) return;
      AppSnack.error(context, '扫描启动失败，请稍后重试');
    }
  }

  void _stopScan() {
    unawaited(FlutterBluePlus.stopScan());
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
        lastConnectedAt: (widget.clock ?? DateTime.now)(),
      );
      applyVehicleBleCredentials(profile);
      unawaited(locationService.recordVehicleLocation(profile.id));
      if (mounted) {
        AppSnack.success(context, '连接成功，已绑定为默认车辆');
      }
    } catch (e) {
      logService.ble('连接绑定设备失败', detail: e.toString(), level: LogLevel.error);
      if (mounted) {
        AppSnack.error(context, '连接失败，请稍后重试');
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
          backgroundColor: CyberHomeColors.pageBg,
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
                      const _ScanHeader(),
                      if (!bluetoothOn)
                        const _ScanHintCard(
                          icon: Lucide.bluetoothOff,
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
                              style: _scanItemTitle,
                            ),
                            const SizedBox(height: 4),
                            Text('请确保蓝牙已开启且靠近车辆', style: _scanCaptionText),
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
                    child: ScanFab(
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

class _ScanHeader extends StatelessWidget {
  const _ScanHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Row(
        children: [
          AppPressable(
            key: const ValueKey('scan-page-back'),
            onTap: () => Navigator.of(context).pop(),
            semanticsLabel: '返回',
            semanticsButton: true,
            child: Container(
              width: AppTouchTargets.min,
              height: AppTouchTargets.min,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: CyberHomeColors.card,
                shape: BoxShape.circle,
                boxShadow: AppShadows.cyberActionShadow,
              ),
              child: const LucideIcon(
                Lucide.arrowLeft,
                size: 20,
                color: CyberHomeColors.inkSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '搜索设备',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: CyberHomeColors.ink,
              ),
            ),
          ),
        ],
      ),
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
      decoration: _scanCardDecoration,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: CyberHomeColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: LucideIcon(
              icon,
              color: CyberHomeColors.primary,
              size: AppIconSizes.md,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _scanItemTitle),
                const SizedBox(height: 2),
                Text(subtitle, style: _scanCaptionText),
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
              width: AppTouchTargets.min,
              height: AppTouchTargets.min,
              decoration: const BoxDecoration(
                color: CyberHomeColors.primary,
                shape: BoxShape.circle,
                boxShadow: AppShadows.cyberActionShadow,
              ),
              child: const LucideIcon(
                Lucide.bluetoothSearching,
                color: CyberHomeColors.white,
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
      ..color = CyberHomeColors.primarySoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, 30, ringPaint);
    canvas.drawCircle(center, 55, ringPaint);
    canvas.drawCircle(center, 80, ringPaint);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - 1.05,
        endAngle: sweepAngle,
        colors: [CyberHomeColors.transparent, CyberHomeColors.primarySoft],
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
    return AnimatedSize(
      duration: MotionPolicy.duration(context, AppMotion.dataChange),
      alignment: Alignment.topCenter,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: results.length,
        findChildIndexCallback: (key) {
          if (key is! ValueKey<String>) return null;
          final index = results.indexWhere(
            (result) => result.device.remoteId.toString() == key.value,
          );
          return index < 0 ? null : index;
        },
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
      ),
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
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _controller, curve: AppMotion.entranceCurve),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPolicy.reduceMotion(context)) {
      _controller.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      unawaited(_controller.forward());
    }
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
      pressedScale: AppMotion.pressScale,
      haptic: false,
      child: AnimatedContainer(
        duration: AppMotion.micro,
        curve: AppMotion.pressCurve,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: widget.disabled
              ? CyberHomeColors.cardMuted
              : CyberHomeColors.card,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(color: CyberHomeColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: AppTouchTargets.min,
              height: AppTouchTargets.min,
              decoration: BoxDecoration(
                color: isTailg
                    ? CyberHomeColors.primarySoft
                    : CyberHomeColors.control,
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              child: LucideIcon(
                isTailg ? Lucide.vehicle : Lucide.bluetooth,
                size: AppIconSizes.md,
                color: isTailg
                    ? CyberHomeColors.primary
                    : CyberHomeColors.inkFaint,
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
                    style: _scanItemTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.result.device.remoteId.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CyberHomeColors.inkFaint,
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CyberHomeColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('连接中', style: _scanCaptionText.copyWith(fontSize: 11)),
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
                    style: _scanCaptionText.copyWith(fontSize: 11),
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
        ? CyberHomeColors.warning
        : CyberHomeColors.success;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        return Container(
          width: 4,
          height: heights[i],
          margin: EdgeInsets.only(left: i > 0 ? 2 : 0),
          decoration: BoxDecoration(
            color: i < activeCount ? activeColor : CyberHomeColors.lineStrong,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

class ScanFab extends StatelessWidget {
  final bool scanning;
  final bool enabled;
  final VoidCallback onTap;
  const ScanFab({
    super.key,
    required this.scanning,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = scanning ? '停止扫描' : '扫描';
    return AppPressable(
      onTap: onTap,
      enabled: enabled,
      haptic: false,
      semanticsContainer: true,
      semanticsLabel: label,
      semanticsButton: true,
      semanticsEnabled: enabled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(
          minWidth: 128,
          minHeight: AppTouchTargets.min,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: !enabled
              ? CyberHomeColors.controlStrong
              : scanning
              ? CyberHomeColors.inkSecondary
              : CyberHomeColors.primary,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          boxShadow: AppShadows.cyberActionShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LucideIcon(
              scanning ? Lucide.stop : Lucide.bluetoothSearching,
              color: enabled ? CyberHomeColors.white : CyberHomeColors.inkFaint,
              size: AppIconSizes.md,
            ),
            const SizedBox(width: 8),
            Text(
              scanning ? '停止' : '扫描',
              style: TextStyle(
                color: enabled
                    ? CyberHomeColors.white
                    : CyberHomeColors.inkFaint,
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
