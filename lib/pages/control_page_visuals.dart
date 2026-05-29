part of 'control_page.dart';

class _UnboundBannerPainter extends CustomPainter {
  const _UnboundBannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * 0.55;
    final accent = const Color(0xFF5596FF);
    final red = const Color(0xFFF11C2C);
    final shadow = Paint()
      ..color = const Color(0xFFDDE3EC).withValues(alpha: 0.72);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.78),
        width: size.width * 0.78,
        height: 22,
      ),
      shadow,
    );

    final wheelPaint = Paint()
      ..color = const Color(0xFF252525)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    final rimPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final leftWheel = Offset(size.width * 0.28, centerY + 34);
    final rightWheel = Offset(size.width * 0.72, centerY + 34);
    final radius = math.min(size.width, size.height) * 0.12;
    for (final wheel in [leftWheel, rightWheel]) {
      canvas.drawCircle(wheel, radius, wheelPaint);
      canvas.drawCircle(wheel, radius * 0.62, rimPaint);
    }

    final frame = Path()
      ..moveTo(leftWheel.dx, leftWheel.dy)
      ..lineTo(size.width * 0.42, centerY - 20)
      ..lineTo(size.width * 0.57, leftWheel.dy)
      ..lineTo(rightWheel.dx, rightWheel.dy)
      ..moveTo(size.width * 0.42, centerY - 20)
      ..lineTo(size.width * 0.53, centerY - 64)
      ..lineTo(size.width * 0.66, centerY - 34);
    final framePaint = Paint()
      ..color = const Color(0xFF2A2D35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(frame, framePaint);

    final seatPaint = Paint()
      ..color = const Color(0xFF2A2D35)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.51, centerY - 64),
      Offset(size.width * 0.41, centerY - 68),
      seatPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.65, centerY - 35),
      Offset(size.width * 0.78, centerY - 46),
      seatPaint,
    );

    final batteryRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.43, centerY - 2, size.width * 0.23, 34),
      const Radius.circular(12),
    );
    canvas.drawRRect(batteryRect, Paint()..color = const Color(0xFF121418));
    canvas.drawRRect(
      batteryRect.deflate(5),
      Paint()..color = red.withValues(alpha: 0.78),
    );
  }

  @override
  bool shouldRepaint(covariant _UnboundBannerPainter oldDelegate) => false;
}

class _BikeModelPainter extends CustomPainter {
  final Color accent;
  final bool isPowerOn;
  final bool isLocked;

  const _BikeModelPainter({
    required this.accent,
    required this.isPowerOn,
    required this.isLocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * 0.56;
    final front = Offset(size.width * 0.75, centerY + 34);
    final rear = Offset(size.width * 0.27, centerY + 34);
    final bodyPaint = Paint()
      ..color = const Color(0xFF2A2D35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accentPaint = Paint()
      ..color = accent.withValues(alpha: isPowerOn ? 0.88 : 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final softPaint = Paint()
      ..color = const Color(0xFFDDE3EC).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, centerY + 52),
        width: size.width * 0.82,
        height: 32,
      ),
      softPaint,
    );
    _drawWheel(canvas, rear, 38, isLocked);
    _drawWheel(canvas, front, 38, isLocked);

    final frame = Path()
      ..moveTo(rear.dx, rear.dy)
      ..lineTo(size.width * 0.42, centerY - 16)
      ..lineTo(size.width * 0.59, centerY + 32)
      ..lineTo(front.dx, front.dy)
      ..moveTo(size.width * 0.42, centerY - 16)
      ..lineTo(size.width * 0.54, centerY - 52)
      ..lineTo(size.width * 0.67, centerY - 22);
    canvas.drawPath(frame, bodyPaint);

    final battery = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.42, centerY - 2, size.width * 0.20, 34),
      const Radius.circular(12),
    );
    canvas.drawRRect(battery, Paint()..color = const Color(0xFF121418));
    canvas.drawRRect(
      battery.deflate(5),
      Paint()..color = accent.withValues(alpha: isPowerOn ? 0.78 : 0.22),
    );

    canvas.drawLine(
      Offset(size.width * 0.54, centerY - 46),
      Offset(size.width * 0.49, centerY - 70),
      bodyPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.46, centerY - 70),
      Offset(size.width * 0.58, centerY - 70),
      bodyPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.66, centerY - 18),
      Offset(size.width * 0.72, centerY - 56),
      bodyPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.72, centerY - 56),
      Offset(size.width * 0.80, centerY - 50),
      accentPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.30, centerY + 28),
      Offset(size.width * 0.25, centerY - 20),
      accentPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.80, centerY - 50),
      5,
      Paint()..color = isPowerOn ? accent : Colors.grey.shade500,
    );
  }

  void _drawWheel(Canvas canvas, Offset center, double radius, bool locked) {
    final wheelPaint = Paint()
      ..color = const Color(0xFF252525)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    final rimPaint = Paint()
      ..color = locked ? Colors.grey.shade400 : accent.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, wheelPaint);
    canvas.drawCircle(center, radius - 11, rimPaint);
    for (var i = 0; i < 6; i++) {
      final angle = i * 3.14159 / 3;
      final end = Offset(
        center.dx + (radius - 13) * math.cos(angle),
        center.dy + (radius - 13) * math.sin(angle),
      );
      canvas.drawLine(center, end, rimPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BikeModelPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.isPowerOn != isPowerOn ||
        oldDelegate.isLocked != isLocked;
  }
}

class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFF0F3F8);
    canvas.drawRect(Offset.zero & size, bg);

    final park = Paint()..color = const Color(0xFFDDE7D8);
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
      ..color = const Color(0xFFD9DEE8)
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
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dx = -0.35 + _controller.value * 1.7;
        return FractionalTranslation(
          translation: Offset(dx, 0),
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
        );
      },
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
    return AnimatedBuilder(
      animation: _controller,
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
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(widget.icon, color: widget.color, size: 16),
              ),
            ],
          ),
        );
      },
    );
  }
}
