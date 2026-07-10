import 'package:flutter/animation.dart';

/// Centralised motion tokens for the Tailg app.
///
/// Current design notes live in `docs/design_system.md`.
/// Replace hardcoded `Duration` / `Curve` literals with these constants
/// to keep animations consistent and tunable from a single source.
abstract final class AppMotion {
  // ── Durations ──────────────────────────────────────────────────────────

  /// Instant feedback (ripple, highlight). ~100 ms.
  static const instant = Duration(milliseconds: 100);

  /// Micro-interaction (press scale, toggle snap). ~150 ms.
  static const micro = Duration(milliseconds: 150);

  /// Standard transition (fade, slide, colour tween). ~250 ms.
  static const standard = Duration(milliseconds: 250);

  /// Toast entrance transition. ~300 ms.
  static const toastEntrance = Duration(milliseconds: 300);

  /// Toast visible period before auto-dismiss. ~1800 ms.
  static const toastVisible = Duration(milliseconds: 1800);

  /// Page-level tab indicator transition. ~200 ms.
  static const tabIndicator = Duration(milliseconds: 200);

  /// Emphasis / page-level transition. ~350 ms.
  static const emphasis = Duration(milliseconds: 350);

  /// Slow reveal (hero, onboarding, empty states). ~500 ms.
  static const reveal = Duration(milliseconds: 500);

  /// Long-press hold timeout (power knob). 1200 ms.
  static const longPressHold = Duration(milliseconds: 1200);

  /// Pulse / breathing loop period.
  static const pulsePeriod = Duration(milliseconds: 1200);

  // ── Curves ────────────────────────────────────────────────────────────

  /// Default press / release curve — snappy but not abrupt.
  static const pressCurve = Curves.easeOutCubic;

  /// Page entrance — gentle deceleration.
  static const entranceCurve = Curves.easeOutCubic;

  /// Page exit — gentle acceleration.
  static const exitCurve = Curves.easeInCubic;

  /// Progress / indeterminate — linear for accuracy.
  static const progressCurve = Curves.linear;

  /// Pulse / breathing — smooth in-out.
  static const pulseCurve = Curves.easeInOut;

  // ── Scale presets ─────────────────────────────────────────────────────

  /// Pressed-down scale factor.
  static const pressScale = 0.96;

  /// Pulse min scale (breathing dot).
  static const pulseMin = 0.75;

  /// Pulse max scale (breathing dot).
  static const pulseMax = 1.1;
}
