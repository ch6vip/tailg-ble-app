# Repository Guidelines

## Project Structure & Module Organization

This is a Flutter app for Tailg vehicle BLE control with official cloud integration. Core Dart code lives in `lib/`: `ble/` contains protocol frames, parsers, GATT constants, and `ConnectionManager`; `services/` owns cloud APIs, persistence, control routing, auto-connect, proximity unlock, logs, and location; `models/` stores vehicle and telemetry data; `pages/`, `widgets/`, and `theme/` contain UI. Tests live in `test/`. Platform projects are under `android/`, `ios/`, `macos/`, `linux/`, `windows/`; web shell assets are under `web/`. Planning, verification, and build notes belong in `docs/`.

## Build, Test, and Development Commands

- `flutter pub get`: install Dart and Flutter dependencies.
- `flutter doctor`: verify Flutter, Android SDK, JDK, and devices.
- `flutter run`: run a debug build on a connected device. BLE behavior requires a physical Android device.
- `flutter build apk --debug`: build a debug APK.
- `flutter build apk --release`: build a release APK; local signing requires `android/key.properties` and a keystore.
- `dart format --output=none --set-exit-if-changed .`: check formatting.
- `flutter analyze`: run static analysis.
- `flutter test`: run all tests.

## Coding Style & Naming Conventions

Use Dart defaults: two-space indentation, trailing commas for readable Flutter trees, `lower_snake_case.dart` files, `PascalCase` types, and `camelCase` members. Keep app-wide colors, radii, shadows, and text styles in `lib/theme/`. Prefer existing service and widget patterns before adding abstractions. This repo uses `flutter_lints`; `constant_identifier_names` is intentionally disabled for protocol constants.

## Testing Guidelines

Use `flutter_test`. Name test files `*_test.dart` and keep tests close to the behavior they verify, such as `ble_parser_test.dart`, `official_cloud_test.dart`, or `vehicle_store_test.dart`. Add focused tests for protocol parsing, command routing, persistence migration, and UI state changes. Run `dart format`, `flutter analyze`, and `flutter test` before submitting.

## Commit & Pull Request Guidelines

Recent history follows Conventional Commits with optional scopes, for example `fix(build): ...`, `feat(ui): ...`, and `fix(services): ...`. Prefer short imperative summaries and scope the change to one concern. Pull requests should include a clear description, affected modules, test results, and screenshots for UI changes. Link related issues or verification notes when relevant.

## CI/CD Pipeline

Workflows live in `.github/workflows/`:

| File | Purpose | Trigger |
|------|---------|---------|
| `build.yml` | CI gate (`format` → `analyze` → `test`) for PRs plus signed APK artifact build for manual runs | PR to `master` or `develop`, manual |
| `release.yml` | Standalone build & release with rich release notes and Telegram notification | `v*` tags, manual |

`release.yml` is the only workflow that listens to `v*` tags and creates GitHub Releases. `build.yml` no longer listens to tags and does not call `softprops/action-gh-release`.

**Quality gates** enforced on every PR via `build.yml` ci job: `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`. Coverage reports are **not** currently uploaded (planned in Sprint 2).

**Build strategy**: PR to `master`/`develop` runs CI automatically; manual Build APK workflow produces a signed release APK artifact (arm64); `v*` tags → GitHub Release with APK artifact via `release.yml`. Release signing keys are injected via GitHub Secrets at build time — never committed to the repo.

**Notifications**: Release publish events are pushed to Telegram. Configuration details and required Secrets reference in `docs/github_actions_guide.md`.

**Cache**: Gradle dependencies are cached across builds. Flutter/Dart packages are cached by `subosito/flutter-action`.

## Security & Configuration Tips

Do not commit keystores, `key.properties`, tokens, phone numbers, IMEI values, or captured vehicle data. Keep official cloud credentials in secure storage and preserve log redaction. Advanced BLE writes, OTA, and account/cloud changes should include reversible steps and a real-device verification note in `docs/first_batch_verification.md` when not fully tested.
