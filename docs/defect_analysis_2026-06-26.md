# Tailg BLE App 缺陷分析报告

> 审查日期:2026-06-26
> 审查范围:lib/ 76 个 Dart 文件、test/ 18 个测试文件、CI 配置、静态分析
> 审查方式:代码库全量扫描 + 关键路径人工复核 + `flutter analyze`

## 概述

共发现 **15 项缺陷**:P0 致命 ×1、P1 严重 ×4、P2 一般 ×6、P3 建议 ×4。

## 修复状态(截至 2026-07-03)

| 编号 | 严重度 | 状态 | 关键改动 |
|------|--------|------|----------|
| P0-1 | 致命 | ✅ 已修复 | `control_page_home_overview.dart` 感应解锁开关从 `manualModeService` 切回 `proximityService` |
| P1-2 | 严重 | ✅ 已修复 | `connection_manager.dart` 新增 `_readyWatchdog` 8s 超时,connected→ready 不再卡死 |
| P1-3 | 严重 | ✅ 已修复 | 心跳失败 + ready 超时改用 `scheduleMicrotask(_onDisconnected)`,异常不再被 Timer zone 吞 |
| P1-4 | 严重 | ✅ 已修复 | `official_cloud_auth_parser.dart` 移除 `'id'` 兜底,只匹配 `'uid'/'userId'` + 回归测试 |
| P1-5 | 严重 | ⚠️ 文档标注 | AES key 混淆本质为弱保护,在缺陷报告中明确说明,真正安全依赖服务端 |
| P2-6 | 一般 | ✅ 已修复 | QGJ 凭证迁移到 `FlutterSecureStorage`,并清理 legacy prefs |
| P2-7 | 一般 | ✅ 已修复 | `service_locator.reset()` 改调 `resetForTest()` 而非 `dispose()`,消除僵尸单例 |
| P2-8 | 一般 | ✅ 已修复 | 删除 `Forward-ServiceIp` 笔误头;`forwardServiceIp` 默认空 + 仅在非空时发送 |
| P2-9 | 一般 | ✅ 已修复 | LogService 增加 BLE 登录帧脱敏 + broadcast stream |
| P2-10 | 一般 | ✅ 已修复 | `parser.dart` token 帧显式校验最小长度 16 hex 后再切片 |
| P2-11 | 一般 | ✅ 已修复 | 全局 `homeTabIndex` 已迁移到 `AppServices` |
| P3-12 | 建议 | ✅ 已修复 | `log_page.dart` 订阅 `LogService.changes` stream 自动刷新 |
| P3-13 | 建议 | 📋 待处理 | `_ridingMode` 持久化(独立 PR) |
| P3-14 | 建议 | 📋 待处理 | 主题色硬编码迁移到 `AppColors` token(独立 PR) |
| P3-15 | 建议 | 📋 待处理 | `_initialized` + `_initializing` 抽基类(独立 PR) |

**已修复**:11 项(1 P0 + 3 P1 + 6 P2 + 1 P3)
**文档标注**:1 项(P1-5,客户端密钥混淆风险说明)
**待处理**:3 项(均为独立 PR 范畴,不阻塞当前发布)

值得注意:该轮审查中 `flutter analyze` 全绿(No issues found),但仍检出了 P0 语义反转 bug——说明此类"逻辑错配"无法被静态分析捕获,依赖集成测试与人工审查。

---

## P0 致命(1 项)

### P0-1 感应解锁开关错接 ManualModeService + 状态反转

- **文件**:`lib/pages/control_page_home_overview.dart:40-43, 319-323, 499`
- **类别**:可靠性 / 安全
- **问题**:
  - v8 首页"感应解锁"开关的 `_toggleProximity(value)` 调用的是 `manualModeService.setEnabled(value)`,而非 `proximityService.setEnabled(value)`。
  - `ManualModeService.enabled=true` 语义是"手动模式 = 禁用自动控车"(见 `manual_mode_service.dart:5-10`、`proximity_service.dart:109` 的 `if (ManualModeService().enabled) return;`)。
  - `_proximityEnabled = manualModeService.enabled` 直接绑定,导致 UI 显示反转:开关亮 = 实际已禁用。
  - `proximityService.setEnabled` 在全库**零调用**(grep 确认),即真正的感应解锁服务从未被 UI 开关控制。
- **影响**:用户点"开启感应解锁"→ 实际关闭;开关显示"已开启"→ 实际禁用。双重错误,直接危及车辆自动解锁安全功能。
- **对照**:`control_page_vehicle_overview.dart:15` 的 `_ManualModePill` 正确地把 `manualModeService.enabled` 当"手动模式"显示,反衬出 `_proximityEnabled` 的错配。
- **测试盲区**:`manual_mode_service_test.dart` 只测 service 本身,未覆盖 UI 绑定层;无 control_page_home_overview 的"开关 → ProximityService"集成测试。
- **修复**:`_toggleProximity` 改为调用 `proximityService.setEnabled(value)`;`_proximityEnabled` 绑定 `proximityService.enabledStream`;移除对 `manualModeService` 的误绑定。

---

## P1 严重(4 项)

### P1-2 BLE connected → ready 无超时保护

- **文件**:`lib/ble/connection_manager.dart:188-200, 305-319`
- **问题**:`connect()` 在 `_setState(connected)` 后等待 TokenResponse / QGJ-login 通知才切到 `ready`。若 `_writeChar`/`_feb1Char`/`_feb2Char` 为 null,仅跳过写入不抛错;若设备不回 token 或 QGJ notify 未订阅(`_feb2Char==null` 时 `_notifySub` 永不创建),状态永久卡在 `connected`,UI 永久"连接中"。
- **修复**:为 connected → ready 增加超时(如 8s),超时后回退 disconnected 并触发重连。

### P1-3 心跳线程内同步调用 _onDisconnected

- **文件**:`lib/ble/connection_manager.dart:707-726`
- **问题**:`_startHeartbeat.tick()` 失败 5 次后直接 `_onDisconnected()`,其内部 `_notifySub?.cancel()` 等 async 未 await,`_attemptReconnect` 是 fire-and-forget Future,异常冒泡到 Timer zone 被 swallow。
- **修复**:心跳失败后通过独立 microtask 调度断连处理,确保异常可见。

### P1-4 _findUserId 用 'id' 兜底误匹配

- **文件**:`lib/services/official_cloud_auth_parser.dart:34-53`
- **问题**:递归遍历响应树查找 'uid'/'userId'/'id','id' 过于通用,会误命中 `carId`/`deviceTravelId`/`extendId` 等字段,导致 userId 错误,后续轨迹查询可能失败或泄露他人数据。
- **修复**:移除 'id' 兜底,仅匹配 'uid'/'userId';或限定匹配层级。

### P1-5 AES key 伪混淆(安全假象)

- **文件**:`lib/ble/constants.dart:1-50`
- **问题**:`_keyMask = 0x5A3C6F91D2E84B7A` 硬编码,XOR 单步可逆。8 个车型 AES key 运行时 `_deobfuscate` 还原,反编译 APK 即可拿到全部密钥,可伪造 BLE 命令帧。
- **评估**:客户端密钥本就无法真正保密,但当前"混淆"给人虚假安全感。建议文档明确这是混淆而非防护,真正安全依赖服务端校验/会话。

---

## P2 一般(6 项)

### P2-6 QGJ 凭证明文存储

- **文件**:`lib/models/vehicle_profile.dart:119-128` + `lib/services/vehicle_store.dart:231-243`
- **问题**:`qgjLoginPassword`/`qgjUserId` 经 `toJson` 直接 `jsonEncode` 进 `SharedPreferences`(明文 XML)。root 设备或备份提取可读。对比 `official_cloud_storage.dart` 已迁 `FlutterSecureStorage`,BLE 凭证未迁。
- **修复**:`VehicleStore` 已将 QGJ 凭证写入 `FlutterSecureStorage`;持久化车辆列表前通过 `_profileJsonWithoutQgjCredentials` 剥离明文字段,并在加载 legacy prefs 时迁移后清理。`vehicle_store_test.dart` 覆盖写入、迁移和删除清理。

### P2-7 AppServices.reset() 误用单例

- **文件**:`lib/services/service_locator.dart:76-79`
- **问题**:`reset()` 调 `_instance.dispose()` 会关闭 `OfficialCloudService._stateController` 等广播流并置 `_disposed=true`。但各 service 是 factory 单例,`production()` 返回的仍是已 dispose 的同一实例(僵尸对象)。
- **修复**:reset 仅用于测试,需重建单例或文档强警告;生产路径禁止调用。

### P2-8 双重 Forward-Service-Ip 头笔误 + localhost 默认

- **文件**:`lib/services/official_cloud_api_client.dart:91-100`
- **问题**:同时存在 `Forward-Service-Ip` 与 `Forward-ServiceIp`(拼写不同),应为笔误;且 `forwardServiceIp` 默认 `'localhost'`,生产若未覆盖,所有云请求携带 `Forward-Service-Ip: localhost`。
- **修复**:删除重复头;localhost 默认值改为空或必填校验。

### P2-9 日志无脱敏且无 stream 推送

- **文件**:`lib/services/log_service.dart:23-78` + `lib/pages/log_page.dart:96,122`
- **问题**:`LogService.ble(detail:...)` 直接记录原始 hex 帧,含 QGJ 登录帧(password/userId);BLE 类目 detail 未被 `OfficialCloudRedactor` 的 phone/imei/mac 正则覆盖,凭据可能落盘可复制。另:日志无 stream,UI 靠 `setState(() {})` 空刷新。
- **修复**:对 BLE 登录帧脱敏;LogService 增加 broadcast stream。

### P2-10 协议帧前缀硬编码 magic byte,容错路径不明

- **文件**:`lib/ble/parser.dart:43-100`
- **问题**:`_tokenPrefix='78000000'` 等用 `startsWith` 匹配,但解密后 hex 仅检查 `< 10`,未校验最小帧长 32 hex;若解密出非预期格式但前 4 字节巧合匹配,`hex.substring(8,16)` 切片可能越界,目前靠外层 try/catch 兜底返回 UnknownResponse,容错路径不明确。
- **修复**:显式校验最小帧长后再切片。

### P2-11 全局可变 ValueNotifier

- **文件**:`lib/main.dart:40`
- **问题**:`final homeTabIndex = ValueNotifier<int>(0);` 顶级可变单例,跨页面共享,违反单一数据源原则,易产生监听器泄漏。
- **修复**:`homeTabIndex` 已收敛为 `AppServices.homeTabIndex`;`main.dart` 仅保留顶层 getter 委托 `AppServices.instance`,并由 `service_locator_test.dart` 覆盖 override/reset 行为。

---

## P3 建议(4 项)

| 编号 | 文件 | 问题 |
|------|------|------|
| P3-12 | `lib/pages/log_page.dart:96,122` | 已修复:`LogService.changes` stream 驱动日志页刷新 |
| P3-13 | `lib/ble/connection_manager.dart:660` | `_ridingMode` 未持久化,重连后默认回 standard |
| P3-14 | `profile_page.dart` 等 30+ 处 | 主题色硬编码 `Color(0xFF...)` 未走 `AppColors` token,无 dark mode 适配 |
| P3-15 | `auto_connect_service.dart` 等 4 个 service | `_initialized` + `_initializing` 双标志重复,可抽基类 |

---

## 测试与质量门禁评估

### 测试覆盖
- 当前 test/ 共 36 个 `*_test.dart` 文件,覆盖协议解析(ble_parser)、云服务(official_cloud)、车辆存储(vehicle_store)、控车页生命周期、位置页重建结构、proximity / auto_connect / manual_mode service 等。
- **盲区**:
  - UI 绑定层测试薄弱,P0-1 的"开关 → 服务"绑定未被任何测试覆盖。
  - 无 connection_manager connected → ready 超时场景测试。
  - `official_cloud_auth_parser` 的 generic `id` 误匹配已有 P1-4 回归测试。

### 静态分析
- `flutter analyze`:**No issues found**(全绿)。
- **局限**:语义错配(P0-1)、逻辑反转、服务错接类 bug 无法被静态分析捕获。

### CI
- `.github/workflows/build.yml` 的 ci job 已覆盖 format → analyze → test 三道门禁。
- `.github/workflows/release.yml` 已在发布前执行 format → analyze → test,并作为唯一 `v*` tag Release 发布入口。
- AGENTS.md 与 `docs/github_actions_guide.md` 已对齐当前 `build.yml`/`release.yml` 配置;当前仍无 coverage 上传步骤。

---

## 后续优先级建议

1. **P3-13**:`_ridingMode` 持久化,避免重连后回落默认模式。
2. **P3-14**:主题色硬编码迁移到 `AppColors`/token 体系,降低暗色模式适配成本。
3. **P3-15**:`_initialized` + `_initializing` service init guard 抽象化,减少重复状态机。
4. **P1-5 安全债**:继续明确客户端密钥混淆只能降低静态暴露,不能替代服务端校验。
5. **测试补强**:补 UI 开关 → Service 绑定、连接状态机超时的集成测试。
