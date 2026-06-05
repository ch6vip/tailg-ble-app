import 'package:flutter/material.dart';

abstract final class AppColors {
  // 极简高端主操作色：黑。原亮蓝 #5596FF 已统一为黑色主操作。
  static const primary = Color(0xFF1A1A1A);
  static const primaryDark = Color(0xFF000000);
  static const pageBg = Color(0xFFFAFAF8);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF666666);
  static const textTertiary = Color(0xFFBBBBBB);
  static const border = Color(0xFFF0F0F0);
  static const success = Color(0xFF00A896);
  static const warning = Color(0xFFFF9800);
  static const danger = Color(0xFFFF5252);
  static const info = Color(0xFF2196F3);
  static const navInactive = Color(0xFFCCCCCC);

  /// 官方品牌红，仅复刻保真场景使用。
  static const brandRed = Color(0xFFF11C2C);

  /// 深色主操作色（极简高端风格滑块/按钮）。
  static const dark = Color(0xFF1A1A1A);

  /// 快捷功能图标强调色。
  static const accentPurple = Color(0xFF7B61FF);
  static const accentTeal = Color(0xFF00A896);
  static const accentOrange = Color(0xFFFF8A00);
}

abstract final class ReplicaColors {
  static const pageBg = Color(0xFFFAFAF8);
  static const lightPageBg = Color(0xFFFAFAF8);
  static const ink = Color(0xFF1A1A1A);
  static const panelInk = Color(0xFF1A1A1A);
  static const secondary = Color(0xFF666666);
  static const muted = Color(0xFFBBBBBB);
  static const subtle = Color(0xFF999999);
  static const line = Color(0xFFF0F0F0);
  static const blue = Color(0xFF1A1A1A);
  static const darkPanel = Color(0xFF1A1A1A);
  static const darkPanelDown = Color(0xFF111111);
  static const darkPanelItem = Color(0x33999999);
}

/// 车体 painter 专用灰阶 token（replica 复刻保真）。
abstract final class ReplicaBikeColors {
  /// 车架主色（深炭）
  static const frame = Color(0xFF2A2D35);

  /// 轮圈细描边
  static const rim = Color(0xFF252525);

  /// 电池深色底块
  static const battery = Color(0xFF121418);

  /// 阴影/反射浅灰
  static const shadow = Color(0xFFDDE3EC);

  /// 场景浅底
  static const surface = Color(0xFFF0F3F8);

  /// 通用浅灰（车把等小部件）
  static const handle = Color(0xFFD9DEE8);

  /// 停车场场景绿地
  static const parking = Color(0xFFDDE7D8);
}

abstract final class ReplicaRadii {
  static const card = 8.0;
  static const sheet = 18.0;
  static const pill = 999.0;
}

abstract final class AppRadii {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const card = 12.0;
  static const tile = 8.0;
  static const sheet = 18.0;
  static const pill = 999.0;
}

abstract final class AppShadows {
  static const card = Color(0x06000000);
  static const cardBlur = 16.0;
  static const cardOffsetY = 4.0;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: card,
      blurRadius: cardBlur,
      offset: Offset(0, cardOffsetY),
    ),
  ];
}

abstract final class AppSpacing {
  static const screenX = 20.0;
  static const sectionGap = 20.0;
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
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textTertiary,
    letterSpacing: 1.5,
  );

  static const dialogTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const itemTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const bodyMedium = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );

  static const valueText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const smallText = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static const caption = TextStyle(fontSize: 12, color: AppColors.textTertiary);
}

const cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
  border: Border.fromBorderSide(BorderSide(color: AppColors.border, width: 1)),
);
