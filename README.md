# Tailg BLE App

台铃电动车的非官方 Flutter 客户端：通过 **蓝牙（BLE）** 直连车辆进行解锁、设防、寻车、开座桶等控制，并可桥接 **官方云端** 完成账号登录、车辆列表/详情和远程控车。配套设计语言为「极简高端」（暖白底 + 黑色主操作 + teal 强调）。

> 仅供学习与个人车辆管理使用。高级写入（QGJ 设置、密码解锁、NFC 加钥匙、OTA）需真机验证后再逐步开放。

## 功能特性

- **本地 BLE 控车**：解锁、设防、寻车、开座桶、通电、断电。
- **QGJ（Q_BASH）协议**：登录、心跳、重连、骑行模式、光感、声音、震动灵敏度，以及一组高级只读状态（自动锁车、感应距离、电子龙头锁、边撑、坐垫、侧翻检测等）。
- **官方云端**：短信验证码登录、官方车辆列表/详情、BLE / 云端 / 自动三态控车通道、基础云端控车。
- **车辆管理**：本地车库、默认车辆、多车切换、自动连接、感应解锁（基于 RSSI 邻近）。
- **信息与诊断**：电池 / BMS 详情、设备信息、OTA 前置检测、故障诊断、运行日志与诊断报告。
- **地图与轨迹**：基于 `flutter_map` 的位置 / 轨迹 / 电子围栏（OSM 兜底，可配置天地图 Token）。

完整能力与官方版本差距见 [FEATURES.md](FEATURES.md)。

## 技术栈

| 类别 | 选型 |
|------|------|
| 框架 | Flutter 3.32.1 (stable) · Dart 3.8.1 |
| BLE | `flutter_blue_plus` |
| 存储 | `shared_preferences`（普通配置）· `flutter_secure_storage`（凭据） |
| 地图 / 定位 | `flutter_map` · `latlong2` · `geolocator` |
| 加密 | `encrypt`（标准协议 AES） |
| 其他 | `permission_handler` · `url_launcher` · `intl` |

## 项目结构

```
lib/
  ble/        BLE 协议解析、GATT 常量、连接管理（串行队列防竞争）
  services/   云端 API、持久化、控车通道路由、邻近解锁等业务逻辑
  models/     车辆状态与云端遥测数据结构
  pages/      各页面 UI（控车主页 / 扫描 / 地图 / 设置 / 车库 / 诊断 …）
  widgets/    可复用组件（滑动点火、统一外框等）
  theme/      设计 token（颜色 / 圆角 / 间距 / 文本样式）
test/         云服务与协议路由的单元测试
docs/         规划、验证、构建等技术文档（见下文「文档」）
```

## 快速开始

### 前置条件

- Flutter `3.32.1`（stable，含 Dart `3.8.1`），`flutter doctor` 全绿
- Android SDK 34 + Build Tools 34.0.0，JDK 17
- 一台开启 USB 调试的 Android 设备或模拟器（BLE 功能需真机，建议 Android 6.0 / API 23+）

### 运行

```bash
# 安装依赖
flutter pub get

# 检查环境
flutter doctor

# 连接设备后运行（debug）
flutter run
```

## 构建

```bash
# Debug APK
flutter build apk --debug

# Release APK（本地需配置签名，见下）
flutter build apk --release
```

签名：CI 通过 `android/key.properties` + `release.keystore` 完成签名（密钥经 GitHub Secrets 注入，不入库）。本地发布需自行准备 `key.properties`：

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=<your-key-alias>
storeFile=../../release.keystore
```

## 测试与质量门禁

提交前请保持以下门禁全绿（与 CI 一致）：

```bash
dart format --output=none --set-exit-if-changed .   # 格式
flutter analyze --fatal-warnings --fatal-infos        # 静态分析
flutter test --coverage                               # 单元测试与覆盖率
dart tool/check_coverage.dart coverage/lcov.info 40   # 覆盖率阈值
```

可选启用本地 pre-commit hook：

```bash
git config core.hooksPath .husky
```

CI（[.github/workflows/build.yml](.github/workflows/build.yml)）：PR 到 `master`、`develop` 时自动执行 `format → analyze → test --coverage → coverage >= 40%`；需要临时 APK 时手动运行该 workflow，门禁通过后构建签名 APK artifact。普通 push 不触发自动编译。

Release（[.github/workflows/release.yml](.github/workflows/release.yml)）：推送 `v*` tag 或手动触发时执行同样门禁，随后签名构建 APK 并发布 GitHub Release。

## BLE 协议概览

| 协议 | 服务 | 说明 |
|------|------|------|
| 标准协议 | `fee5` | AES 加密，覆盖 KKS/BB/AX/JD/HJ/JW/XL/YY 等车型 |
| QGJ (Q_BASH) | `feb0` / `fcc0` | 3 通道 kuyi 协议；`feb3` 为实时遥测心跳通道 |

解析层对畸形帧做长度 / 魔数校验，不会崩溃；GATT 读写经串行队列执行以避免竞争。

## 控车通道路由

控车请求按「BLE / 官方云端 / 自动」三态路由（纯函数实现，已被单测覆盖）：BLE 直连优先，必要时回退云端，自动模式按连接状态择优。

## 文档

| 文档 | 用途 |
|------|------|
| [docs/README.md](docs/README.md) | 文档索引与阅读顺序 |
| [FEATURES.md](FEATURES.md) | 已实现能力、官方 3.5.6 差距、工程结构 |
| [docs/official_3_5_6_deep_comparison.md](docs/official_3_5_6_deep_comparison.md) | 官方版本复刻度对比简报 |
| [docs/cloud_architecture_plan.md](docs/cloud_architecture_plan.md) | 官方账号 / 云控车 / BLE 兜底规划 |
| [docs/design_system.md](docs/design_system.md) | 当前设计系统索引 |
| [docs/first_batch_verification.md](docs/first_batch_verification.md) | 真机验证清单 |
| [docs/android_build_notes.md](docs/android_build_notes.md) | Android 构建 warning 与处理 |

## 项目信息

- 包名：`de.tttq.tailg_ble_app`
- 最低 Android：建议 API 23+（BLE 需要）
- 仅发布到内部 / 侧载，未上架 pub.dev（`publish_to: none`）
