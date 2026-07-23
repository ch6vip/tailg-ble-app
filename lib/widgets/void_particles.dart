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

  @override
  State<VoidParticleField> createState() => _VoidParticleFieldState();
}

class _VoidParticleFieldState extends State<VoidParticleField>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_Particle> _particles = [];
  double _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _initParticles();
    _ticker = createTicker((elapsed) {
      _elapsed = elapsed.inMicroseconds / 1000;
      if (mounted) setState(() {});
    });
    unawaited(_ticker.start());
  }

  void _initParticles() {
    final rng = math.Random(42);
    _particles.clear();
    for (var i = 0; i < widget.particleCount; i++) {
      _particles.add(_Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 1.2 + rng.nextDouble() * 3.2,
        speedX: (rng.nextDouble() - 0.5) * widget.driftSpeed,
        speedY: (rng.nextDouble() - 0.5) * widget.driftSpeed * 0.6,
        phase: rng.nextDouble() * math.pi * 2,
        pulsePeriod: 1.2 + rng.nextDouble() * 2.8,
        opacity: 0.12 + rng.nextDouble() * 0.35,
      ));
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ParticlePainter(
          particles: _particles,
          elapsed: _elapsed,
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
    required this.elapsed,
    required this.energyColor,
    required this.interactionOffset,
    required this.scale,
  });

  final List<_Particle> particles;
  final double elapsed;
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
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

/// Animated blob nebula — organic, breathing gradient field.
class VoidNebula extends StatefulWidget {
  const VoidNebula({
    super.key,
    this.blobCount = 3,
    this.intensity = 1.0,
    this.colors,
  });

  final int blobCount;
  final double intensity;
  final List<Color>? colors;

  @override
  State<VoidNebula> createState() => _VoidNebulaState();
}

class _VoidNebulaState extends State<VoidNebula>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_NebulaBlob> _blobs = [];
  double _elapsed = 0;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(13);
    final defaultColors = [
      VoidColors.energy.withValues(alpha: 0.12 * widget.intensity),
      const Color(0xFF2E9BFF).withValues(alpha: 0.07 * widget.intensity),
      const Color(0xFF7C6CFF).withValues(alpha: 0.06 * widget.intensity),
    ];
    final colors = widget.colors ?? defaultColors;
    for (var i = 0; i < widget.blobCount; i++) {
      _blobs.add(_NebulaBlob(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 120 + rng.nextDouble() * 200,
        color: colors[i % colors.length],
        driftX: (rng.nextDouble() - 0.5) * 0.02,
        driftY: (rng.nextDouble() - 0.5) * 0.02,
        phase: rng.nextDouble() * math.pi * 2,
      ));
    }
    _ticker = createTicker((elapsed) {
      _elapsed = elapsed.inMicroseconds / 1000;
      if (mounted) setState(() {});
    });
    unawaited(_ticker.start());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _NebulaPainter(blobs: _blobs, elapsed: _elapsed),
        size: Size.infinite,
      ),
    );
  }
}

class _NebulaBlob {
  _NebulaBlob({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.driftX,
    required this.driftY,
    required this.phase,
  });

  double x;
  double y;
  final double size;
  final Color color;
  final double driftX;
  final double driftY;
  final double phase;
}

class _NebulaPainter extends CustomPainter {
  _NebulaPainter({required this.blobs, required this.elapsed});

  final List<_NebulaBlob> blobs;
  final double elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = elapsed / 1000;
    for (final b in blobs) {
      b.x += math.sin(ms * 0.3 + b.phase) * b.driftX * 0.5;
      b.y += math.cos(ms * 0.2 + b.phase * 1.3) * b.driftY * 0.5;

      // Clamp to visible area
      b.x = b.x.clamp(-0.2, 1.2);
      b.y = b.y.clamp(-0.2, 1.2);

      final cx = b.x * size.width;
      final cy = b.y * size.height;

      final paint = Paint()
        ..color = b.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
      canvas.drawCircle(Offset(cx, cy), b.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter old) => true;
}