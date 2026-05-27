import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF1E88E5);
  static const primaryDark = Color(0xFF1565C0);
  static const pageBg = Color(0xFFF5F6FA);
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF666666);
  static const textTertiary = Color(0xFF999999);
  static const border = Color(0xFFEEEEEE);
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFF9800);
  static const danger = Color(0xFFFF5252);
  static const info = Color(0xFF2196F3);
  static const navInactive = Color(0xFFBDBDBD);
}

abstract final class AppRadii {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const pill = 28.0;
}

abstract final class AppSpacing {
  static const screenX = 20.0;
  static const sectionGap = 16.0;
}

abstract final class AppNav {
  static const barBaseHeight = 82.0;
  static const contentBottomPadding = 104.0;
}

abstract final class AppTextStyles {
  static const pageTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const subPageTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const sectionLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
}

const cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
  boxShadow: [
    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
  ],
);
