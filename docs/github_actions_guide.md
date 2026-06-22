# Tailg BLE App — GitHub Actions CI/CD 配置指南

> 自动生成于项目架构分析。本文档说明每个工作流的关键步骤、触发规则及所需 Secrets 配置。

---

## 项目技术栈摘要

| 维度 | 详情 |
|------|------|
| 框架 | Flutter 3.32.1 / Dart 3.8.1 |
| 构建工具 | Gradle (Kotlin DSL), compileSdk 36, JDK 11 |
| 依赖管理 | `flutter pub get`（pubspec.yaml + pubspec.lock） |
| 测试框架 | `flutter_test`（19 个测试文件） |
| 代码规范 | `flutter_lints`，Dart formatter |
| 目标平台 | Android（minSdk 23, arm64 优先） |
| 签名方式 | `key.properties` + `release.keystore`（Base64 注入） |

---

## 工作流文件清单

| 文件 | 用途 | 触发条件 |
|------|------|----------|
| `ci.yml` | 主 CI/CD 全流程管道 | push/PR 到 master/develop，tag v*，手动 |
| `release.yml` | 独立 Release 发布 | push tag v*，手动 |
| `build.yml` | 旧版构建工作流（保留兼容） | push/PR 到 master，tag v*，手动 |

> 推荐：`ci.yml` 已涵盖旧版 `build.yml` 的全部功能，可在验证后删除 `build.yml` 避免重复触发。

---

## 工作流详细说明

### 1. `ci.yml` — 主 CI/CD 管道

#### 阶段结构

```
Stage 1 ─ 并行 ──────→  Stage 2 ─────→  Stage 3 ──────→  Stage 4 ─────→  Stage 5
┌─────────┐           ┌──────────┐    ┌──────────────┐   ┌───────────────┐  ┌───────────┐
│ format   │──┐        │          │    │ build-debug  │   │ deploy-dev    │  │ notify-   │
│ (格式检查) │  ├──────→│  test    │───→│ (develop/PR) │──→│ (develop)     │  │ success/  │
├─────────┤  │        │ (测试+   │    ├──────────────┤   ├───────────────┤  │ failure   │
│ analyze  │──┘        │  覆盖率) │    │ build-release│   │ deploy-staging│  │ (汇总通知) │
│ (静态分析) │           │          │    │ (master/tag) │──→│ (master)      │  │           │
└─────────┘           └──────────┘    └──────────────┘   │ deploy-prod   │  └───────────┘
                                                          │ (tag v*)      │
                                                          └───────────────┘
```

#### 各 Step 详解

| Job | Step | 作用 |
|-----|------|------|
| **format** | `dart format --output=none --set-exit-if-changed .` | 检查全部 Dart 代码是否符合官方格式规范，不一致则失败 |
| **analyze** | `flutter pub get` + `flutter analyze` | 安装依赖后运行 Dart 静态分析器，检测类型错误、未使用变量、lint 违规等 |
| **test** | `flutter test --coverage` | 运行 `test/` 下全部 19 个单元测试，生成 LCOV 覆盖率文件 |
| **test** | `codecov/codecov-action@v5` | 将 `coverage/lcov.info` 上传至 Codecov，生成在线覆盖率报告 |
| **test** | `upload-artifact@v4` | 保存覆盖率原始报告为 workflow artifact（7 天保留期） |
| **test** | Post coverage summary | 在 GitHub Actions 运行摘要中输出测试文件和覆盖率概览 |
| **build-debug** | Gradle 缓存 (`actions/cache@v4`) | 缓存 `~/.gradle/caches` 和 `~/.gradle/wrapper`，减少重复构建时间 |
| **build-debug** | `flutter build apk --debug` | 编译 Debug APK（develop 分支和 PR 触发） |
| **build-debug** | SHA-256 校验 | 生成 APK 的 SHA-256 校验和文件，防止篡改检测 |
| **build-release** | Decode keystore | 从 `KEYSTORE_BASE64` Secret 解码出签名密钥文件 |
| **build-release** | Create `key.properties` | 用 Secrets 中的密码和别名写入 Android 签名配置 |
| **build-release** | `flutter build apk --release --target-platform android-arm64` | 编译签名 Release APK（仅 arm64，对应绝大多数真机） |
| **deploy-development** | 下载 artifact + 分发 | 将 Debug APK 部署到开发分发渠道 |
| **deploy-staging** | Firebase App Distribution | 将签名 APK 推送到 Firebase App Distribution（可选，需配置 Token） |
| **deploy-production** | `softprops/action-gh-release@v2` | 创建 GitHub Release，上传签名 APK 和校验和文件 |
| **notify-failure** | Slack 通知 | 管道任何步骤失败时推送 Slack 消息（需配置 Webhook） |
| **notify-success** | 成功汇总 | 在运行摘要中输出各阶段通过状态 |

#### 触发条件矩阵

| 触发事件 | 分支/标签 | 执行范围 |
|----------|-----------|----------|
| `push` | `develop` | format → analyze → test → build-debug → deploy-development → notify |
| `push` | `master` | format → analyze → test → build-release → deploy-staging → notify |
| `push` | `v*` (tag) | format → analyze → test → build-release → deploy-production → notify |
| `pull_request` | → `master`/`develop` | format → analyze → test → build-debug → notify |
| `workflow_dispatch` | 手动选择 | 全流程（可按需选择目标环境） |

---

### 2. `release.yml` — 独立 Release 发布

#### 阶段结构

```
Tag v* 推送 / 手动触发
       │
       ▼
┌────────────────┐
│ Build & Publish│
│ Release        │
│                │
│ 1. 签名配置    │
│ 2. 构建 APK    │
│ 3. 提取版本号  │
│ 4. 创建 Release│
└────────────────┘
```

#### 关键步骤

| Step | 作用 |
|------|------|
| 解码密钥 | 从 `KEYSTORE_BASE64` 还原签名密钥 |
| 创建 `key.properties` | 写入签名参数 |
| `flutter build apk --release` | 构建签名 APK |
| 提取版本号 | 从 `pubspec.yaml` 解析版本号，检测是否为 pre-release |
| `softprops/action-gh-release@v2` | 创建/更新 GitHub Release，附带 APK 和 SHA-256 |

#### 与 `ci.yml` 的关系

- `ci.yml` 在 tag 推送时会**同时**执行完整 CI 管道和发布流程
- `release.yml` 仅执行构建+发布，不触发 CI
- 两者独立运行，互不阻塞。如果 `ci.yml` 的测试失败而只想补发 Release，可手动触发 `release.yml`

---

## 仓库 Secrets 配置项

需要在仓库 Settings → Secrets and variables → Actions 中配置以下 Secrets：

### 必需（签名构建）

| Secret 名称 | 说明 | 获取方式 |
|-------------|------|----------|
| `KEYSTORE_BASE64` | 签名密钥文件（`.keystore` 或 `.jks`）的 Base64 编码 | `base64 -w0 release.keystore` |
| `KEYSTORE_PASSWORD` | 密钥库密码 | 创建密钥时设置 |
| `KEY_PASSWORD` | 密钥密码 | 创建密钥时设置 |
| `KEY_ALIAS` | 密钥别名 | 创建密钥时设置 |

> 生成 Base64：`base64 -w0 release.keystore` → 复制输出字符串到 Secret

### 推荐（覆盖率报告）

| Secret 名称 | 说明 | 获取方式 |
|-------------|------|----------|
| `CODECOV_TOKEN` | Codecov 上传令牌 | 在 [Codecov](https://app.codecov.io) 注册仓库后获取 |

> 公开仓库不强制需要 Token，但推荐配置以保证上传稳定性。

### 可选（部署与通知）

| Secret 名称 | 说明 | 用途 |
|-------------|------|------|
| `TELEGRAM_BOT_TOKEN` | Telegram Bot Token | CI 失败/成功 + Release 通知推送（**已配置**） |
| `TELEGRAM_CHAT_ID` | Telegram 会话/频道 ID | 通知目标（**已配置**） |
| `FIREBASE_TOKEN` | Firebase CI 令牌 | 预发布环境分发 APK |
| `FIREBASE_APP_ID_STAGING` | Firebase App ID（Staging） | 指定分发目标应用 |
| `DEV_DEPLOY_WEBHOOK_URL` | 开发分发 Webhook | 开发环境 APK 内部分发 |
| `SLACK_BOT_TOKEN` | Slack Bot xoxb- Token | 失败通知推送到 Slack |
| `SLACK_WEBHOOK_URL` | Slack Incoming Webhook URL | 失败通知（备选方案） |
| `SLACK_CHANNEL_ID` | Slack 频道 ID | 通知目标频道 |

---

## 分支策略与环境映射

```
develop ──────────────────────────────→ development（Debug APK）
  │
  │  PR ───→ format + analyze + test
  │
  ▼
master ───────────────────────────────→ staging（签名 APK + Firebase 分发）
  │
  │  tag v1.0.0 ──────────────────────→ production（GitHub Release）
  │  tag v1.0.0-rc1 ─────────────────→ production（Pre-release）
  │
  ▼
hotfix/* ──→ PR 到 master ──→ 同上
```

### 环境保护规则（推荐）

在仓库 Settings → Environments 中为各环境设置保护规则：

| 环境 | 保护规则建议 |
|------|-------------|
| `development` | 无特殊限制 |
| `staging` | 需要至少 1 名审查者批准 |
| `production` | 需要至少 2 名审查者批准，仅允许 `v*` 标签触发 |

---

## 缓存策略

| 缓存类型 | 路径 | Key 策略 |
|----------|------|----------|
| Flutter/Dart 包 | 由 `subosito/flutter-action@v2` 的 `cache: true` 自动管理 | 基于 `pubspec.lock` |
| Gradle 依赖 | `~/.gradle/caches`, `~/.gradle/wrapper` | 基于 `android/**/*.gradle*` 和 `gradle-wrapper.properties` 的 hash |

这些缓存可将重复构建时间从 ~8 分钟缩短至 ~2 分钟。

---

## 快速验证

推送配置后，可通过以下方式验证：

```bash
# 本地模拟 CI 检查
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage

# 本地模拟构建
flutter build apk --debug
```

或直接提交到 `develop` 分支触发自动化管道验证。
