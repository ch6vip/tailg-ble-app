# i18n Extraction Plan

Status: Plan only — no implementation; cloud-only scope
Scope: `lib/` (Flutter, SDK ^3.8.1)
Author target: H1 — centralize hardcoded user-facing strings

> Scope note: this plan excludes all removed local-hardware, BLE/GATT, scanning, and device-verification pages. Any historical references to those pages or strings are not implementation tasks.

## 1. Summary

The current cloud-only tree has about 944 CJK-containing lines across 64 Dart files in `lib/`. `flutter_localizations`, `intl`, and Flutter's built-in localization delegates are present, but there is no `l10n.yaml`, ARB file, generated app-localization class, or business-copy lookup. We recommend Option (c) Hybrid: centralize user-facing strings first, then migrate the registry to generated ARB resources when a second locale is implemented.

## 2. Current state

Survey method:
- `rg '[\x{4e00}-\x{9fff}]' lib` — counts every line containing a CJK character
- `rg '\.arb|l10n|intl|AppLocalizations' .` — confirms absence of any l10n scaffolding

| Metric | Value |
| --- | --- |
| Total CJK-containing lines in `lib/` | ~944 |
| Files containing CJK strings | 64 |
| Files in `lib/` (Dart) | Refresh this survey before implementation; removed local-hardware directories are excluded |
| Existing `l10n.yaml` | none |
| Existing `.arb` files | none |
| `flutter_localizations` in `pubspec.yaml` | present |
| `intl` in `pubspec.yaml` | present |
| `MaterialApp` `localizationsDelegates` / `supportedLocales` | built-in delegates configured; business strings still hardcoded |

The Chinese appears in three flavours:
- UI labels: `Text('设置')`, `'车辆位置'`, `'NFC钥匙'`
- Interpolated: `'今日骑行记录 $travelCount 条'`, `'累计轨迹 ${totalMileage}km'`, `'重连 $attempt/$attempts'`
- Domain/log messages that are *partly* user-facing (SnackBars, dialogs, error toasts) and *partly* internal logs. These two should be split — only SnackBar/dialog copy needs to be i18n'd; internal logs are developer-facing and can stay Chinese (or move to a separate `LogMessages` const).

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
- Define key-naming convention: `Strings.<featureArea>.<screen>.<element>` (e.g. `Strings.cloud.login.submitButton`, `Strings.control.unbound.loginCta`).
- Add a CI/lint guard: a grep-based check (or a tiny analyzer plugin later) that fails if a `Text('...')` with a CJK character lands in `lib/`. The guard is what keeps the debt from re-accumulating. Easiest form: a `tool/check_no_chinese_in_text.dart` script invoked from `flutter analyze` or CI.
- If this plan moves into implementation, add a focused conventions section to this document or create `docs/i18n-conventions.md` in the same PR.

### Phase 2 — Extract high-traffic files (~5 pages, ~600 LoC touched)
These are the screens with the most visible copy and the most "lone hero" pages users will see first. Prioritize by string count × visibility.

| # | File | Hits | Why high-traffic | Example strings |
| --- | --- | --- | --- | --- |
| 1 | `lib/pages/vehicle_control_home_page.dart` | — | Aurora 爱车主页（控车快捷 / 电量 / 位置 / 最近命令） | `'寻车'`, `'已设防'`, `'开坐垫'`, `'最近命令'` |
| 2 | `lib/pages/service_hub_page.dart` | — | 服务中心入口网格 | `'服务中心'`, `'车辆定位'`, `'历史轨迹'`, `'电子围栏'` |
| 3 | `lib/pages/location_page.dart` | 79 | Map / 轨迹 / 电子围栏 — second most hit page | `'车辆定位'`, `'电子围栏'`, `'历史轨迹'`, `'今日骑行记录 $travelCount 条'`, `'累计轨迹 ${totalMileage}km'` |
| 4 | `lib/pages/vehicle_settings_page.dart` | 77 | Vehicle config (most knobs) | `'震动灵敏度'`, `'档位'`, `'一键修复'`, ... (one row per setting) |
| 5 | `lib/pages/official_cloud_page.dart` | 72 | Official cloud login + SMS code | `'验证码已发送'`, `'手机号'`, `'验证码'`, `'登录'` |
| 6 | `lib/pages/official_replica_pages.dart` | 69 | NFC and charging-station placeholder screens | `'手机'`, `'手表'`, `'添加'`, `'删除'` |
| 7 | `lib/pages/settings_page.dart` | 42 | Top-level settings menu (most cross-links) | `'设置'`, `'连接'`, `'爱车'`, `'扫码'`, `'日志'` |
| 8 | `lib/pages/diagnostic_page.dart` | 28 | Diagnostic dumps | `'诊断'`, `'运行中'`, `'已停止'` |
| 9 | `lib/main.dart` | 6 | Bottom nav labels | `'服务'`, `'爱车'`, `'我的'`, `'$label，已选中'` |

For each: replace literal → `Strings.*`, re-run, snapshot-diff golden tests, ship.

### Phase 3 — Extract remaining 44 files (~1200 LoC touched, 2–3 days)
- Mechanical sweep. Group by feature: `garage_page`, `cloud_token_page`, `log_page`, `vehicle_message_page`, `vehicle_control_home_page`, `service_hub_page`, then `widgets/*`, then `services/*` for SnackBar/error copy. Removed scan, OTA-precheck, device-info pages, and the retired official-replica `control_page_*` family are excluded.
- Skip internal log strings (developer-facing). Only i18n what the user can see in a SnackBar, dialog, tooltip, or `Text`.
- Update `app_snack.dart`, `app_chrome.dart`, `empty_state.dart`, `slide_to_action.dart` — these are shared widgets, extract once, used everywhere.

### Phase 4 — Add English (optional, future PR)
- Add `lib/l10n/strings_en.dart` with the same key set.
- Promote the registry to a `BuildContext`-based lookup: `AppL10n.of(ctx).scan.startButton`.
- Wire `MaterialApp.localizationsDelegates` + `supportedLocales` in `lib/main.dart`.
- Add a settings toggle "跟随系统 / 简体中文 / English" (`app_preferences_service.dart` already exists as a good place to store this).
- Migrate `Strings.cloudLoginSubmit` literals to `AppL10n.of(ctx).cloud.login.submitButton`.

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
2. **Contextual strings (same Chinese, different meaning)**. `'连接'` can mean cloud session, network connection, or adding to favorites. Use distinct keys — never share a key across features.
3. **Dynamic / list content**. NFC key names, official-cloud API error strings, GPS coordinates, and dates come from data, not from the UI tree. Do not pass them through `Strings`; translate only the surrounding frame.
4. **SnackBars built from exceptions** (`_showSnack(_errorMessage(e), error: true)`). The error map is hardcoded Chinese in services like `control_command_executor.dart` and `official_cloud_api_client.dart`. The error->message map needs to move out of services and into `Strings` (with a thin key-based API: services throw a typed error, UI translates it).
5. **Test snapshot updates**. `test/widget_test.dart` and others may have golden images / hardcoded text assertions. Re-record after Phase 2 lands.
6. **Shared imports**. Prefer one `Strings` import per library file. Retired official-replica `control_page.dart` part trees no longer apply; Aurora home and service hub are standalone libraries.
7. **Log strings in services**. Service logs are mostly *developer* messages going to `logService`. **Do not** i18n them — they are not user-facing. The check should be scoped: `Text('..CJK..')` and `SnackBar(content: Text('..CJK..'))` only, not bare string literals in services.
8. **Comment / doc strings**. The regex `[\x{4e00}-\x{9fff}]` matches them too. The lint guard should only count `Text(`-style call sites.
9. **Selector / Semantics labels**. `lib/main.dart:310` builds a Semantics label via `'$label，已选中'`. This needs to be i18n'd too — accessibility strings are first-class UI.
10. **Hard-coded enum display names**. `lib/models/vehicle_profile.dart:2` has `auto('自动识别')` — protocol enum stores its own user-facing label. Either move the label to `Strings.protocol.auto` and let the model look it up, or leave it (since the protocol enum is the *only* consumer). Recommend: leave for v1, fix in Phase 4.
11. **Part-of-file Chinese in `app_colors.dart`**. There is a doc comment `/// 官方品牌红，仅复刻保真场景使用。` and a `static const brandRed`. The constant is fine; the comment is fine (it's a docstring, not user copy). No action.

## 7. Open questions for the user

1. **Locale scope at v1**: ship Chinese-only centralization (recommended) or also add English in the same PR? Adding English roughly doubles Phase 1+2 work and requires a locale-switcher UI in settings.
2. **Storage of preference**: where should "user-picked locale" live? `shared_preferences` (already in deps) is the obvious answer, but should it be a top-level toggle in `app_preferences_pages.dart` or a hidden debug flag?
3. **Error-message ownership**: do we want services to throw typed errors (e.g. `class CloudError { final ErrorCode code; }`) and let the UI translate, or keep the human-readable Chinese string in the service and i18n the whole string? The first is the "right" answer but is a larger refactor; the second is faster but means future locales must edit services too.
4. **Naming convention**: `Strings.cloud.login.submitButton` (nested, dot-notation) vs `Strings.cloudLoginSubmitButton` (flat)? Nested reads better; flat is one fewer file-level abstraction. Recommend nested.
5. **Lint enforcement strength**: a CI grep-check that fails the build, or an analyzer warning only? Recommend CI failure (it's the only thing that prevents regression).
6. **Pluralization needs**: any place where the Chinese hides a plural? E.g. `'今日骑行记录 $travelCount 条'` — do we need the v1 helper to handle "1 条 / 2 条" in English? English has the singular/plural split; Chinese doesn't, so the v1 helper can just always do the plural-safe interpolation. Confirm acceptable.
7. **Scope of `lib/services/*.dart` Chinese**: do we treat any of it as user-facing? (e.g. SnackBar messages in `control_command_result.dart`). Recommend: only strings that already pass through a widget on the user-visible path. Internal logs stay Chinese.

## 8. Survey data backing the plan

- **Current cloud-only survey**: about 944 CJK-containing lines across 64 files
- **Top density**: refresh this list after the cloud-only survey; removed local-hardware pages are excluded
- **Current scaffolding**: `flutter_localizations` and `intl` are dependencies, but no ARB files or generated app strings exist
- **`MaterialApp`**: built-in Flutter delegates are wired, but business copy is not translated

## 9. Critical files for implementation

- `lib/main.dart` — bottom nav labels and current `MaterialApp` localization wiring
- `lib/pages/vehicle_control_home_page.dart` — Aurora 爱车主页；primary control-surface copy
- `lib/pages/service_hub_page.dart` — service grid labels
- `lib/pages/location_page.dart` — second-densest page; the test bed for the `s(...)` interpolation helper
- `pubspec.yaml` — localization dependencies are already present; add generated-resource configuration when ARB migration starts
- `lib/services/control_command_result.dart` and `lib/services/official_cloud_api_client.dart` — the services that surface error strings into SnackBars
