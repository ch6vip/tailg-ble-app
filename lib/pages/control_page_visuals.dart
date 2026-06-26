part of 'control_page.dart';

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
