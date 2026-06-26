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

## Service Wiring Pitfalls (learned 2026-06-26)
- UI toggles on the control page MUST bind to the actual feature service, not `ManualModeService`. ManualMode is a *disable-all-auto-control* override consulted by `ProximityService.start()` / `AutoConnectService` — wiring a feature switch to it inverts the semantics (switch ON = feature OFF).
- `AppServices.reset()` (test-only) must call `resetForTest()` on each singleton service, NOT `dispose()`. `dispose()` closes StreamControllers permanently on factory singletons → zombie instances on next `production()`.
- BLE `connected → ready` transition needs a watchdog timer (8s) — without it, a silent handshake failure leaves the UI stuck on "连接中" forever.
- Any callback invoked from `Timer.periodic` that performs async cleanup must be wrapped in `scheduleMicrotask(...)` so thrown exceptions surface instead of being swallowed by the Timer zone.
- `_findUserId`-style recursive extractors must NOT use `'id'` as a fallback key — too greedy, matches `carId`/`deviceTravelId`/`extendId` etc. Use only `'uid'`/`'userId'`.
- HTTP header maps must be audited for typos — `Forward-Service-Ip` vs `Forward-ServiceIp` both existed and silently doubled the request size while only one form reached the server.
- `LogService` now exposes a `changes` broadcast stream; UI pages should subscribe instead of `setState(() {})` polling.
- BLE log entries containing login frames are redacted at `LogService.ble()` level — keep this pattern when adding new credential-bearing log calls.
