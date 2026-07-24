import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_void.dart';

/// Kinetic typography — experimental display text with entrance animation.
///
/// Each character animates in with staggered scale + fade + slide.
/// Two modes: [KineticTypeMode.sequential] char-by-char, or
/// [KineticTypeMode.word] word-by-word.
///
/// Set [enableAnimation] to false to disable entrance animation (e.g. in tests).
enum KineticTypeMode { sequential, word, block }

class KineticType extends StatefulWidget {
  const KineticType(
    this.text, {
    super.key,
    this.style,
    this.mode = KineticTypeMode.sequential,
    this.staggerDelay = 32,
    this.duration = const Duration(milliseconds: 420),
    this.curve = Curves.easeOutBack,
    this.autoPlay = true,
    this.alignment = TextAlign.left,
    this.maxLines,
    this.overflow,
  });

  /// Set to false to disable entrance animation (e.g. in tests).
  static bool enableAnimation = true;

  final String text;
  final TextStyle? style;
  final KineticTypeMode mode;
  final int staggerDelay;
  final Duration duration;
  final Curve curve;
  final bool autoPlay;
  final TextAlign alignment;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<KineticType> createState() => _KineticTypeState();
}

class _KineticTypeState extends State<KineticType>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<Animation<double>> _itemAnims = [];
  List<String> _items = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _buildItems();
    if (widget.autoPlay && KineticType.enableAnimation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_controller.forward());
      });
    }
  }

  @override
  void didUpdateWidget(KineticType old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.mode != widget.mode) {
      _buildItems();
      if (widget.autoPlay && KineticType.enableAnimation) {
        unawaited(_controller.forward(from: 0));
      }
    }
  }

  void _buildItems() {
    _itemAnims.clear();
    switch (widget.mode) {
      case KineticTypeMode.sequential:
        _items = widget.text.characters.toList();
      case KineticTypeMode.word:
        _items = widget.text.split(' ');
      case KineticTypeMode.block:
        _items = [widget.text];
    }
    final totalDuration = Duration(
      milliseconds:
          widget.duration.inMilliseconds + _items.length * widget.staggerDelay,
    );
    _controller.duration = totalDuration;
    for (var i = 0; i < _items.length; i++) {
      final start = (i * widget.staggerDelay) / totalDuration.inMilliseconds;
      final end =
          (widget.duration.inMilliseconds + i * widget.staggerDelay) /
          totalDuration.inMilliseconds;
      _itemAnims.add(
        _controller.drive(
          Tween<double>(begin: 0, end: 1).chain(
            CurveTween(
              curve: Interval(
                start.clamp(0.0, 1.0),
                end.clamp(0.0, 1.0),
                curve: widget.curve,
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    // When animations are disabled, render plain text to avoid
    // invisible widgets (the controller never starts, so anim values
    // remain at 0 — opacity 0, scale 0.4).
    if (!KineticType.enableAnimation) {
      return Text(
        widget.text,
        style: widget.style,
        textAlign: widget.alignment,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (widget.mode == KineticTypeMode.block) {
          return Opacity(
            opacity: _itemAnims.isNotEmpty
                ? _itemAnims[0].value.clamp(0.0, 1.0)
                : 0,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translateByDouble(
                  0,
                  (1 - (_itemAnims.isNotEmpty ? _itemAnims[0].value : 0)) * 30,
                  0,
                  0,
                ),
              child: Text(
                widget.text,
                style: widget.style,
                textAlign: widget.alignment,
                maxLines: widget.maxLines,
                overflow: widget.overflow,
              ),
            ),
          );
        }

        final children = <Widget>[];
        for (var i = 0; i < _items.length; i++) {
          final anim = _itemAnims[i];
          children.add(
            Opacity(
              opacity: anim.value.clamp(0.0, 1.0),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scaleByDouble(
                    0.4 + 0.6 * anim.value,
                    0.4 + 0.6 * anim.value,
                    0.4 + 0.6 * anim.value,
                    1,
                  )
                  ..translateByDouble(0, (1 - anim.value) * 20, 0, 1),
                child: Text(
                  widget.mode == KineticTypeMode.word ? _items[i] : _items[i],
                  style: widget.style,
                ),
              ),
            ),
          );
        }
        return DefaultTextStyle(
          style: widget.style ?? const TextStyle(),
          child: Wrap(
            alignment:
                WrapAlignment.values[widget.alignment.index.clamp(
                  0,
                  WrapAlignment.values.length - 1,
                )],
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: children,
          ),
        );
      },
    );
  }
}

/// Glowing display text with energy neon effect.
class VoidGlowText extends StatelessWidget {
  const VoidGlowText(
    this.text, {
    super.key,
    this.style,
    this.glowColor = VoidColors.energy,
    this.glowIntensity = 1.0,
    this.textAlign,
    this.maxLines,
  });

  final String text;
  final TextStyle? style;
  final Color glowColor;
  final double glowIntensity;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Glow layer
        Text(
          text,
          maxLines: maxLines,
          textAlign: textAlign,
          style: (style ?? const TextStyle()).copyWith(
            color: glowColor.withValues(alpha: 0.3 * glowIntensity),
            shadows: [
              Shadow(
                color: glowColor.withValues(alpha: 0.4 * glowIntensity),
                blurRadius: 12 * glowIntensity,
              ),
              Shadow(
                color: glowColor.withValues(alpha: 0.2 * glowIntensity),
                blurRadius: 24 * glowIntensity,
              ),
              Shadow(
                color: glowColor.withValues(alpha: 0.1 * glowIntensity),
                blurRadius: 48 * glowIntensity,
              ),
            ],
          ),
        ),
        // Core text
        Text(text, maxLines: maxLines, textAlign: textAlign, style: style),
      ],
    );
  }
}

/// Animated metric counter — counts from 0 to target with energy pulse.
class VoidMetricCounter extends StatefulWidget {
  const VoidMetricCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 1200),
    this.curve = Curves.easeOutCubic,
    this.prefix = '',
    this.suffix = '',
    this.decimalPlaces = 0,
    this.autoPlay = true,
  });

  final double value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final String prefix;
  final String suffix;
  final int decimalPlaces;
  final bool autoPlay;

  @override
  State<VoidMetricCounter> createState() => _VoidMetricCounterState();
}

class _VoidMetricCounterState extends State<VoidMetricCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;
  double _displayValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _anim = _controller.drive(CurveTween(curve: widget.curve));
    _controller.addListener(() {
      setState(() => _displayValue = _anim.value * widget.value);
    });
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_controller.forward());
      });
    }
  }

  @override
  void didUpdateWidget(VoidMetricCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      unawaited(_controller.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatted = _displayValue.toStringAsFixed(widget.decimalPlaces);
    return Text(
      '${widget.prefix}$formatted${widget.suffix}',
      style: widget.style?.copyWith(
        fontFeatures: [
          const FontFeature.tabularFigures(),
          ...?widget.style?.fontFeatures,
        ],
      ),
    );
  }
}

/// Animated section divider — energy line that draws in.
class VoidDivider extends StatefulWidget {
  const VoidDivider({
    super.key,
    this.color = VoidColors.energy,
    this.height = 1.5,
    this.width = 60,
    this.margin = const EdgeInsets.symmetric(vertical: 16),
  });

  final Color color;
  final double height;
  final double width;
  final EdgeInsetsGeometry margin;

  @override
  State<VoidDivider> createState() => _VoidDividerState();
}

class _VoidDividerState extends State<VoidDivider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = _controller.drive(CurveTween(curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller.forward());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          margin: widget.margin,
          height: widget.height,
          width: widget.width * _anim.value,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.height / 2),
            gradient: LinearGradient(
              colors: [
                widget.color.withValues(alpha: 0),
                widget.color.withValues(alpha: 0.8),
                widget.color.withValues(alpha: 0),
              ],
            ),
          ),
        );
      },
    );
  }
}
