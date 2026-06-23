import 'package:flutter/material.dart';

abstract final class AppColors {
  // 主操作色：v8 翡翠绿（Aurora Cockpit 设计语言）。原黑色 #1A1A1A 已下线为
  // 主操作；纯黑仍保留在 [dark] token 上用于高对比深色表面（电池详情、骑行模式）。
  static const primary = Color(0xFF00C896);
  static const primaryDark = Color(0xFF00A57C);
  static const pageBg = Color(0xFFF5F5F7); // M3: slightly cooler, more modern
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF666666);
  static const textTertiary = Color(0xFF8A8A8A);
  static const border = Color(0xFFEBEBEB);
  static const success = Color(0xFF00A896);
  static const warning = Color(0xFFFF9800);
  static const danger = Color(0xFFFF5252);
  // 信息提示色统一为极简高端 teal（原 #2196F3 蓝已下线）。类别色冲突处
  // （骑行模式 standard、电池 BLE 来源 chip）已就地改用其它 token 以保持区分。
  static const info = Color(0xFF00A896);
  static const navInactive = Color(0xFF929292);

  /// 官方品牌红，仅复刻保真场景使用。
  static const brandRed = Color(0xFFF11C2C);

  /// 深色主操作色（极简高端风格滑块/按钮）。
  static const dark = Color(0xFF1A1A1A);

  /// 快捷功能图标强调色。
  static const accentPurple = Color(0xFF7B61FF);
  static const accentTeal = Color(0xFF00A896);
  static const accentOrange = Color(0xFFFF8A00);

  // ── Material 3 surface tokens ──────────────────────────────────────────
  /// Card / elevated surface (pure white on light theme).
  static const surface = Color(0xFFFFFFFF);

  /// Subtle tinted background for nested containers.
  static const surfaceContainerLow = Color(0xFFF8F8FA);

  /// Slightly stronger tint for pressed / hovered states.
  static const surfaceContainerHigh = Color(0xFFF0F0F4);

  /// Outline variant: lighter than [border], for dividers and hairlines.
  static const outlineVariant = Color(0xFFE8E8EC);

  /// Dark surface for contrast panels (e.g., battery detail dark card).
  static const darkSurface = Color(0xFF1A1A1A);
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

  // ── Material 3 elevation system ────────────────────────────────────────
  /// Level 1: subtle lift for cards resting on page background.
  static const List<BoxShadow> elevation1 = [
    BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x04000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Level 2: medium lift for floating panels and active cards.
  static const List<BoxShadow> elevation2 = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  /// Level 3: strong lift for FABs, dialogs, and overlays.
  static const List<BoxShadow> elevation3 = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 3)),
  ];
}

abstract final class AppSpacing {
  static const screenX = 20.0;
  static const sectionGap = 20.0;
  // M3: tighter card padding for more content density
  static const cardPadding = 16.0;
  static const cardGap = 12.0;
  static const sectionTop = 16.0;
}

/// Icon size tokens: sm → md → lg → xl four-tier hierarchy.
abstract final class AppIconSizes {
  /// Inline text, status badges, compact list items.
  static const sm = 16.0;

  /// List leading icons, settings tile icons.
  static const md = 20.0;

  /// Grid entries, bottom navigation, tab bar icons, action buttons.
  static const lg = 24.0;

  /// Empty states, hero illustrations, large decorative icons.
  static const xl = 48.0;
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

  static const bodySmall = TextStyle(
    fontSize: 13,
    color: AppColors.textTertiary,
  );

  static const bodyLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const cardTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const sectionLabelStrong = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textTertiary,
  );
}

/// Default card decoration: M3 elevated surface (no border, soft shadow).
const cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
  boxShadow: AppShadows.elevation1,
);
