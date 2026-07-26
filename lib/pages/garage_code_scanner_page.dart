import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/lucide_icon.dart';

class GarageCodeScannerPage extends StatefulWidget {
  const GarageCodeScannerPage({super.key});

  @override
  State<GarageCodeScannerPage> createState() => _GarageCodeScannerPageState();
}

class _GarageCodeScannerPageState extends State<GarageCodeScannerPage>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
    ],
  );
  var _handled = false;
  var _torchOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_startScanner());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(_stopScanner());
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _startScanner() async {
    try {
      await _controller.start();
    } on MobileScannerException {
      // The controller exposes the same failure through its state so the
      // scanner errorBuilder can render the actionable error screen.
    }
  }

  Future<void> _stopScanner() async {
    try {
      await _controller.stop();
    } on MobileScannerException {
      // Lifecycle changes can arrive while camera initialization is pending.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim() ?? '';
      if (value.isEmpty) continue;
      _handled = true;
      unawaited(_controller.stop());
      Navigator.of(context).pop(value);
      return;
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } on MobileScannerException {
      return;
    }
    if (mounted) setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberHomeColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(
              permissionDenied:
                  error.errorCode == MobileScannerErrorCode.permissionDenied,
            ),
          ),
          const _ScannerMask(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ScannerAction(
                        label: '返回',
                        icon: Lucide.arrowLeft,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      _ScannerAction(
                        label: _torchOn ? '关闭手电筒' : '打开手电筒',
                        icon: Lucide.zap,
                        active: _torchOn,
                        onTap: _toggleTorch,
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    '扫描车辆二维码或车架条码',
                    style: TextStyle(
                      color: CyberHomeColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.permissionDenied});

  final bool permissionDenied;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CyberHomeColors.ink,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LucideIcon(
                Lucide.alertCircle,
                size: 32,
                color: CyberHomeColors.white,
              ),
              const SizedBox(height: 12),
              Text(
                permissionDenied ? '需要相机权限才能扫码' : '当前设备无法启动相机',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: CyberHomeColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (permissionDenied) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => unawaited(openAppSettings()),
                  child: const Text('打开设置'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerMask extends StatelessWidget {
  const _ScannerMask();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ScannerMaskPainter());
  }
}

class _ScannerMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final windowSize = size.width.clamp(220.0, 290.0);
    final window = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.44),
      width: windowSize,
      height: windowSize,
    );
    final overlay = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(8)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      overlay,
      Paint()..color = CyberHomeColors.ink.withValues(alpha: 0.62),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(window, const Radius.circular(8)),
      Paint()
        ..color = CyberHomeColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScannerAction extends StatelessWidget {
  const _ScannerAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: AppPressable(
        onTap: onTap,
        semanticsLabel: label,
        semanticsButton: true,
        child: Container(
          width: AppTouchTargets.min,
          height: AppTouchTargets.min,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? CyberHomeColors.primary
                : CyberHomeColors.ink.withValues(alpha: 0.56),
            shape: BoxShape.circle,
          ),
          child: LucideIcon(icon, color: CyberHomeColors.white, size: 20),
        ),
      ),
    );
  }
}
