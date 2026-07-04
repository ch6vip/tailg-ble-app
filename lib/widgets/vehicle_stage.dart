import 'package:flutter/material.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';

/// Fallback vehicle illustration used only when the official asset cannot be
/// loaded.
class VehicleStagePainter extends CustomPainter {
  VehicleStagePainter({this.batteryLevel = 0.84});

  /// Battery level 0.0–1.0, drives the green energy bar width.
  final double batteryLevel;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Scale the original 340×172 viewBox to fit
    final sx = w / 340;
    final sy = h / 172;
    final s = sx < sy ? sx : sy;
    final ox = (w - 340 * s) / 2;
    final oy = (h - 172 * s) / 2;

    canvas.save();
    canvas.translate(ox, oy);
    canvas.scale(s);

    _drawFloor(canvas);
    _drawBrandMark(canvas);
    _drawVehicle(canvas);
    canvas.restore();
  }

  void _drawFloor(Canvas canvas) {
    final paint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, 0.7),
        radius: 0.5,
        colors: [Color(0x18BFCAD6), Color(0x00BFCAD6)],
      ).createShader(const Rect.fromLTWH(60, 100, 220, 50))
      ..style = PaintingStyle.fill;
    canvas.drawOval(const Rect.fromLTWH(80, 135, 180, 20), paint);
  }

  void _drawBrandMark(Canvas canvas) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'TAILG',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFDFE5EC),
          letterSpacing: 8,
          fontFamily: 'Arial',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, const Offset(110, -18));
  }

  void _drawVehicle(Canvas canvas) {
    final bodyGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFCFDFE), Color(0xFFDFE5EC)],
    );
    final tireGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFE3E8EF), Color(0xFFC2CAD4)],
    );
    final enGradient = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFF00E0A6), Color(0xFF00A57C)],
    );

    // Body stroke color
    final bodyStroke = Paint()
      ..color = const Color(0xFF2A313D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeJoin = StrokeJoin.round;

    // Body fill
    final bodyFill = Paint()
      ..shader = bodyGradient.createShader(
        const Rect.fromLTRB(46, 50, 340, 130),
      );
    final tireFill = Paint()
      ..shader = tireGradient.createShader(
        const Rect.fromLTRB(0, 100, 340, 172),
      );

    // --- Rear mudguard ---
    canvas.drawPath(
      _cubicPath(46, 116, 80, 80, 118, 104),
      Paint()
        ..color = const Color(0xFFC2CAD4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );

    // --- Front mudguard ---
    canvas.drawPath(
      _cubicPath(232, 112, 266, 80, 304, 110),
      Paint()
        ..color = const Color(0xFFC2CAD4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );

    // --- Rear body (seat/battery compartment) ---
    final rearBody = Path()
      ..moveTo(92, 72)
      ..lineTo(150, 68)
      ..quadraticBezierTo(160, 70, 162, 82)
      ..lineTo(168, 120)
      ..lineTo(104, 124)
      ..quadraticBezierTo(90, 104, 88, 84)
      ..quadraticBezierTo(88, 75, 92, 72)
      ..close();
    canvas.drawPath(rearBody, bodyFill);
    canvas.drawPath(rearBody, bodyStroke);

    // --- Battery energy bar (dynamic: scales with batteryLevel) ---
    const barW = 40.0;
    const barX = 108.0;
    const barY = 92.0;
    const barH = 13.0;
    final fillW = barW * (batteryLevel.clamp(0.0, 1.0));

    // Background track (empty)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW, barH),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFE8ECF1),
    );
    // Filled portion
    if (fillW > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, fillW, barH),
          const Radius.circular(4),
        ),
        Paint()
          ..shader = enGradient.createShader(
            Rect.fromLTWH(barX, barY, barW, barH),
          ),
      );
    }
    // Subtle border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW, barH),
        const Radius.circular(4),
      ),
      Paint()
        ..color = const Color(0xFF04231A).withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // --- Footboard (low step-through) ---
    canvas.drawLine(
      const Offset(150, 124),
      const Offset(214, 124),
      Paint()
        ..color = const Color(0xFF2A313D)
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(156, 124),
      const Offset(210, 124),
      Paint()
        ..color = const Color(0xFF3A434F)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..colorFilter = const ColorFilter.mode(
          Color(0x803A434F),
          BlendMode.srcOver,
        ),
    );

    // --- Front leg shield + stem ---
    final frontShield = Path()
      ..moveTo(214, 124)
      ..quadraticBezierTo(214, 104, 224, 90)
      ..quadraticBezierTo(236, 70, 250, 60)
      ..lineTo(266, 54)
      ..quadraticBezierTo(272, 60, 268, 74)
      ..quadraticBezierTo(260, 96, 244, 112)
      ..quadraticBezierTo(232, 122, 224, 124)
      ..close();
    canvas.drawPath(frontShield, bodyFill);
    canvas.drawPath(frontShield, bodyStroke);

    // --- Seat ---
    final seat = Path()
      ..moveTo(60, 70)
      ..quadraticBezierTo(54, 58, 72, 55)
      ..lineTo(150, 50)
      ..quadraticBezierTo(164, 50, 160, 63)
      ..lineTo(154, 70)
      ..quadraticBezierTo(150, 73, 142, 72)
      ..lineTo(70, 73)
      ..quadraticBezierTo(62, 73, 60, 70)
      ..close();
    canvas.drawPath(seat, Paint()..color = const Color(0xFF2A313D));
    // Seat stitch line
    canvas.drawLine(
      const Offset(74, 58),
      const Offset(148, 54),
      Paint()
        ..color = const Color(0x4D4A5563)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // --- Handlebar stem + handlebar ---
    canvas.drawLine(
      const Offset(258, 60),
      const Offset(278, 32),
      Paint()
        ..color = const Color(0xFF2A313D)
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(266, 32),
      const Offset(296, 27),
      Paint()
        ..color = const Color(0xFF2A313D)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    // --- Dashboard ---
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(252, 40, 22, 15),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF1B2230),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(256, 44, 14, 7),
        const Radius.circular(2),
      ),
      Paint()..color = AppColors.energyGreen.withValues(alpha: 0.9),
    );

    // --- Headlight ---
    final headlight = Path()
      ..moveTo(244, 96)
      ..lineTo(266, 102)
      ..lineTo(263, 116)
      ..lineTo(241, 110)
      ..close();
    canvas.drawPath(headlight, Paint()..color = const Color(0xFF3A434F));
    canvas.drawOval(
      const Rect.fromLTWH(249, 100, 10, 11),
      Paint()..color = const Color(0xFFFCE7B8),
    );

    // --- Rear wheel ---
    _drawWheel(canvas, 82, 130, tireFill);
    // --- Front wheel ---
    _drawWheel(canvas, 268, 130, tireFill);
  }

  void _drawWheel(Canvas canvas, double cx, double cy, Paint tireFill) {
    // Tire
    canvas.drawCircle(Offset(cx, cy), 30, tireFill);
    canvas.drawCircle(
      Offset(cx, cy),
      30,
      Paint()
        ..color = const Color(0xFF2A313D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5,
    );
    // Hub
    canvas.drawCircle(
      Offset(cx, cy),
      13.5,
      Paint()..color = const Color(0xFFF6F8FB),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      13.5,
      Paint()
        ..color = const Color(0xFF9AA3B0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Axle
    canvas.drawCircle(
      Offset(cx, cy),
      3.6,
      Paint()..color = const Color(0xFF2A313D),
    );
    // Spokes
    final sp = Paint()
      ..color = const Color(0xFFB6BEC9)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(cx, cy - 12), Offset(cx, cy + 12), sp);
    canvas.drawLine(Offset(cx - 12, cy), Offset(cx + 12, cy), sp);
    canvas.drawLine(Offset(cx - 8.5, cy - 8.5), Offset(cx + 8.5, cy + 8.5), sp);
    canvas.drawLine(Offset(cx - 8.5, cy + 8.5), Offset(cx + 8.5, cy - 8.5), sp);
  }

  Path _cubicPath(
    double x1,
    double y1,
    double cx,
    double cy,
    double x2,
    double y2,
  ) {
    return Path()
      ..moveTo(x1, y1)
      ..quadraticBezierTo(cx, cy, x2, y2);
  }

  @override
  bool shouldRepaint(covariant VehicleStagePainter old) =>
      batteryLevel != old.batteryLevel;
}

/// Wrapper widget for the vehicle stage with proper sizing and shadow.
class VehicleStage extends StatelessWidget {
  const VehicleStage({
    super.key,
    this.batteryLevel = 0.84,
    this.height = 200,
    this.imageUrl,
  });

  final double batteryLevel;
  final double height;
  final String? imageUrl;

  String? get _normalizedImageUrl {
    final value = imageUrl?.trim();
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return value;
    }
    if (value.startsWith('//')) return 'https:$value';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vehicleWidth = (constraints.maxWidth * 0.66).clamp(218.0, 300.0);
        final remoteImageUrl = _normalizedImageUrl;
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                left: (constraints.maxWidth - vehicleWidth) / 2 + 18,
                right: (constraints.maxWidth - vehicleWidth) / 2 + 18,
                bottom: 28,
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF385064).withValues(alpha: 0.14),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: _VehicleImage(
                  imageUrl: remoteImageUrl,
                  width: vehicleWidth,
                  height: height - 18,
                  batteryLevel: batteryLevel,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VehicleImage extends StatelessWidget {
  const _VehicleImage({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.batteryLevel,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final double batteryLevel;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null) {
      return Image.network(
        url,
        key: const ValueKey('vehicle-stage-network-image'),
        fit: BoxFit.contain,
        width: width,
        height: height,
        semanticLabel: '台铃车辆',
        errorBuilder: (_, __, ___) => _fallbackImage(),
      );
    }
    return _fallbackImage();
  }

  Widget _fallbackImage() {
    return Image.asset(
      'assets/official_tailg/vehicle.png',
      key: const ValueKey('vehicle-stage-asset-image'),
      fit: BoxFit.contain,
      width: width,
      height: height,
      semanticLabel: '台铃车辆',
      errorBuilder: (_, __, ___) => SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: VehicleStagePainter(batteryLevel: batteryLevel),
        ),
      ),
    );
  }
}
