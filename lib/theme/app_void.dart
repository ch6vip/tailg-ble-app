import 'package:flutter/material.dart';

/// VOID COCKPIT — Awwwards-grade design tokens.
///
/// Dark-first immersive canvas. Energy emerald as the single brand pulse.
/// No emoji. Icons via Lucide only (see widgets/lucide_icon.dart).
abstract final class VoidColors {
  // ── Void field ──────────────────────────────────────────────────────────
  static const voidDeep = Color(0xFF05070B);
  static const voidMid = Color(0xFF0A0E14);
  static const voidLift = Color(0xFF11161F);
  static const voidPanel = Color(0xFF151B26);
  static const voidPanelHi = Color(0xFF1C2433);

  // ── Energy ──────────────────────────────────────────────────────────────
  static const energy = Color(0xFF00FFB2);
  static const energyDim = Color(0xFF00C896);
  static const energySoft = Color(0x3300FFB2);
  static const energyGlow = Color(0x5500FFB2);
  static const energyAmber = Color(0xFFFFB84D);
  static const energyRed = Color(0xFFFF4D6A);

  // ── Type ────────────────────────────────────────────────────────────────
  static const ink = Color(0xFFF4F6FA);
  static const inkMuted = Color(0xFF8B93A7);
  static const inkFaint = Color(0xFF5A6278);
  static const inkGhost = Color(0xFF3A4154);

  // ── Hairlines / glass ───────────────────────────────────────────────────
  static const hairline = Color(0x22FFFFFF);
  static const hairlineStrong = Color(0x33FFFFFF);
  static const glass = Color(0x14FFFFFF);
  static const glassStrong = Color(0x22FFFFFF);

  // ── Light-mode companions (when system light) ───────────────────────────
  static const lightVoid = Color(0xFFF3F5F8);
  static const lightPanel = Color(0xFFFFFFFF);
  static const lightInk = Color(0xFF0B1220);
  static const lightInkMuted = Color(0xFF5C667A);
  static const lightHairline = Color(0x140B1220);
}

abstract final class VoidRadii {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const pill = 999.0;
}

abstract final class VoidSpace {
  static const screenX = 22.0;
  static const section = 28.0;
  static const card = 18.0;
  static const tight = 8.0;
  static const micro = 4.0;
}

abstract final class VoidType {
  /// Massive display figure (battery %, range).
  static const display = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.w300,
    height: 0.9,
    letterSpacing: -2.4,
    color: VoidColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Secondary display (smaller metrics).
  static const displaySm = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    height: 1.0,
    letterSpacing: -1.0,
    color: VoidColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Hero page title — experimental tracking.
  static const hero = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: -0.6,
    color: VoidColors.ink,
  );

  /// Micro label — uppercase-feel via wide tracking (keep Chinese as-is).
  static const micro = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 1.6,
    color: VoidColors.inkFaint,
  );

  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: VoidColors.inkMuted,
  );

  static const bodyStrong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: VoidColors.ink,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: VoidColors.inkMuted,
  );
}

abstract final class VoidMotion {
  static const snap = Duration(milliseconds: 140);
  static const soft = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 480);
  static const breathe = Duration(milliseconds: 2400);
  static const ring = Duration(milliseconds: 900);

  static const outExpo = Cubic(0.16, 1, 0.3, 1);
  static const inOutSoft = Cubic(0.65, 0, 0.35, 1);
  static const springy = Cubic(0.34, 1.4, 0.64, 1);

  static const pressScale = 0.97;
}

abstract final class VoidGlow {
  static List<BoxShadow> energy({double intensity = 1}) => [
    BoxShadow(
      color: VoidColors.energy.withValues(alpha: 0.18 * intensity),
      blurRadius: 32 * intensity,
      spreadRadius: -4,
    ),
    BoxShadow(
      color: VoidColors.energy.withValues(alpha: 0.08 * intensity),
      blurRadius: 64 * intensity,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> panel = const [
    BoxShadow(color: Color(0x40000000), blurRadius: 28, offset: Offset(0, 12)),
  ];

  static List<BoxShadow> float = const [
    BoxShadow(color: Color(0x55000000), blurRadius: 40, offset: Offset(0, 16)),
  ];
}
