# Tailg Cloud App - GitHub Actions CI/CD 配置指南

> 本文档按 `.github/workflows/` 当前实际配置维护。当前只有 `build.yml` 和 `release.yml` 两个工作流，不存在 `ci.yml`。CI 只运行自动化门禁和 APK 构建，不要求实体设备、实体车辆或 Bluetooth 测试。

---

## 项目技术栈摘要

| 维度 | 详情 |
|------|------|
| 框架 | Flutter 3.44.6 / Dart 3.12.2 |
| 构建工具 | Gradle (Kotlin DSL), compileSdk 36, JDK 11 |
| 依赖管理 | `flutter pub get` (`pubspec.yaml` + `pubspec.lock`) |
| 测试框架 | `flutter_test` |
| 代码规范 | `flutter_lints`，Dart formatter |
| 目标平台 | Android (`minSdk 23`, arm64 优先) |
| 签名方式 | GitHub Secrets 注入 keystore 与 `android/key.properties` |

---

## 工作流文件清单

| 文件 | 用途 | 触发条件 |
|------|------|----------|
| `build.yml` | PR 自动 CI 门禁 + push/手动构建签名 APK artifact | PR/push 到 `master`/`develop`，手动 |
| `release.yml` | 构建签名 APK 并发布 GitHub Release | push `v*` tag，手动 |

当前分工：

- `build.yml` 不监听 `v*` tag，也不创建 GitHub Release。
- push 到 `master`/`develop` 会触发 `build.yml`，先跑 CI 门禁，成功后构建签名 APK artifact。
- PR 到 `master`/`develop` 只跑 CI 门禁，不构建签名 APK。
- `release.yml` 是唯一 tag 发布入口，负责 `softprops/action-gh-release`。
- 两个工作流都会在构建前执行 `dart format --output=none --set-exit-if-changed .`、`flutter analyze`、`flutter test`。
- 当前没有覆盖率上传、Codecov、Firebase 分发或 Slack 通知步骤。

---

## `build.yml` - CI 与 APK Artifact

### 触发规则

| 触发事件 | 分支 | 执行范围 |
|----------|------|----------|
| `pull_request` | `master` / `develop` | `ci` |
| `push` | `master` / `develop` | `ci` -> `build` |
| `workflow_dispatch` | 手动选择当前 ref | `ci` -> `build` |

### Job 结构

| Job | 条件 | 关键步骤 |
|-----|------|----------|
| `ci` | 所有触发事件 | checkout、安装 Flutter、`flutter pub get`、format、analyze、test |
| `build` | `needs: ci` 且 push/手动触发 | Gradle 缓存、解码 keystore、生成 `android/key.properties`、构建 release APK、生成 SHA-256、上传 artifact |

### 构建产物

| 项 | 配置 |
|----|------|
| APK 路径 | `build/app/outputs/flutter-apk/app-release.apk` |
| 校验文件 | `build/app/outputs/flutter-apk/app-release.apk.sha256` |
| Artifact 名称 | `tailg-ble-${{ github.ref_name }}-${{ github.sha }}` |
| 保留时间 | 14 天 |
| 压缩级别 | 0 |

---

## `release.yml` - Release 发布

### 触发规则

| 触发事件 | 行为 |
|----------|------|
| `push` `v*` tag | checkout 当前 tag，构建并发布 Release |
| `workflow_dispatch` | 可填写 `tag`；留空时使用当前 ref |

手动补发 Release 时建议填写已存在的 tag，避免在分支 ref 上生成非预期 Release。

### Job 结构

| Step | 作用 |
|------|------|
| checkout | 使用 tag 输入或当前 ref |
| setup Flutter | 安装 Flutter 3.44.6 stable，启用 pub cache |
| quality gates | `flutter pub get`、format、analyze、test |
| signing | 解码 keystore，写入 `android/key.properties` |
| build | `flutter build apk --release --target-platform android-arm64` |
| checksum | 生成 APK SHA-256 |
| version | 从 `pubspec.yaml` 提取 App 版本，并根据 tag 判断 prerelease |
| release | 用 `softprops/action-gh-release@v2` 创建/更新 GitHub Release |
| notify | 发布成功后通过 Telegram 推送通知 |
| summary | 写入 GitHub Actions run summary |

### Release 产物

| 文件 | 说明 |
|------|------|
| `app-release.apk` | arm64 release APK |
| `app-release.apk.sha256` | SHA-256 校验文件 |

Release 标题格式：

```text
Tailg BLE v<pubspec version> (<tag>)
```

带 `-rc`、`-beta`、`-alpha` 的 tag 会标记为 prerelease。

---

## Secrets

### 必需：签名构建

| Secret | 用途 |
|--------|------|
| `KEYSTORE_BASE64` | Base64 编码的 Android keystore |
| `KEYSTORE_PASSWORD` | keystore 密码 |
| `KEY_PASSWORD` | key 密码 |
| `KEY_ALIAS` | key alias |

`build.yml` 的 push/手动 APK 构建会在缺少签名 Secret 时显式失败；PR CI 不需要签名 Secret。`release.yml` 的签名属性也依赖同一组 Secret。

### 发布通知

| Secret | 用途 |
|--------|------|
| `TELEGRAM_CHAT_ID` | Telegram 接收会话 |
| `TELEGRAM_BOT_TOKEN` | Telegram Bot token |

当前 Release 成功后会执行 Telegram 通知步骤；如果不需要通知，应同步调整 `release.yml`，避免缺少 Secret 导致发布后的通知步骤失败。

---

## 权限与并发

| 工作流 | `permissions` | `concurrency` |
|--------|---------------|---------------|
| `build.yml` | `contents: read` | `build-${{ github.ref }}`，新运行会取消同 ref 旧运行 |
| `release.yml` | `contents: write` | `release-${{ github.ref }}`，不取消同 ref 旧运行 |

---

## 本地验证命令

提交前建议执行：

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-warnings --fatal-infos
flutter test --coverage --reporter compact
dart tool/check_coverage.dart coverage/lcov.info 40
```

本地 release APK 构建需要准备 `android/key.properties` 和 keystore：

```bash
flutter build apk --release --target-platform android-arm64
```

---

## 当前限制

- 覆盖率报告尚未上传为 CI artifact；当前仅通过 `coverage/lcov.info` 执行 40% 线覆盖率门禁。
- `build.yml` 的 PR 触发不会构建 APK；push 到 `master`/`develop` 或手动运行 Build APK workflow 才会上传签名 APK artifact。
- `release.yml` 是唯一 GitHub Release 发布入口；验证 tag 发布时只需检查该工作流。
