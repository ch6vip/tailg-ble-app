# i18n Extraction Plan

Status: Plan only — no implementation
Scope: `lib/` (Flutter, SDK ^3.8.1)
Author target: H1 — centralize hardcoded user-facing strings

## 1. Summary

The codebase has ~1023 hardcoded Chinese string occurrences across 54 of ~85 Dart files in `lib/`. There is no existing i18n/l10n setup (no `l10n.yaml`, no ARB files, no `flutter_localizations`, no `intl` direct dep — `intl` is transitive only). We recommend Option (c) Hybrid: ship a thin in-house `Strings` class now to escape the "stringly-typed" pain, while leaving the door open to migrate to `flutter_localizations` + ARB later. This unblocks future English (and other locales) without forcing the team to learn `intl`/build_runner today.

## 2. Current state

Survey method:
- `rg '[\x{4e00}-\x{9fff}]' lib` — counts every line containing a CJK character
- `rg '\.arb|l10n|intl|AppLocalizations' .` — confirms absence of any l10n scaffolding

| Metric | Value |
| --- | --- |
| Total CJK string occurrences in `lib/` | ~1023 lines touched |
| Files containing CJK strings | 54 |
| Files in `lib/` (Dart) | ~85 (28 pages, 4 widgets, 22 services, 7 ble, 3 models, 1 config, 1 main, ~20 supporting) |
| Existing `l10n.yaml` | none |
| Existing `.arb` files | none |
| `flutter_localizations` in `pubspec.yaml` | absent |
| `intl` in `pubspec.yaml` | absent (transitive only via Flutter SDK) |
| `MaterialApp` `localizationsDelegates` / `supportedLocales` | not configured (see `lib/main.dart` line ~90) |

The Chinese appears in three flavours:
- UI labels: `Text('设置')`, `'车辆位置'`, `'NFC钥匙'`
- Interpolated: `'今日骑行记录 $travelCount 条'`, `'累计轨迹 ${totalMileage}km'`, `'重连 $attempt/$attempts'`
- Domain/log messages that are *partly* user-facing (SnackBars, dialogs, error toasts) and *partly* internal logs (e.g. `connection_manager.dart` logs `连接设备 ${device.platformName}` to `logService`). These two should be split — only SnackBar/dialog copy needs to be i18n'd; log strings are developer-facing and can stay Chinese (or move to a separate `LogMessages` const).

## 3. Recommended approach: Option (c) — Hybrid

We pick **(c)**: a small, home-rolled `Strings` class for the v1 extraction, with the seams designed so a future migration to ARB is mechanical, not a rewrite.

Why not (a) `flutter_localizations` + ARB right now:
- `intl` + `flutter_localizations` + `gen_l10n` requires adding the SDK, a `l10n.yaml`, ARB files, and (optionally) `build_runner` for typed access. That is heavy for a 1-locale app that just wants centralization.
- The team would have to learn ICU plural/gender syntax even for the simple "1 条 / N 条" cases that already exist (e.g. `今日骑行记录 $travelCount 条`).
- Tooling churn (codegen, IDE plugin, analyzer noise) outweighs the benefit until we actually ship a second locale.

Why not (b) `Strings` class only:
- It is the lightest path, but if we name keys ad-hoc we will paint ourselves into a corner. We want a key-naming convention from day 1 so the future ARB migration is "rename `S.scanStart` → `AppLocalizations.of(ctx).scanStart`" instead of "go find every literal."

Hybrid rules:
- New `lib/l10n/strings.dart` exposing a `Strings` abstract class with `static const` fields, grouped by feature.
- All `Text('中文')` becomes `Text(Strings.scanStart)`.
- All `'$var 条'` interpolations become a small helper: `Strings.travelCount(travelCount)` (so the future ARB can use ICU plurals; the v1 helper just does string interpolation).
- No runtime `BuildContext` dependency in v1 — keeps call sites simple. Future ARB step will introduce context.
- Keep one locale (`zh`) for v1. App locale stays default Chinese.

## 4. Phased rollout

### Phase 1 — Foundation (≈ 1 day, ~300 LoC)
- Create `lib/l10n/strings.dart` (the central registry).
- Create `lib/l10n/format.dart` with `s(String template, [Object? p1, ...])` and a couple of plural helpers (e.g. `sPluralCount(int n, String suffix)`).
- Define key-naming convention: `Strings.<featureArea>.<screen>.<element>` (e.g. `Strings.scan.startButton`, `Strings.control.unbound.scanCta`).
- Add a CI/lint guard: a grep-based check (or a tiny analyzer plugin later) that fails if a `Text('...')` with a CJK character lands in `lib/`. The guard is what keeps the debt from re-accumulating. Easiest form: a `tool/check_no_chinese_in_text.dart` script invoked from `flutter analyze` or CI.
- Document the convention in `docs/i18n-conventions.md` (sibling doc).

### Phase 2 — Extract high-traffic files (~5 pages, ~600 LoC touched)
These are the screens with the most visible copy and the most "lone hero" pages users will see first. Prioritize by string count × visibility.

| # | File | Hits | Why high-traffic | Example strings |
| --- | --- | --- | --- | --- |
| 1 | `lib/pages/control_page_service_cards.dart` | 36 | Home dashboard service grid (NFC, 音效, 蓝牙续费) | `'功能设置'`, `'NFC钥匙'`, `'刷卡骑行新体验'`, `'蓝牙续费'`, `'续费'`, `'附近站点'` |
| 2 | `lib/pages/location_page.dart` | 79 | Map / 轨迹 / 电子围栏 — second most hit page | `'车辆定位'`, `'电子围栏'`, `'历史轨迹'`, `'今日骑行记录 $travelCount 条'`, `'累计轨迹 ${totalMileage}km'` |
| 3 | `lib/pages/vehicle_settings_page.dart` | 77 | Vehicle config (most knobs) | `'震动灵敏度'`, `'档位'`, `'一键修复'`, ... (one row per setting) |
| 4 | `lib/pages/official_cloud_page.dart` | 72 | Official cloud login + SMS code | `'验证码已发送'`, `'手机号'`, `'验证码'`, `'登录'` |
| 5 | `lib/pages/official_replica_pages.dart` | 69 | NFC, 蓝牙续费, 充电站 replica screens | `'手机'`, `'手表'`, `'添加'`, `'删除'` |
| 6 | `lib/pages/qgj_advanced_settings_page.dart` | 52 | Advanced QGJ settings | `'未读取到高级设置状态'`, `'高级设置已刷新'` |
| 7 | `lib/pages/settings_page.dart` | 42 | Top-level settings menu (most cross-links) | `'设置'`, `'连接'`, `'爱车'`, `'扫码'`, `'日志'` |
| 8 | `lib/pages/device_info_page.dart` | 34 | Device info / 序列号 / 固件 | `'设备信息'`, `'固件版本'`, `'序列号'` |
| 9 | `lib/pages/diagnostic_page.dart` | 28 | Diagnostic dumps | `'诊断'`, `'运行中'`, `'已停止'` |
| 10 | `lib/main.dart` | 6 | Bottom nav labels | `'扫描'`, `'爱车'`, `'设置'`, `'$label，已选中'` |

For each: replace literal → `Strings.*`, re-run, snapshot-diff golden tests, ship.

### Phase 3 — Extract remaining 44 files (~1200 LoC touched, 2–3 days)
- Mechanical sweep. Group by feature: `garage_page`, `scan_page`, `cloud_token_page`, `log_page`, `ota_precheck_page`, `vehicle_message_page`, `control_page_*` (the part files), then `widgets/*`, then `services/*` for SnackBar/error copy.
- Skip internal log strings (developer-facing). Only i18n what the user can see in a SnackBar, dialog, tooltip, or `Text`.
- Update `app_snack.dart`, `app_chrome.dart`, `empty_state.dart`, `slide_to_action.dart` — these are shared widgets, extract once, used everywhere.

### Phase 4 — Add English (optional, future PR)
- Add `lib/l10n/strings_en.dart` with the same key set.
- Promote the registry to a `BuildContext`-based lookup: `AppL10n.of(ctx).scan.startButton`.
- Wire `MaterialApp.localizationsDelegates` + `supportedLocales` in `lib/main.dart`.
- Add a settings toggle "跟随系统 / 简体中文 / English" (`app_preferences_service.dart` already exists as a good place to store this).
- Migrate `Strings.scanStart` literals to `AppL10n.of(ctx).scan.startButton` (mostly a sed pass).

## 5. Migration cost estimate

| Phase | New LoC | Files touched | Working days |
| --- | --- | --- | --- |
| 1 — Foundation | ~300 (strings.dart, format.dart, conventions doc, lint guard) | 3 new + 1 lint config | 0.5–1 |
| 2 — High-traffic | ~200 net change in callsites (mostly deletes of literals + adds of `Strings.*`) | 10 files | 1–1.5 |
| 3 — Long tail | ~400 net change | ~44 files | 2–3 |
| 4 — English | ~500 (new strings file + `AppL10n` wrapper + wiring) | 5–10 files | 1–2 |

Total: ~1400 LoC touched, ~5–7 working days for one engineer. No production-risk refactor in any single commit (each phase ships green).

## 6. Risks and gotchas

1. **String interpolation**. `Text('剩余 $value%')` vs `Text('剩余 ${value}%')` — both must become `Text(s('剩余 {0}%', value))` so the English "X% remaining" reordering is possible. Direct `'.. $var ..'` interpolation is the #1 migration blocker.
2. **Contextual strings (same Chinese, different meaning)**. `'连接'` can mean BLE connection *or* "connect to wifi" *or* "add to favorites". Use distinct keys (`Strings.control.connectBle`, `Strings.settings.connectWifi`) — never share a key across features.
3. **Dynamic / list content**. NFC key names, error messages from the BLE stack, official-cloud API error strings, GPS coords, dates — these come from data, not from the UI tree. Do not pass them through `Strings`; they stay as data. Only i18n the surrounding *frame* (e.g. `Strings.nfc.addedOn(date)`).
4. **SnackBars built from exceptions** (`_showSnack(_errorMessage(e), error: true)`). The error map is hardcoded Chinese in services like `control_command_executor.dart` and `official_cloud_api_client.dart`. The error->message map needs to move out of services and into `Strings` (with a thin key-based API: services throw a typed error, UI translates it).
5. **Test snapshot updates**. `test/widget_test.dart` and others may have golden images / hardcoded text assertions. Re-record after Phase 2 lands.
6. **Part files**. `lib/pages/control_page.dart` has 11 `part of` files. `Strings` needs to be importable from all of them — the `part` files already share the parent's imports, so a single import in `control_page.dart` is enough.
7. **Log strings in services**. Files like `ble/connection_manager.dart` (45 hits) and `services/official_cloud_service.dart` (50 hits) are mostly *developer* logs going to `logService`. **Do not** i18n them — they are not user-facing. The risk is the analyzer pattern (from Phase 1) misfiring on these. The check should be scoped: `Text('..CJK..')` and `SnackBar(content: Text('..CJK..'))` only, not bare string literals in services.
8. **Comment / doc strings**. The regex `[\x{4e00}-\x{9fff}]` matches them too. The lint guard should only count `Text(`-style call sites.
9. **Selector / Semantics labels**. `lib/main.dart:310` builds a Semantics label via `'$label，已选中'`. This needs to be i18n'd too — accessibility strings are first-class UI.
10. **Hard-coded enum display names**. `lib/models/vehicle_profile.dart:2` has `auto('自动识别')` — protocol enum stores its own user-facing label. Either move the label to `Strings.protocol.auto` and let the model look it up, or leave it (since the protocol enum is the *only* consumer). Recommend: leave for v1, fix in Phase 4.
11. **Part-of-file Chinese in `app_colors.dart`**. There is a doc comment `/// 官方品牌红，仅复刻保真场景使用。` and a `static const brandRed`. The constant is fine; the comment is fine (it's a docstring, not user copy). No action.

## 7. Open questions for the user

1. **Locale scope at v1**: ship Chinese-only centralization (recommended) or also add English in the same PR? Adding English roughly doubles Phase 1+2 work and requires a locale-switcher UI in settings.
2. **Storage of preference**: where should "user-picked locale" live? `shared_preferences` (already in deps) is the obvious answer, but should it be a top-level toggle in `app_preferences_pages.dart` or a hidden debug flag?
3. **Error-message ownership**: do we want services to throw typed errors (e.g. `class BleError { final ErrorCode code; }`) and let the UI translate, or keep the human-readable Chinese string in the service and i18n the whole string? The first is the "right" answer but is a larger refactor; the second is faster but means future locales must edit services too.
4. **Naming convention**: `Strings.scan.startButton` (nested, dot-notation) vs `Strings.scanStartButton` (flat)? Nested reads better; flat is one fewer file-level abstraction. Recommend nested.
5. **Lint enforcement strength**: a CI grep-check that fails the build, or an analyzer warning only? Recommend CI failure (it's the only thing that prevents regression).
6. **Pluralization needs**: any place where the Chinese hides a plural? E.g. `'今日骑行记录 $travelCount 条'` — do we need the v1 helper to handle "1 条 / 2 条" in English? English has the singular/plural split; Chinese doesn't, so the v1 helper can just always do the plural-safe interpolation. Confirm acceptable.
7. **Scope of `lib/services/*.dart` Chinese**: do we treat any of it as user-facing? (e.g. SnackBar messages in `control_command_result.dart`). Recommend: only strings that already pass through a widget on the user-visible path. Internal logs stay Chinese.

## 8. Survey data backing the plan

- **Total CJK string occurrences in `lib/`**: 1023, across 54 files
- **Top density**: `location_page.dart` 79, `vehicle_settings_page.dart` 77, `official_cloud_page.dart` 72, `official_replica_pages.dart` 69, `qgj_advanced_settings_page.dart` 52, `official_cloud_service.dart` 50, `connection_manager.dart` 45, `settings_page.dart` 42, `control_page_service_cards.dart` 36, `device_info_page.dart` 34, `battery_details_page.dart` 33, `garage_page.dart` 31, `diagnostic_page.dart` 28, `vehicle_message_page.dart` 32
- **No existing i18n**: `pubspec.yaml` has neither `flutter_localizations` nor `intl` as a direct dep
- **`MaterialApp` is not localized**: `lib/main.dart` — no `localizationsDelegates` / `supportedLocales`

## 9. Critical files for implementation

- `lib/main.dart` — bottom nav labels and `MaterialApp` where `localizationsDelegates` will be wired in Phase 4
- `lib/pages/control_page_service_cards.dart` — densest visible screen; will exercise every extraction pattern
- `lib/pages/location_page.dart` — second-densest page; the test bed for the `s(...)` interpolation helper
- `pubspec.yaml` — where `flutter_localizations` and (later) `intl` will be added
- `lib/services/control_command_result.dart` and `lib/services/official_cloud_api_client.dart` — the services that surface error strings into SnackBars
