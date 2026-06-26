part of 'control_page.dart';
// ignore_for_file: unused_element

/// v8 透视线稿电动车。设计稿在 340×172 的 viewBox 中绘制，这里在同一坐标系
/// 作画并整体缩放铺满画布，保证比例与设计稿一致（穿行式车架 + 双辐条轮 +
/// teal 电池能量条）。
class _UnboundBannerPainter extends CustomPainter {
  const _UnboundBannerPainter();

  static const double _vbWidth = 340;
  static const double _vbHeight = 172;
  static const Color _ink = Color(0xFF2A313D);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _vbWidth;
    final scaledHeight = _vbHeight * scale;
    // Vertically center the artwork within the available band.
    final dy = (size.height - scaledHeight) / 2;

    canvas.save();
    canvas.translate(0, dy);
    canvas.scale(scale);
    _paintVehicle(canvas);
    canvas.restore();
  }

  void _paintVehicle(Canvas canvas) {
    final bodyShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFCFDFE), Color(0xFFDFE5EC)],
    ).createShader(const Rect.fromLTRB(60, 48, 270, 126));
    final tireShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFE3E8EF), Color(0xFFC2CAD4)],
    ).createShader(const Rect.fromLTRB(0, 100, 0, 160));
    final energyShader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFF00E0A6), Color(0xFF00A57C)],
    ).createShader(const Rect.fromLTRB(108, 92, 148, 105));

    // Drop shadow under the bike grounds it on the floor.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(175, 168), width: 240, height: 18),
      Paint()
        ..color = const Color(0xFF18273F).withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final fenderPaint = Paint()
      ..color = const Color(0xFFC2CAD4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(46, 116)
        ..quadraticBezierTo(80, 80, 118, 104),
      fenderPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(232, 112)
        ..quadraticBezierTo(266, 80, 304, 110),
      fenderPaint,
    );

    final bodyStroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeJoin = StrokeJoin.round;

    // Rear body: seat / battery bay.
    final rearBody = Path()
      ..moveTo(92, 72)
      ..lineTo(150, 68)
      ..quadraticBezierTo(160, 70, 162, 82)
      ..lineTo(168, 120)
      ..lineTo(104, 124)
      ..quadraticBezierTo(90, 104, 88, 84)
      ..quadraticBezierTo(88, 75, 92, 72)
      ..close();
    canvas.drawPath(rearBody, Paint()..shader = bodyShader);
    canvas.drawPath(rearBody, bodyStroke);

    // teal battery energy bar.
    final energyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(108, 92, 40, 13),
      const Radius.circular(4),
    );
    canvas.drawRRect(energyRect, Paint()..shader = energyShader);
    canvas.drawRRect(
      energyRect,
      Paint()
        ..color = const Color(0xFF04231A).withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Step-through footboard.
    canvas.drawLine(
      const Offset(150, 124),
      const Offset(214, 124),
      Paint()
        ..color = _ink
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(156, 124),
      const Offset(210, 124),
      Paint()
        ..color = const Color(0xFF3A434F).withValues(alpha: 0.5)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Front leg shield + stem.
    final legShield = Path()
      ..moveTo(214, 124)
      ..quadraticBezierTo(214, 104, 224, 90)
      ..quadraticBezierTo(236, 70, 250, 60)
      ..lineTo(266, 54)
      ..quadraticBezierTo(272, 60, 268, 74)
      ..quadraticBezierTo(260, 96, 244, 112)
      ..quadraticBezierTo(232, 122, 224, 124)
      ..close();
    canvas.drawPath(legShield, Paint()..shader = bodyShader);
    canvas.drawPath(legShield, bodyStroke);

    // Seat.
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
    canvas.drawPath(seat, Paint()..color = _ink);
    canvas.drawLine(
      const Offset(74, 58),
      const Offset(148, 54),
      Paint()
        ..color = const Color(0xFF4A5563).withValues(alpha: 0.7)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Handlebar stem + bar.
    canvas.drawLine(
      const Offset(258, 60),
      const Offset(278, 32),
      Paint()
        ..color = _ink
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(266, 32),
      const Offset(296, 27),
      Paint()
        ..color = _ink
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    // Dashboard.
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
      Paint()..color = const Color(0xFF00C896).withValues(alpha: 0.9),
    );

    // Headlight.
    canvas.drawPath(
      Path()
        ..moveTo(244, 96)
        ..lineTo(266, 102)
        ..lineTo(263, 116)
        ..lineTo(241, 110)
        ..close(),
      Paint()..color = const Color(0xFF3A434F),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(254, 105), width: 10, height: 12),
      Paint()..color = const Color(0xFFFCE7B8),
    );

    // Wheels last so they sit on top of the fenders.
    _drawWheel(canvas, 82, 130, tireShader);
    _drawWheel(canvas, 268, 130, tireShader);
  }

  void _drawWheel(Canvas canvas, double cx, double cy, Shader tire) {
    final center = Offset(cx, cy);
    canvas.drawCircle(center, 30, Paint()..shader = tire);
    canvas.drawCircle(
      center,
      30,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5,
    );
    canvas.drawCircle(center, 13.5, Paint()..color = const Color(0xFFF6F8FB));
    canvas.drawCircle(
      center,
      13.5,
      Paint()
        ..color = const Color(0xFF9AA3B0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(center, 3.6, Paint()..color = _ink);

    final spoke = Paint()
      ..color = const Color(0xFFB6BEC9)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - 12), Offset(cx, cy + 12), spoke);
    canvas.drawLine(Offset(cx - 12, cy), Offset(cx + 12, cy), spoke);
    canvas.drawLine(
      Offset(cx - 8.5, cy - 8.5),
      Offset(cx + 8.5, cy + 8.5),
      spoke,
    );
    canvas.drawLine(
      Offset(cx - 8.5, cy + 8.5),
      Offset(cx + 8.5, cy - 8.5),
      spoke,
    );
  }

  @override
  bool shouldRepaint(covariant _UnboundBannerPainter oldDelegate) => false;
}

class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = ReplicaBikeColors.surface;
    canvas.drawRect(Offset.zero & size, bg);

    final park = Paint()..color = ReplicaBikeColors.parking;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.04,
          size.height * 0.10,
          size.width * 0.35,
          size.height * 0.28,
        ),
        const Radius.circular(16),
      ),
      park,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.62,
          size.height * 0.56,
          size.width * 0.28,
          size.height * 0.32,
        ),
        const Radius.circular(16),
      ),
      park,
    );

    final road = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final mainRoad = Path()
      ..moveTo(-20, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.34,
        size.height * 0.42,
        size.width * 0.56,
        size.height * 0.52,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.62,
        size.width + 20,
        size.height * 0.30,
      );
    canvas.drawPath(mainRoad, road);
    canvas.drawLine(
      Offset(size.width * 0.18, -20),
      Offset(size.width * 0.58, size.height + 20),
      road,
    );

    final line = Paint()
      ..color = ReplicaBikeColors.handle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 34) {
      canvas.drawLine(Offset(x, 0), Offset(x + 18, size.height), line);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 6), line);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) => false;
}

class _SoundWavePainter extends CustomPainter {
  final Color color;

  const _SoundWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 5; i++) {
      final path = Path();
      final y = size.height * (0.18 + i * 0.14);
      path.moveTo(size.width * 0.46, y);
      path.cubicTo(
        size.width * 0.58,
        y - 16,
        size.width * 0.70,
        y + 18,
        size.width * 0.86,
        y,
      );
      path.cubicTo(
        size.width * 0.93,
        y - 8,
        size.width * 0.98,
        y + 8,
        size.width * 1.04,
        y,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoundWavePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SweepHighlight extends StatefulWidget {
  final Color color;

  const _SweepHighlight({required this.color});

  @override
  State<_SweepHighlight> createState() => _SweepHighlightState();
}

class _SweepHighlightState extends State<_SweepHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Transform.rotate(
            angle: -0.35,
            child: Container(
              width: 34,
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    widget.color,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        builder: (context, child) {
          final dx = -0.35 + _controller.value * 1.7;
          return FractionalTranslation(
            translation: Offset(dx, 0),
            child: child,
          );
        },
      ),
    );
  }
}

class _PulseActionIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _PulseActionIcon({required this.icon, required this.color});

  @override
  State<_PulseActionIcon> createState() => _PulseActionIconState();
}

class _PulseActionIconState extends State<_PulseActionIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: widget.color.withValues(alpha: 0.22)),
          ),
          child: Icon(widget.icon, color: widget.color, size: AppIconSizes.sm),
        ),
        builder: (context, child) {
          final value = Curves.easeInOut.transform(_controller.value);
          return SizedBox(
            width: 34,
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 24 + value * 8,
                  height: 24 + value * 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.08 + value * 0.08),
                  ),
                ),
                child!,
              ],
            ),
          );
        },
      ),
    );
  }
}
