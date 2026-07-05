# Design System Notes

本文件是当前 Flutter 实现的设计系统索引，替代旧的 `design_v2/` HTML/PNG 原型目录。旧原型只用于早期探索，当前实现以 `lib/theme/`、共享组件和测试守卫为准。

## Source Of Truth

| Area | Current source |
| --- | --- |
| Color tokens | `lib/theme/app_colors.dart` |
| Motion tokens | `lib/theme/app_motion.dart` |
| Shared chrome, cards, skeleton | `lib/widgets/app_chrome.dart` |
| Press / long-press interaction | `lib/widgets/app_pressable.dart`, `lib/widgets/control_card.dart` |
| Status labels | `lib/widgets/status_badge.dart` |
| Toast / snack feedback | `lib/widgets/app_toast.dart`, `lib/widgets/app_snack.dart` |

## Current Visual Direction

- Quiet work-focused dashboard, not a marketing landing page.
- Primary brand/action color: `AppColors.primary` (`#00C896`).
- Safety and warning states use explicit semantic tokens: `success`, `warning`, `danger`, `brandRed`.
- Surface hierarchy uses `pageBg`, `surface`, `surfaceContainerLow`, `surfaceContainerHigh`, `hairline`, and `outlineVariant`.
- Dark mode is wired through `ThemeMode.system` and `AppColorsDark`; hardcoded contrast audit remains a later token-system task.

## Interaction Rules

- Tap targets for custom controls should stay at least `AppTouchTargets.min`
  (44 px).
- Reusable press feedback should go through `AppPressable` and `AppMotion.pressScale`.
- Long-press power actions use `AppMotion.longPressHold` and must support pointer-exit cancellation.
- Snack/toast colors should resolve from the active theme where possible.

## Page Patterns

- Control home hero: `ControlPageHero` owns battery, range, connection label, vehicle switch, and message entry.
- Vehicle illustration: `VehicleStagePainter` is now a native canvas implementation; do not reintroduce external SVG/HTML dependencies.
- Central control card: `ControlCard` owns the long-press power knob and quick action layout.
- Profile page: `ProfilePage` follows the current app chrome and account/status card structure.

## Historical Notes

The removed `design_v2/` directory contained early HTML previews and bitmap screenshots. Those files were useful during visual exploration, but they were not used by Flutter builds, tests, CI, or runtime assets. Keep future design references in this document or in code-owned theme/component files instead of committing large throwaway prototypes.
