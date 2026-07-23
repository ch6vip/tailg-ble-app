import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_void.dart';
import 'void_particles.dart';

/// Full-bleed immersive void field with soft energy nebula.
class VoidCanvas extends StatelessWidget {
  const VoidCanvas({
    super.key,
    required this.child,
    this.intensity = 1.0,
    this.lightMode = false,
    this.particleCount = 32,
    this.showParticles = true,
  });

  final Widget child;
  final double intensity;
  final bool lightMode;
  final int particleCount;
  final bool showParticles;

  @override
  Widget build(BuildContext context) {
    final dark = !lightMode && Theme.of(context).brightness == Brightness.dark;
    // Force void aesthetic in both modes — light gets cool grey field.
    final top = dark ? VoidColors.voidDeep : const Color(0xFFE8ECF2);
    final bot = dark ? VoidColors.voidMid : const Color(0xFFF6F7FA);
    final glow = dark
        ? VoidColors.energy.withValues(alpha: 0.14 * intensity)
        : VoidColors.energyDim.withValues(alpha: 0.10 * intensity);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bot],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Volumetric particle field — deepest layer
          if (showParticles)
            Positioned.fill(
              child: IgnorePointer(
                child: VoidParticleField(
                  particleCount: particleCount,
                  energyColor: dark
                      ? VoidColors.energy
                      : VoidColors.energyDim,
                  driftSpeed: 0.06,
                  scale: intensity,
                ),
              ),
            ),
          // Top-right energy nebula
          Positioned(
            top: -80,
            right: -60,
            child: _Blob(size: 280, color: glow),
          ),
          // Bottom-left cooler nebula
          Positioned(
            bottom: 80,
            left: -100,
            child: _Blob(
              size: 320,
              color: (dark ? const Color(0xFF2E9BFF) : const Color(0xFF7C6CFF))
                  .withValues(alpha: 0.08 * intensity),
            ),
          ),
          // Fine grain noise overlay (cheap: low-opacity white dots via CustomPaint)
          const Positioned.fill(child: IgnorePointer(child: _Grain())),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _Grain extends StatelessWidget {
  const _Grain();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GrainPainter());
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x08FFFFFF);
    final rnd = math.Random(7);
    final count = (size.width * size.height / 1800).clamp(40, 220).toInt();
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Frosted glass panel with hairline edge.
class VoidGlass extends StatelessWidget {
  const VoidGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(VoidSpace.card),
    this.margin = EdgeInsets.zero,
    this.radius = VoidRadii.lg,
    this.border = true,
    this.blur = true,
    this.glow = false,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final bool border;
  final bool blur;
  final bool glow;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill =
        color ??
        (dark
            ? VoidColors.voidPanel.withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.82));
    final edge = dark ? VoidColors.hairline : VoidColors.lightHairline;

    final panel = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: edge, width: 1) : null,
        boxShadow: glow
            ? VoidGlow.energy(intensity: 0.6)
            : (dark ? VoidGlow.panel : const []),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (!blur) return panel;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: panel,
      ),
    );
  }
}

/// Kinetic battery ring — experimental hero visualization.
class VoidEnergyRing extends StatefulWidget {
  const VoidEnergyRing({
    super.key,
    required this.percent,
    this.size = 196,
    this.stroke = 8,
    this.label,
    this.sublabel,
  });

  final double percent; // 0–100
  final double size;
  final double stroke;
  final String? label;
  final String? sublabel;

  @override
  State<VoidEnergyRing> createState() => _VoidEnergyRingState();
}

class _VoidEnergyRingState extends State<VoidEnergyRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: VoidMotion.breathe);
    unawaited(_pulse.repeat(reverse: true));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.percent.clamp(0.0, 100.0);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? VoidColors.ink : VoidColors.lightInk;
    final muted = dark ? VoidColors.inkMuted : VoidColors.lightInkMuted;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final glowBoost = 0.7 + _pulse.value * 0.3;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Soft ambient glow under the ring
              Container(
                width: widget.size * 0.72,
                height: widget.size * 0.72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: VoidGlow.energy(intensity: glowBoost),
                ),
              ),
              CustomPaint(
                size: Size.square(widget.size),
                painter: _RingPainter(
                  progress: p / 100,
                  stroke: widget.stroke,
                  track: dark
                      ? VoidColors.voidPanelHi
                      : const Color(0xFFE2E6EE),
                  energy: p < 15
                      ? VoidColors.energyRed
                      : (p < 35 ? VoidColors.energyAmber : VoidColors.energy),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p <= 0 && widget.label == null
                        ? '--'
                        : (widget.label ?? p.round().toString()),
                    style: VoidType.display.copyWith(
                      fontSize: widget.size * 0.28,
                      color: ink,
                    ),
                  ),
                  if (widget.sublabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.sublabel!,
                      style: VoidType.micro.copyWith(color: muted),
                    ),
                  ] else ...[
                    const SizedBox(height: 2),
                    Text(
                      '%',
                      style: VoidType.micro.copyWith(
                        color: muted,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.stroke,
    required this.track,
    required this.energy,
  });

  final double progress;
  final double stroke;
  final Color track;
  final Color energy;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    if (progress <= 0) return;

    final energyPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = energy
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4);

    // Start at top (-pi/2), sweep clockwise.
    const start = -math.pi / 2;
    final sweep = math.pi * 2 * progress;
    canvas.drawArc(rect, start, sweep, false, energyPaint);

    // Leading tip glow
    final tip = Offset(
      c.dx + r * math.cos(start + sweep),
      c.dy + r * math.sin(start + sweep),
    );
    canvas.drawCircle(
      tip,
      stroke * 0.55,
      Paint()
        ..color = energy.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.stroke != stroke ||
      old.track != track ||
      old.energy != energy;
}

/// Experimental section label — thin rule + wide-tracked micro text.
class VoidSectionLabel extends StatelessWidget {
  const VoidSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? VoidColors.inkFaint : VoidColors.lightInkMuted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VoidSpace.screenX,
        VoidSpace.section,
        VoidSpace.screenX,
        VoidSpace.tight,
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 1.5,
            color: VoidColors.energy.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 10),
          Text(text, style: VoidType.micro.copyWith(color: muted)),
        ],
      ),
    );
  }
}

/// Massive kinetic headline used on empty / gate states.
class VoidHeadline extends StatelessWidget {
  const VoidHeadline({
    super.key,
    required this.title,
    this.subtitle,
    this.align = TextAlign.left,
  });

  final String title;
  final String? subtitle;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? VoidColors.ink : VoidColors.lightInk;
    final muted = dark ? VoidColors.inkMuted : VoidColors.lightInkMuted;
    return Column(
      crossAxisAlignment: align == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: align,
          style: VoidType.hero.copyWith(color: ink, fontSize: 32),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            textAlign: align,
            style: VoidType.body.copyWith(color: muted),
          ),
        ],
      ],
    );
  }
}

/// Metric tile — large tabular figure + micro label.
class VoidMetric extends StatelessWidget {
  const VoidMetric({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.accent = false,
  });

  final String value;
  final String label;
  final String? unit;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? VoidColors.ink : VoidColors.lightInk;
    final muted = dark ? VoidColors.inkFaint : VoidColors.lightInkMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: VoidType.micro.copyWith(color: muted),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VoidType.displaySm.copyWith(
                  fontSize: 26,
                  color: accent ? VoidColors.energy : ink,
                ),
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit!,
                  style: VoidType.caption.copyWith(color: muted, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
