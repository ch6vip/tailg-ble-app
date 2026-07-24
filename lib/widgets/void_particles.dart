import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/app_void.dart';

/// Volumetric particle field — animated, reactive, immersive.
///
/// Renders soft energy particles that drift, pulse, and respond to
/// interaction pressure. Handled as a pure [CustomPainter] for 60fps
/// performance.
class VoidParticleField extends StatefulWidget {
  const VoidParticleField({
    super.key,
    this.particleCount = 48,
    this.energyColor = VoidColors.energy,
    this.driftSpeed = 0.08,
    this.scale = 1.0,
    this.interactionOffset,
  });

  final int particleCount;
  final Color energyColor;
  final double driftSpeed;
  final double scale;
  final Offset? interactionOffset;

  /// Set to false to disable continuous animation (e.g. in tests that use
  /// [WidgetTester.pumpAndSettle]).
  static bool enableAnimation = true;

  @override
  State<VoidParticleField> createState() => _VoidParticleFieldState();
}

class _VoidParticleFieldState extends State<VoidParticleField>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_Particle> _particles = [];
  final ValueNotifier<double> _elapsedNotifier = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _initParticles();
    _ticker = createTicker((elapsed) {
      _elapsedNotifier.value = elapsed.inMicroseconds / 1000;
    });
    if (VoidParticleField.enableAnimation) {
      unawaited(_ticker.start());
    }
  }

  void _initParticles() {
    final rng = math.Random(42);
    _particles.clear();
    for (var i = 0; i < widget.particleCount; i++) {
      _particles.add(
        _Particle(
          x: rng.nextDouble(),
          y: rng.nextDouble(),
          size: 1.2 + rng.nextDouble() * 3.2,
          speedX: (rng.nextDouble() - 0.5) * widget.driftSpeed,
          speedY: (rng.nextDouble() - 0.5) * widget.driftSpeed * 0.6,
          phase: rng.nextDouble() * math.pi * 2,
          pulsePeriod: 1.2 + rng.nextDouble() * 2.8,
          opacity: 0.12 + rng.nextDouble() * 0.35,
        ),
      );
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ParticlePainter(
          particles: _particles,
          elapsed: _elapsedNotifier,
          energyColor: widget.energyColor,
          interactionOffset: widget.interactionOffset,
          scale: widget.scale,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.phase,
    required this.pulsePeriod,
    required this.opacity,
  });

  double x;
  double y;
  final double size;
  final double speedX;
  final double speedY;
  final double phase;
  final double pulsePeriod;
  final double opacity;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.particles,
    required ValueNotifier<double> elapsed,
    required this.energyColor,
    required this.interactionOffset,
    required this.scale,
  }) : _elapsed = elapsed,
       super(repaint: elapsed);

  final List<_Particle> particles;
  final ValueNotifier<double> _elapsed;
  double get elapsed => _elapsed.value;
  final Color energyColor;
  final Offset? interactionOffset;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final dt = 0.016; // ~60fps step
    final w = size.width;
    final h = size.height;
    final ms = elapsed / 1000;

    for (final p in particles) {
      // Drift
      p.x += p.speedX * dt * 60 * scale;
      p.y += p.speedY * dt * 60 * scale;

      // Wrap around
      if (p.x < -0.05) p.x = 1.05;
      if (p.x > 1.05) p.x = -0.05;
      if (p.y < -0.05) p.y = 1.05;
      if (p.y > 1.05) p.y = -0.05;

      // Interaction repel
      if (interactionOffset != null) {
        final dx = (p.x * w - interactionOffset!.dx) / w;
        final dy = (p.y * h - interactionOffset!.dy) / h;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < 0.12) {
          final force = (0.12 - dist) / 0.12 * 0.03;
          p.x += dx * force;
          p.y += dy * force;
        }
      }

      // Pulse opacity
      final pulse = math.sin(ms * (2 * math.pi / p.pulsePeriod) + p.phase);
      final alpha = (0.4 + 0.6 * ((pulse + 1) / 2)) * p.opacity;
      final drawSize = p.size * (0.8 + 0.2 * ((pulse + 1) / 2));

      final px = p.x * w;
      final py = p.y * h;

      // Glow halo
      final glowPaint = Paint()
        ..color = energyColor.withValues(alpha: alpha * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(px, py), drawSize * 3, glowPaint);

      // Core
      final corePaint = Paint()
        ..color = energyColor.withValues(alpha: alpha * 0.9);
      canvas.drawCircle(Offset(px, py), drawSize * 0.8, corePaint);
    }

    // Subtle connection lines between nearby particles
    final threshold = 0.08;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4;
    for (var i = 0; i < particles.length; i += 2) {
      for (var j = i + 1; j < particles.length; j += 2) {
        final a = particles[i];
        final b = particles[j];
        final dx = a.x - b.x;
        final dy = a.y - b.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < threshold) {
          final alpha = (1 - dist / threshold) * 0.12;
          linePaint.color = energyColor.withValues(alpha: alpha);
          canvas.drawLine(
            Offset(a.x * w, a.y * h),
            Offset(b.x * w, b.y * h),
            linePaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
