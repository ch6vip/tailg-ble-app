# Project Memory — Tailg BLE App

## Design System
- Design language: v8 "Aurora Cockpit" (Ninebot-inspired), primary color `#00C896` (emerald green)
- Design doc: `design_v2/UI_DESIGN_PROPOSAL.md` (v2 spec, partially implemented)
- Token files: `lib/theme/app_colors.dart`, `app_motion.dart`
- Green token mapping: `success` = status confirmation; `energyGreen` = battery indicators
- `info` / `accentTeal` are aliases of `success` (backward compat, prefer `success` for new code)
- Dark mode: `AppColorsDark` defined, not yet wired to ThemeMode

## Key Widgets & UX Patterns
- `ControlCard` (lib/widgets/): floating card with _SideButton(press-feedback), _PowerKnob(long-press 1.2s + busy glow), _SubControl
- `StatusBadge` (lib/widgets/): pulsing dot only for active states (armed/ble/online), static for idle/offline
- `_RidingModeSelector`: eco=success green, standard=accentSky blue, sport=warning orange
- `_UnboundBanner`: PageView carousel with 3 feature pages, auto-rotation 4s

## Motion Tokens (AppMotion)
- `pressScale`: 0.96; `micro`: 150ms; `standard`: 250ms; `longPressHold`: 1200ms
- Curves: `pressCurve` = easeOutCubic, `pulseCurve` = easeInOut, `progressCurve` = linear

## Conventions
- Touch targets: minimum 44×44px (WCAG 2.5.5)
- Press feedback required on all interactive elements: AnimatedScale(0.96)
- Use AppColors tokens — never hardcode Material Colors
- New theme tokens go in `lib/theme/`, imported by consumers
- Control page is split into part files under `lib/pages/control_page_*.dart`
