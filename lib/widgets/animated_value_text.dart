import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// A stable text slot for values that change after a cloud or vehicle refresh.
class AnimatedValueText extends StatelessWidget {
  const AnimatedValueText(
    this.value, {
    super.key,
    required this.style,
    this.unit,
    this.unitStyle,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String value;
  final TextStyle style;
  final String? unit;
  final TextStyle? unitStyle;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final text = unit == null
        ? Text(
            value,
            key: ValueKey(value),
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
            style: style,
          )
        : Text.rich(
            key: ValueKey((value, unit)),
            TextSpan(
              children: [
                TextSpan(text: value, style: style),
                TextSpan(text: unit, style: unitStyle ?? style),
              ],
            ),
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
          );
    if (MediaQuery.of(context).disableAnimations) return text;
    return AnimatedSwitcher(
      duration: AppMotion.dataChange,
      switchInCurve: AppMotion.entranceCurve,
      switchOutCurve: AppMotion.exitCurve,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.16),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: text,
    );
  }
}
