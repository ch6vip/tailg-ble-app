# Repository Guidelines

## Mission

This repository is an **unofficial full-logic replica** of the official Tailg app（台铃智能）:

- Match official **features, control-channel rules, state machines, and API semantics**
- Channels: **local BLE** + **remote MQTT** + **cloud HTTP**
- UI uses the in-house Aurora design system — **not** a pixel-perfect skin clone
- Out of scope by default: mall, payment, insurance, community, and other L3 ops features

Task plan (source-code based): [PLAN.md](PLAN.md). Product overview: [README.md](README.md).

There is **no `docs/` tree**. Keep durable notes in those root markdown files (or short PR descriptions).

## Project Structure

| Path | Role |
|------|------|
| `lib/ble/` | Near-field protocol, AES, `ConnectionManager`, QGJ frames |
| `lib/services/` | Cloud API, MQTT, control routing, auto-connect, persistence, logging |
| `lib/models/` | Vehicles, battery, commands, geo |
| `lib/pages/` · `lib/widgets/` · `lib/theme/` | UI + design tokens |
| `test/` | Unit / widget tests |
| `android/` · `ios/` · … | Platform projects (BLE + location permissions) |

Official APK reverse material lives **outside** this repo: `E:\ctf-aaa\tlddc\decompiled`.

## Build, Test, Development

```bash
flutter pub get
flutter doctor
flutter run                          # real device needed for BLE
flutter build apk --debug
flutter build apk --release          # needs key.properties + keystore locally or via CI
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-warnings --fatal-infos
flutter test
flutter test --coverage
```

Optional map token:

```bash
flutter run --dart-define=TIANDITU_TOKEN=<token>
```

## Coding Style

- Dart defaults: 2-space indent, trailing commas, `lower_snake_case.dart`, `PascalCase` types, `camelCase` members
- Colors / radii / motion: only via `lib/theme/` — no raw Material brand colors in pages
- Prefer existing service patterns (`OfficialCloud*`, `OfficialMqtt*`, `ControlCommand*`, `ConnectionManager`) before new layers
- `flutter_lints` enabled; `constant_identifier_names` is intentionally off for protocol constants

## Testing

- `flutter_test`; files named `*_test.dart`
- Prioritize: control routing, BLE frame parse, MQTT payload, cloud parsers, persistence, command result states
- Logic must be testable without a vehicle; device/BLE checks are manual acceptance on top
- Before push: format + analyze + test

## Commits & PRs

- Conventional Commits with optional scope: `feat(ble):`, `fix(mqtt):`, `feat(cloud):`, `docs:`, …
- One concern per commit when practical
- PRs: what official behavior you matched, modules touched, test results, screenshots for UI; note real-device checks if channel behavior changed

## CI/CD

| Workflow | Trigger | Behavior |
|----------|---------|----------|
| `.github/workflows/build.yml` | PR/push `master`·`develop`, manual | format → analyze → test → coverage gate; push also builds signed arm64 APK artifact |
| `.github/workflows/release.yml` | `v*` tags, manual | same gates → GitHub Release (+ optional Telegram) |

Never commit keystores, `key.properties`, tokens, phone numbers, IMEI, or raw captures. Secrets only via GitHub Actions secrets / local untracked files.

## Security & Privacy

- Official credentials only in secure storage
- Keep log redaction (`sensitive_value_masker` / log pipeline)
- Replica work may need device + vehicle tests; do not paste secrets into issues or commits

## Relation to `tailg-next`

Per workspace `E:\ctf-aaa\tlddc\版本说明.md`: this repo is the **test / full-replica line**; `tailg-next` is the **production** line. Do not assume changes here auto-ship there.
