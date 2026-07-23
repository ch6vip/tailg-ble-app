import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../theme/app_void.dart';

/// VoidGlassCard — 玻璃态卡片组件
///
/// 使用 BackdropFilter 产生毛玻璃效果，支持能量色发光边框和内嵌微光。
/// 对标 Awwwards 级沉浸式 UI 层。
class VoidGlassCard extends StatelessWidget {
  const VoidGlassCard({
    super.key,
    required this.child,
    this.margin,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 20,
    this.blurSigma = 12,
    this.glowColor,
    this.glowOpacity = 0.15,
    this.borderColor,
    this.borderWidth = 1,
    this.elevation = 0,
    this.clip = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;
  final Color? glowColor;
  final double glowOpacity;
  final Color? borderColor;
  final double borderWidth;
  final double elevation;
  final bool clip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final effectiveGlow =
        glowColor ??
        (dark ? VoidColors.energy : VoidColors.energyDim);
    final effectiveBorder =
        borderColor ??
        (dark
            ? const Color(0x2AFFFFFF)
            : const Color(0x1A0B1220));

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: dark
                ? const Color(0x1A151B26)
                : const Color(0xCCFFFFFF),
            border: Border.all(
              color: effectiveBorder,
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: effectiveGlow.withValues(alpha: glowOpacity * 0.3),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
              if (elevation > 0)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08 * elevation),
                  blurRadius: 8 + 4 * elevation,
                  offset: Offset(0, 2 + elevation),
                ),
            ],
          ),
          padding: padding,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }

    return card;
  }
}

/// VoidGlassPanel — 全宽玻璃面板，用于页面 section 容器
class VoidGlassPanel extends StatelessWidget {
  const VoidGlassPanel({
    super.key,
    required this.child,
    this.margin,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    this.blurSigma = 8,
    this.glowColor,
    this.glowOpacity = 0.10,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final double blurSigma;
  final Color? glowColor;
  final double glowOpacity;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final panel = ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: dark
                ? const Color(0x0AFFFFFF)
                : const Color(0x080B1220),
            border: Border(
              bottom: BorderSide(
                color: dark
                    ? const Color(0x1AFFFFFF)
                    : const Color(0x0A0B1220),
                width: 0.5,
              ),
            ),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );

    if (margin != null) {
      return Padding(padding: margin!, child: panel);
    }
    return panel;
  }
}