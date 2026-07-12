# Tailg Cloud App

台铃电动车的非官方 Flutter 客户端：通过 **官方云端** 完成账号登录、车辆列表/详情和远程控车（解锁、设防、寻车、开坐垫、通电、断电等）。配套设计语言为「极简高端」（暖白底 + 黑色主操作 + teal 强调）。

> 仅供学习与个人车辆管理使用。高级写入（QGJ 设置、密码解锁、NFC 加钥匙、OTA）不在当前 cloud-only 范围内，不提供开放计划。

## 功能特性

- **官方云端控车**：短信验证码登录、官方车辆列表/详情、云端命令下发与状态同步。
- **车辆中心**：账号下已绑定车辆展示、默认车辆切换、车库管理。
- **信息与诊断**：电池详情、云端自检、运行日志与诊断报告导出。
- **地图与轨迹**：基于 `flutter_map` 的位置 / 轨迹 / 电子围栏（OSM 兜底，可配置天地图 Token）。

> 本地 BLE 直连栈（扫描、GATT、协议解析、感应解锁）已移除，当前版本为 cloud-only。

完整能力与官方版本差距见 [FEATURES.md](FEATURES.md)。

## 技术栈

| 类别 | 选型 |
|------|------|
| 框架 | Flutter 3.44.6 (stable) · Dart 3.12.2 |
| 存储 | `shared_preferences`（普通配置）· `flutter_secure_storage`（凭据） |
| 地图 / 定位 | `flutter_map` · `latlong2` · `geolocator` |
| 其他 | `url_launcher` · `intl` · `cached_network_image` |

## 项目结构

```
lib/
  services/   云端 API、持久化、控车通道路由、日志、定位等业务逻辑
  models/     车辆状态与云端遥测数据结构
  pages/      各页面 UI（控车主页 / 地图 / 设置 / 车库 / 诊断 …）
  widgets/    可复用组件（滑动点火、统一外框等）
  theme/      设计 token（颜色 / 圆角 / 间距 / 文本样式）
test/         云服务与 UI 的单元/组件测试
docs/         规划、验证、构建等技术文档
```

## 快速开始

### 前置条件

- Flutter `3.44.6`（stable，含 Dart `3.12.2`），`flutter doctor` 全绿
- Android SDK 34 + Build Tools 34.0.0，JDK 17
- Android 模拟器可选；不要求连接实体手机或车辆

### 运行

```bash
# 安装依赖
flutter pub get

# 检查环境
flutter doctor

# 启动模拟器后运行（debug，可选）
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

CI（[.github/workflows/build.yml](.github/workflows/build.yml)）：PR 到 `master`、`develop` 时自动执行 `format → analyze → test --coverage → coverage >= 40%`；push 到 `master`、`develop` 时会先跑同样门禁，随后自动构建签名 APK artifact。

Release（[.github/workflows/release.yml](.github/workflows/release.yml)）：推送 `v*` tag 或手动触发时执行同样门禁，随后签名构建 APK 并发布 GitHub Release。

## 控车通道

当前控车通道仅使用 **官方云端**（`ControlCommandTransport.officialCloud`）。云端不可用时返回 `unavailable`，本项目不提供其他控车通道。

## 文档

| 文档 | 用途 |
|------|------|
| [docs/README.md](docs/README.md) | 文档索引与阅读顺序 |
| [FEATURES.md](FEATURES.md) | 已实现能力、官方 3.5.6 差距、工程结构 |
| [docs/official_3_5_6_deep_comparison.md](docs/official_3_5_6_deep_comparison.md) | 官方版本复刻度对比简报 |
| [docs/cloud_architecture_plan.md](docs/cloud_architecture_plan.md) | 官方账号 / 云控车规划 |
| [docs/design_system.md](docs/design_system.md) | 当前设计系统索引 |
| [docs/device_regression_checklist_v1_0_13.md](docs/device_regression_checklist_v1_0_13.md) | 已废弃的真机/BLE 历史清单 |
| [docs/android_build_notes.md](docs/android_build_notes.md) | Android 构建 warning 与处理 |

## 项目信息

- 包名：`de.tttq.tailg_ble_app`（历史包名保留）
- 最低 Android：建议 API 23+
- 仅发布到内部 / 侧载，未上架 pub.dev（`publish_to: none`）
