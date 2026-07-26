import 'package:flutter/material.dart';

/// Central motion accessibility policy for one-shot and continuous effects.
abstract final class MotionPolicy {
  static bool reduceMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static bool loopsEnabled(BuildContext context) {
    return !reduceMotion(context) && TickerMode.valuesOf(context).enabled;
  }

  static Duration duration(BuildContext context, Duration normal) {
    return reduceMotion(context) ? Duration.zero : normal;
  }
}
