# Tailg Cloud App

台铃电动车的**非官方 Flutter 客户端**。通过**官方云端 API** 完成账号登录、车辆管理与远程控车（设防 / 解防 / 通电 / 断电 / 寻车 / 开坐垫），并提供电池、定位轨迹、电子围栏、消息中心与诊断日志等能力。

[![Build APK](https://github.com/ch6vip/tailg-ble-app/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/ch6vip/tailg-ble-app/actions/workflows/build.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.44.6_stable-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.12.2-0175C2?logo=dart)
![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android)
![Tests](https://img.shields.io/badge/tests-389%2B_passing-00C896)
![Coverage](https://img.shields.io/badge/coverage-81%25-00C896)

> ⚠️ 仅供**学习研究与个人车辆管理**使用。本项目为 **cloud-only**：本地 BLE 直连栈（扫描 / GATT / 协议解析 / 感应解锁）已整体移除，控车与状态同步**仅走官方云端**。高级写入（QGJ 设置、密码解锁、NFC 加钥匙、OTA、胎压 / ECU 校准）不在范围内，且无开放计划。

---

## ✨ 功能特性

| 模块 | 能力 |
|------|------|
| **账号与会话** | 短信验证码登录、退出、会话保持；粘贴 token 快速登录 |
| **车辆中心** | 账号下车辆列表 / 详情（在线、电量、电压、设防、ACC 状态）、多车快速切换、默认车辆、车库管理 |
| **云端控车** | 设防 / 解防 / 通电 / 断电 / 寻车 / 开坐垫；命令态（发送中 / 成功 / 失败 / 未确认）统一反馈 |
| **车况可信度** | 打开 App / 回前台 / 切回控车页自动刷新 `carStatus`；显示「最后同步时间」；busy 态显示「同步中」而非误报离线 |
| **电池详情** | 电量 / 电压 / 温度 / BMS 信息，环形进度，force 刷新，最后同步卡 |
| **定位与轨迹** | 停车位置、历史轨迹、电子围栏读取与写入；空态 / 刷新 / 登录引导反馈 |
| **消息中心** | 官方车辆消息 / 系统消息（`pageOfCarMsg` / `pageOfSysMsg`）、服务端清空、本地已读状态、通知偏好 |
| **骑行数据** | 月度骑行统计与碳排估算 |
| **诊断与日志** | 云端自检、历史诊断记录、运行日志（含凭据脱敏）、诊断报告导出 |

完整能力清单与官方 3.5.6 版差距见 **[FEATURES.md](FEATURES.md)**。

---

## 🧱 技术栈

| 类别 | 选型 |
|------|------|
| 框架 | Flutter **3.44.6** (stable) · Dart **3.12.2** |
| 存储 | `shared_preferences`（普通配置）· `flutter_secure_storage`（凭据） |
| 地图 / 定位 | `flutter_map` · `latlong2` · `geolocator` · `cached_network_image`（瓦片缓存） |
| 动效 / 国际化 | `lottie` · `intl` · `flutter_localizations` |
| 其他 | `url_launcher` · `cupertino_icons` |
| 质量 | `flutter_lints`(`--fatal-infos`) · `mockito` · `flutter_test` / `integration_test` |

---

## 🏗️ 项目架构

```
lib/
├── main.dart                  应用入口、路由、底部导航
├── config/                    地图瓦片等运行时配置
├── models/                    车辆状态、电池快照、命令类型、地理坐标等数据结构
├── services/                  业务逻辑（见下）
├── pages/                     各页面 UI（控车主页 / 电池 / 定位 / 车库 / 诊断 / 我的 …）
├── widgets/                   可复用组件（ControlCard / StatusBadge / VehicleStage …）
└── theme/                     设计 token（app_colors · app_motion）

test/                          约 54 个测试文件，覆盖云服务、控车路由、持久化与 UI 状态
docs/                          架构规划、对齐进度、构建与设计文档
```

### 服务分层（`lib/services/`）

- **官方云端**：`official_cloud_service` · `official_cloud_api_client` · `official_cloud_auth_parser` · `official_cloud_data_parser` · `official_cloud_storage` · `official_cloud_vehicle_sync` / `_mapper` / `_links`
- **控车管道**：`control_command_executor` · `control_command_policy`（策略校验）· `control_command_confirmation`（二次确认）· `control_command_result` · `control_channel_resolver` · `control_home_mode`
- **状态与持久化**：`vehicle_store` · `app_preferences_service` · `message_read_store` · `replica_feature_store` · `service_locator`
- **横切能力**：`log_service`（广播 stream + 脱敏）· `sensitive_value_masker` · `location_service` · `permission_service` · `app_navigation` · `display_time_formatter` · `diagnostic_export_service`

---

## 🎨 设计系统

设计语言 **v8「Aurora Cockpit」**（Ninebot 蓝本），所有颜色 / 圆角 / 阴影 / 文本样式统一收敛在 `lib/theme/`，**禁止硬编码 Material 颜色**。

| Token | 值 | 用途 |
|-------|-----|------|
| `primary` | `#00C896` 翡翠绿 | 主操作、品牌色 |
| `success` / `accentTeal` | `#00A896` | 状态确认、信息 |
| `energyGreen` | `#00C896` | 电池 / 能量指示 |
| `accentSky` | `#2E9BFF` | 标准骑行模式 |
| `warning` | `#FF9800` | 运动模式 / 警告 |
| `danger` | `#FF5252` | 警示、失败 |
| `pageBg` | `#F5F5F7` | 页面底色 |

- **交互反馈**：所有可点击元素按下 `AnimatedScale(0.96)`；`_PowerKnob` 长按 1.2s 触发通电 + busy 光环
- **无障碍**：触控目标 ≥ 44×44px（WCAG 2.5.5），对比度 ≥ 4.5:1，颜色非唯一信息载体
- **暗色**：`AppColorsDark` token 已定义（暗色主色 `#00E0A8`），已通过 `ThemeMode.system` 跟随系统；部分页面仍有硬编码对比色，后续按 token 体系扫尾

设计索引见 **[docs/design_system.md](docs/design_system.md)**。

---

## 🚀 快速开始

### 前置条件

- Flutter `3.44.6`（stable，含 Dart `3.12.2`），`flutter doctor` 全绿
- Android SDK（compileSdk 36）· Gradle 8.12（需 JDK 17 运行；Kotlin / Java 编译目标 11）
- Android 模拟器可选；**不要求**连接实体手机、车辆或蓝牙设备

### 运行

```bash
flutter pub get          # 安装依赖
flutter doctor           # 检查环境
flutter run              # 启动模拟器 / 设备后运行 debug 构建（可选）
```

### 地图瓦片 Token（可选）

默认使用**高德**瓦片兜底，无需配置。如需**天地图**，通过编译期变量注入 Token：

```bash
flutter run --dart-define=TIANDITU_TOKEN=<your-token>
flutter build apk --release --dart-define=TIANDITU_TOKEN=<your-token>
```

配置逻辑见 `lib/config/map_tile_config.dart`（有 Token → 天地图矢量 + 注记，否则 → 高德）。

---

## 📦 构建

```bash
flutter build apk --debug        # Debug APK
flutter build apk --release      # Release APK（需签名，见下）
```

**签名**：CI 通过 GitHub Secrets 注入密钥（`key.properties` 与 keystore **不入库**）。本地发布自行准备 `android/key.properties`：

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=<your-key-alias>
storeFile=../../release.keystore
```

---

## ✅ 质量门禁

提交前请保持以下门禁全绿（与 CI 完全一致）：

```bash
dart format --output=none --set-exit-if-changed .    # ① 格式
flutter analyze --fatal-warnings --fatal-infos       # ② 静态分析（0 容忍）
flutter test --coverage                              # ③ 单元 / 组件测试
dart tool/check_coverage.dart coverage/lcov.info 40  # ④ 覆盖率阈值 ≥ 40%
```

可选启用本地 pre-commit hook：

```bash
git config core.hooksPath .husky
```

**当前状态**：`analyze` 0 问题 · 约 **390** 个用例（最近全量跑：**389 通过 / 1 失败**，失败为 `test_conventions_test` 对 `clipboard_text_test` 平台 mock 约定）· 行覆盖约 **81%**（门槛 40%）。badge 与状态数字可能略滞后，以本地 `flutter test --coverage` 为准。

### CI / CD

| 工作流 | 触发 | 行为 |
|--------|------|------|
| [`build.yml`](.github/workflows/build.yml) | PR / push 到 `master`·`develop`，手动 | `format → analyze → test --coverage → 覆盖率门禁`；push 后额外构建签名 APK（arm64）artifact |
| [`release.yml`](.github/workflows/release.yml) | `v*` tag，手动 | 同门禁 → 签名 APK → 发布 GitHub Release（含 Telegram 通知） |

配置与 Secrets 说明见 **[docs/github_actions_guide.md](docs/github_actions_guide.md)**。

---

## 🔌 控车通道

当前控车通道**仅** `ControlCommandTransport.officialCloud`。云端不可用时命令返回 `unavailable`，本项目**不提供**任何本地 / 蓝牙控车通道。

> 官方云返回的车辆 JSON 仍可能包含 `btname` / `btmac` / `bleConnect*` 字段，仅作展示或兼容映射，**不驱动**任何本地蓝牙连接。

---

## 📚 文档索引

| 文档 | 用途 |
|------|------|
| [FEATURES.md](FEATURES.md) | 已实现能力、官方版差距、车辆添加策略 |
| [docs/README.md](docs/README.md) | 文档索引与阅读顺序 |
| [docs/cloud_architecture_plan.md](docs/cloud_architecture_plan.md) | 官方账号 / 云端控车架构规划 |
| [docs/cloud_only_alignment_progress.md](docs/cloud_only_alignment_progress.md) | cloud-only 对齐进度（P0 / P0.5） |
| [docs/official_3_5_6_deep_comparison.md](docs/official_3_5_6_deep_comparison.md) | 官方 3.5.6 复刻度对比 |
| [docs/design_system.md](docs/design_system.md) | 设计系统索引 |
| [docs/github_actions_guide.md](docs/github_actions_guide.md) | CI/CD 配置与 Secrets |
| [docs/android_build_notes.md](docs/android_build_notes.md) | Android 构建 warning 处理 |
| [docs/qgj_ble_residual_inventory.md](docs/qgj_ble_residual_inventory.md) | QGJ/BLE 残留清单与可删除评估 |

---

## ℹ️ 项目信息

- **版本**：`1.1.0+14`（以 `pubspec.yaml` 为准）
- **包名**：`de.tttq.tailg_ble_app`（历史包名保留；与 cloud-only 产品定位无关）
- **最低 Android**：API 23（Android 6.0）· compileSdk 36
- **发布**：仅内部 / 侧载，未上架 pub.dev（`publish_to: none`）

## 🔒 安全须知

- 严禁提交 keystore、`key.properties`、token、手机号、IMEI 及任何抓取的车辆数据
- 官方云凭据存于 `flutter_secure_storage`；日志经 `sensitive_value_masker` 脱敏，新增日志调用须沿用该模式
- 账号 / 云端相关改动需附自动化测试证据，且不得要求真机、实体车辆或蓝牙抓包

---

> 本项目与台铃官方无隶属关系，商标归各自所有者。请遵守当地法律法规，仅在你拥有合法使用权的车辆上使用。
