import 'package:flutter/material.dart';

/// Light-mode color tokens for the Tailg BLE app.
///
/// Use [AppColors.of] to resolve the correct token set for the current
/// [ThemeMode], or reference static members directly when you are certain
/// the app is in light mode (e.g. inside a `Theme` with `Brightness.light`).
///
/// ## Green token mapping
/// | Token          | Value          | Preferred for                                       |
/// |----------------|----------------|------------------------------------------------------|
/// | [success]      | `#00A896`      | Operation confirmation, "healthy" status             |
/// | [energyGreen]  | `#00C896`      | Battery / energy indicators (v8 brand green)         |
/// | [info]         | alias of success | Backward compat — use [success] for new code       |
/// | [accentTeal]   | alias of success | Backward compat — use [success] for new code       |
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

  /// 官方台铃 App 首页浅灰底色（APK: `ceff0f5`）。
  static const officialPageBg = Color(0xFFEFF0F5);

  /// 官方台铃 App 次级文字色（APK: `c807e89`）。
  static const officialTextMuted = Color(0xFF807E89);

  /// 深色主操作色（极简高端风格滑块/按钮）。
  static const dark = Color(0xFF1A1A1A);

  /// 快捷功能图标强调色。
  static const accentPurple = Color(0xFF7B61FF);
  static const accentTeal = Color(0xFF00A896);
  static const accentOrange = Color(0xFFFF8A00);

  // ── v8 accent tokens (see docs/design_system.md) ──────────────────────
  static const accentViolet = Color(0xFF7C6CFF);
  static const accentSky = Color(0xFF2E9BFF);
  static const accentAmber = Color(0xFFF5A623);

  // ── v8 surface tokens ──────────────────────────────────────────────────
  static const card2 = Color(0xFFF2F5F8);
  static const card3 = Color(0xFFE8ECF1);
  static const energySoft = Color(0x1F00C896);
  static const hairline = Color(0x120F1620);
  static const hairline2 = Color(0x1A0F1620);

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

  // ── v8 Ninebot tokens ──────────────────────────────────────────────────
  /// Page top background (cool teal-tinted light, v8 radial gradient top).
  static const pageBgTop = Color(0xFFE9EEF4);

  /// Page bottom background (warm light grey, v8 gradient bottom).
  static const pageBgBot = Color(0xFFF6F8FB);

  /// Deep ink button primary (Ninebot-style central knob).
  static const inkBtn = Color(0xFF1B2230);

  /// Lighter ink button variant (hover / secondary).
  static const inkBtn2 = Color(0xFF2A3342);

  /// Teal tinted surface (brand-coloured card background).
  static const surfaceBrandTint = Color(0xFFF0FAF8);

  /// Red soft surface (warning/alert card background).
  static const surfaceBrandRedTint = Color(0xFFFFF1F2);

  /// Amber soft surface (reconnecting/warning card background).
  static const surfaceBrandAmberTint = Color(0xFFFFF4D6);

  /// Teal soft surface (info/connected card background).
  static const surfaceBrandTealTint = Color(0xFFE5F6F4);

  /// Energy / battery green.
  static const energyGreen = Color(0xFF00C896);

  /// Energy amber (medium battery).
  static const energyAmber = Color(0xFFF5A623);

  /// Energy red (low battery).
  static const energyRed = Color(0xFFFF4D5E);

  // ── Theme-aware factory ──────────────────────────────────────────────

  /// Returns light or dark color tokens based on the ambient [Theme].
  ///
  /// Usage: `final c = AppColors.of(context);`
  /// Then use `c.primary`, `c.surface`, etc.
  static AppColorsData of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? AppColorsDark.instance
        : AppColorsLight.instance;
  }
}

/// Typed container for resolved color tokens.
abstract class AppColorsData {
  const AppColorsData();
  Color get primary;
  Color get primaryDark;
  Color get pageBg;
  Color get textPrimary;
  Color get textSecondary;
  Color get textTertiary;
  Color get border;
  Color get success;
  Color get warning;
  Color get danger;
  Color get surface;
  Color get surfaceContainerLow;
  Color get surfaceContainerHigh;
  Color get outlineVariant;
  Color get darkSurface;
  Color get energyGreen;
  Color get energyAmber;
  Color get energyRed;
  Color get inkBtn;
  Color get inkBtn2;
  Color get accentSky;
  Color get accentViolet;
  Color get accentAmber;
  Color get accentPurple;
  Color get accentOrange;
  Color get brandRed;
  Color get pageBgTop;
  Color get pageBgBot;
}

/// Light-mode token set (current default).
class AppColorsLight extends AppColorsData {
  const AppColorsLight._();
  static const instance = AppColorsLight._();

  @override
  Color get primary => AppColors.primary;
  @override
  Color get primaryDark => AppColors.primaryDark;
  @override
  Color get pageBg => AppColors.pageBg;
  @override
  Color get textPrimary => AppColors.textPrimary;
  @override
  Color get textSecondary => AppColors.textSecondary;
  @override
  Color get textTertiary => AppColors.textTertiary;
  @override
  Color get border => AppColors.border;
  @override
  Color get success => AppColors.success;
  @override
  Color get warning => AppColors.warning;
  @override
  Color get danger => AppColors.danger;
  @override
  Color get surface => AppColors.surface;
  @override
  Color get surfaceContainerLow => AppColors.surfaceContainerLow;
  @override
  Color get surfaceContainerHigh => AppColors.surfaceContainerHigh;
  @override
  Color get outlineVariant => AppColors.outlineVariant;
  @override
  Color get darkSurface => AppColors.darkSurface;
  @override
  Color get energyGreen => AppColors.energyGreen;
  @override
  Color get energyAmber => AppColors.energyAmber;
  @override
  Color get energyRed => AppColors.energyRed;
  @override
  Color get inkBtn => AppColors.inkBtn;
  @override
  Color get inkBtn2 => AppColors.inkBtn2;
  @override
  Color get accentSky => AppColors.accentSky;
  @override
  Color get accentViolet => AppColors.accentViolet;
  @override
  Color get accentAmber => AppColors.accentAmber;
  @override
  Color get accentPurple => AppColors.accentPurple;
  @override
  Color get accentOrange => AppColors.accentOrange;
  @override
  Color get brandRed => AppColors.brandRed;
  @override
  Color get pageBgTop => AppColors.pageBgTop;
  @override
  Color get pageBgBot => AppColors.pageBgBot;
}

/// Dark-mode token set.
///
/// Dark-mode token notes are tracked in `docs/design_system.md`:
/// - Backgrounds invert to deep charcoal
/// - Foreground colours are lightened and slightly desaturated
/// - Brand accent stays vivid but with adjusted contrast
class AppColorsDark extends AppColorsData {
  const AppColorsDark._();
  static const instance = AppColorsDark._();

  @override
  Color get primary => const Color(0xFF00E0A8);
  @override
  Color get primaryDark => const Color(0xFF00C896);
  @override
  Color get pageBg => const Color(0xFF0F1117);
  @override
  Color get textPrimary => const Color(0xFFF0F0F2);
  @override
  Color get textSecondary => const Color(0xFFA0A4B0);
  @override
  Color get textTertiary => const Color(0xFF6B7080);
  @override
  Color get border => const Color(0xFF2A2D38);
  @override
  Color get success => const Color(0xFF00D8A8);
  @override
  Color get warning => const Color(0xFFFFB74D);
  @override
  Color get danger => const Color(0xFFFF6B6B);
  @override
  Color get surface => const Color(0xFF1A1D27);
  @override
  Color get surfaceContainerLow => const Color(0xFF151820);
  @override
  Color get surfaceContainerHigh => const Color(0xFF22252F);
  @override
  Color get outlineVariant => const Color(0xFF2E3140);
  @override
  Color get darkSurface => const Color(0xFF0A0C12);
  @override
  Color get energyGreen => const Color(0xFF00E0A8);
  @override
  Color get energyAmber => const Color(0xFFFFC04D);
  @override
  Color get energyRed => const Color(0xFFFF6B6B);
  @override
  Color get inkBtn => const Color(0xFF2A2D38);
  @override
  Color get inkBtn2 => const Color(0xFF363A48);
  @override
  Color get accentSky => const Color(0xFF5CB8FF);
  @override
  Color get accentViolet => const Color(0xFF9B8EFF);
  @override
  Color get accentAmber => const Color(0xFFFFB84D);
  @override
  Color get accentPurple => const Color(0xFFA78BFA);
  @override
  Color get accentOrange => const Color(0xFFFF9A3C);
  @override
  Color get brandRed => const Color(0xFFFF4D5E);
  @override
  Color get pageBgTop => const Color(0xFF11141C);
  @override
  Color get pageBgBot => const Color(0xFF0F1117);
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

  // ── v8 tokens (see docs/design_system.md) ──────────────────────────────
  static const List<BoxShadow> svcCardShadow = [
    BoxShadow(color: Color(0x0D182740), blurRadius: 14, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> sheetShadow = [
    BoxShadow(color: Color(0x38182740), blurRadius: 40, offset: Offset(0, -10)),
  ];

  static const List<BoxShadow> fnIconShadow = [
    BoxShadow(color: Color(0x0D182740), blurRadius: 10, offset: Offset(0, 3)),
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

abstract final class AppTouchTargets {
  /// Minimum custom control hit target used across compact official-style UI.
  static const min = 44.0;
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
