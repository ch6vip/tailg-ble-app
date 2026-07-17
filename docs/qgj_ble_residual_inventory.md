# QGJ / BLE 残留清单与可删除评估

> 状态：**审计清单（2026-07-16）**  
> 范围：当前工作区 `lib/`、`test/`、包名与平台工程；不含 Git 历史中的已删 `lib/ble/`。  
> 产品边界：cloud-only；本地 BLE 栈已移除，**不恢复** GATT / 扫描 / 感应解锁。

本文回答审计项 **C**：哪些 QGJ/BLE 痕迹还在、是否仍被运行时依赖、能否删、建议怎么删。

---

## 1. 结论摘要

| 类别 | 可否删除 | 说明 | 状态（2026-07-16） |
|------|----------|------|--------------------|
| **QGJ 登录密码 / userId 全套** | **可删（推荐）** | 生产 UI 无写入路径；仅 store + 测试 + secure 残留 | **已删除**（`VehicleProfile` / `VehicleStore` 出清；prefs 加载时 scrub 旧字段） |
| **`QgjSoundEffectsPage`** | **可删（推荐）** | 无任何导航入口，死页面 | **已删除** |
| **`LogService.connection` + QGJ 帧脱敏** | **可精简** | 生产代码零调用 `connection()`；仅测试与日志页分类 UI | **已精简**（删除 `connection` 分类/方法；日志页单列表；login 帧通用脱敏） |
| **`VehicleProtocol` / `protocol: qgj` 标签** | **暂保留或弱化** | 云同步仍按 `btname` 打标；诊断导出展示；**不驱动控车** | 保留 |
| **云 JSON 字段 `btname` / `btmac` / `bleConnect*`** | **不可删** | 官方 API 字段；本地车库 ID、展示名、停车位置依赖 | 保留 |
| **包名 / 工程名 `tailg_ble_app`** | **暂不删** | 改 applicationId 等于换包，升级/覆盖安装成本高 | 保留 |
| **文档中的 BLE 历史叙述** | **保留** | 已标归档/已移除，防止误恢复 | 保留 |

**已完成切片**：PR-C1（死页面）· PR-C2（QGJ 凭据出清）· PR-C3（日志 connection 分类精简）。  
**下一步**：无必做清理项；包名 rename 仍不做。

---

## 2. 运行时依赖图（保留理由）

```text
官方 carStatus / 车辆列表 JSON
  ├─ btmac  ──► OfficialVehicle.normalizedDeviceMac ──► 本地 VehicleProfile.id
  ├─ btname ──► displayName 回退 + VehicleProtocol 启发式 (Q_BASH/QGJ/Q_)
  └─ bleConnectLat/Lng/Time/Address ──► 停车位置 (VehicleLocationResolver)

云控车路径：仅 token + commandImei + HTTP cmd/*
  └─ 不读取 qgjLoginPassword / qgjUserId / BLE 连接
```

**要点**：蓝牙相关字段是**云数据兼容与本地身份映射**，不是本地蓝牙驱动。

---

## 3. 代码清单（按可删性）

### 3.1 建议删除 — QGJ 凭据（无生产调用方）

| 位置 | 符号 / 行为 | 生产调用 | 评估 |
|------|-------------|----------|------|
| `lib/models/vehicle_profile.dart` | `qgjLoginPassword`, `qgjUserId`, `hasQgjCredentials`, `clearQgjCredentials` | 仅序列化/反序列化与 store | **可删字段**；读旧 JSON 时忽略即可 |
| `lib/services/vehicle_store.dart` | `_secureQgjPasswordPrefix`, `_secureQgjUserIdPrefix` | hydrate on init | **可删** secure 键读写 |
| 同上 | `_hydrateQgjCredentials`, `_containsLegacyQgjCredentials` | init 路径 | **可删**；改为忽略旧键或一次性 delete |
| 同上 | `updateQgjCredentials` | **全库无 lib 调用方**（仅 test） | **可删 public API** |
| 同上 | `_profileJsonWithoutQgjCredentials` | 写 prefs 时剥离明文 | 随字段删除可简化为普通 `toJson` |
| `test/vehicle_store_test.dart` | 多处 QGJ 凭证用例 | — | 随删除改写/删除 |
| `lib/services/log_service.dart` | `_loginHint` + login frame 整段 redact | message 匹配「登录|login」时整段脱敏 | **已通用化**（随 PR-C3） |
| `test/log_service_test.dart` | `keeps login frame details fully redacted` | — | **已改为通用 login 用例** |

**删除时注意**

1. 升级用户可能仍有 secure 中 `vehicle_qgj_password:*` 键：建议 init 时 **批量 delete 前缀键**（若平台 API 不便枚举，可文档说明残留无害且不再读取）。
2. prefs 中旧 `vehicle_profiles` JSON 若仍含 `qgjLoginPassword`：parser 用 `parsePersistedInt` 读后丢弃，或 `fromJson` 直接不读即可。
3. 测试覆盖迁移：`vehicle_store_test` 中 protocol 映射用例可保留；凭证 round-trip 用例删除。

### 3.2 建议删除 — 死页面

| 位置 | 说明 |
|------|------|
| `lib/pages/official_replica_pages.dart` → `QgjSoundEffectsPage` | **零引用**（无 `Navigator` / 路由 / 导出使用） |
| 相关本地音效 UI 文案 | 纯占位，不写云、不写车 |

删除后确认 `official_replica_pages_test.dart` 是否引用该类（当前检索仅定义处）。

### 3.3 已精简 — 日志「连接」分类（BLE 时代命名）

| 位置 | 说明 | 状态 |
|------|------|------|
| `LogCategory.connection` | 已删除；仅保留 `operation` | **已完成** |
| `LogService.connection()` | 已删除 | **已完成** |
| `lib/pages/log_page.dart` | 去掉 Tab，单列表展示全部操作日志 | **已完成** |
| 诊断导出 `[CONN]` | 统一为 `[OP]` | **已完成** |

### 3.4 暂保留 — 协议枚举与展示（不驱动控车）

| 位置 | 说明 | 评估 |
|------|------|------|
| `VehicleProtocol` (`auto` / `standard` / `qgj`) | 本地档案字段 | 云同步仍写入；诊断导出 `Protocol: …` |
| `OfficialCloudVehicleMapper._protocolForOfficialVehicle` | 按 `btname` 前缀判 QGJ | **展示/档案标签**；删除会改变同步行为与测试 |
| `diagnostic_export_service` `Protocol:` 行 | 用户导出信息 | 可保留；或改为「云同步标签」文案 |

若未来要「去 QGJ 字样」：可把枚举值改成中性 `legacyNamed` / 仅存字符串 `btnamePrefixClass`，**不必**再叫 QGJ；工作量中等，收益主要是叙事清晰。

### 3.5 必须保留 — 官方云字段与定位

| 位置 | 字段 | 用途 |
|------|------|------|
| `OfficialVehicle` | `btname`, `btmac` | 身份键、展示名、协议启发、诊断脱敏展示 |
| `OfficialVehicleLocation` | `bleConnectTime/Lat/Lng/Address` | **停车位置**（命名来自官方，语义是车辆最后上报位置） |
| `vehicle_location_resolver.dart` | 读上述字段 | 控车页/定位页坐标 |
| `official_cloud_data_parser` | 非空判定含 btmac/btname | 解析有效性 |
| `OfficialCloudRedactor` / `SensitiveTextRedactor` | 脱敏 `btmac`/`mac` | 安全 |
| `diagnostic_export_service` | BT name / BT MAC 行 | 诊断（MAC 已 compact mask） |
| 车辆 JSON 扩展键名 | `bleRenewal`, `bluetoothRenewal`, … | 仅键名常量，展示/兼容 |

**不要**为了「去掉 BLE 字样」重命名这些 **JSON 键**（会与官方 API 断裂）。若需 UI 文案中性，仅在展示层写「设备 MAC / 停车时间」即可。

### 3.6 暂不改 — 工程身份

| 位置 | 说明 |
|------|------|
| `pubspec.yaml` `name: tailg_ble_app` | Dart 包名；全库 `package:tailg_ble_app/...` import |
| `applicationId` / `namespace` `de.tttq.tailg_ble_app` | Android 身份；改则侧载用户无法覆盖升级 |
| `TailgBleApp` 类名 | 可择机改名 `TailgCloudApp`，纯符号，低风险中工作量 |
| 地图 `userAgentPackageName` | 与 applicationId 对齐 |
| CI artifact 名 `tailg-ble-…` | 文档/脚本约定 |

### 3.7 文档中的 BLE/QGJ（保留并继续标历史）

- `FEATURES.md`、`docs/cloud_architecture_plan.md`、`docs/archive/工程审视报告_*`、`docs/archive/device_regression_checklist_*` 等已标明 **已移除 / 不执行**。
- **不要**从文档抹掉「已删除 BLE」——否则后人可能以为该恢复。

---

## 4. 测试侧引用（随删除联动）

| 文件 | 内容 | 删除凭据时 |
|------|------|------------|
| `test/vehicle_store_test.dart` | `updateQgjCredentials`、`hasQgjCredentials`、protocol qgj | 删凭证用例；可留 protocol 持久化 |
| `test/official_cloud_test.dart` | mapper → `VehicleProtocol.qgj`、btmac 身份 | **保留**（云映射契约） |
| `test/log_service_test.dart` | QGJ 登录帧 redact | 改通用用例或删 |
| `test/diagnostic_export_service_test.dart` | btname/btmac、password=qgj-secret 脱敏样例 | 脱敏样例可改中性字符串 |
| 其它 widget 测试 | fixture 中 `btmac` / `bleConnect*` | **保留**（模拟官方 JSON） |

---

## 5. 建议删除 PR 切片

### PR-C1（小、安全）：死页面 — **已完成**

- 删除 `QgjSoundEffectsPage` 及仅服务于它的私有 widget/状态
- 确认无路由引用

### PR-C2（中）：QGJ 凭据出清 — **已完成**

1. 从 `VehicleProfile` 移除 `qgjLoginPassword` / `qgjUserId` / `hasQgjCredentials` / `clearQgjCredentials`
2. 删除 `VehicleStore.updateQgjCredentials` 与 secure 读写 hydrate（`VehicleStore` 不再依赖 `flutter_secure_storage`）
3. `_save` 直接 `toJson`，无凭据字段
4. init 时若 prefs 原始 JSON 含 legacy 字段则 re-persist scrub
5. 更新 `vehicle_store_test` 凭证相关用例为 scrub/忽略行为

### PR-C3（小）：日志分类 — **已完成**

- 删除 `LogCategory.connection` / `connection()`；仅保留 `operation`
- 日志页去掉「全部/连接/操作」Tab，改为单列表
- 诊断导出统一 `[OP]` 标签
- `_qgjLoginHint` 改为通用 `_loginHint`（登录|login）
- 保留 `SensitiveTextRedactor` 通用脱敏（与 QGJ 无关，**必留**）

### 明确不做（除非立项）

- 删除 `btmac`/`btname`/`bleConnect*` 模型字段  
- 恢复任何 BLE 栈  
- 仅因叙事改 `applicationId`

---

## 6. 风险与回滚

| 风险 | 缓解 |
|------|------|
| 旧安装残留 QGJ secure 键 | 停止读取即可；可选清理 |
| 旧 JSON 含 qgj 字段 | `fromJson` 忽略未知/废弃键 |
| 测试依赖 protocol=qgj | 映射测试独立保留 |
| 误删 btmac 导致车库 ID 全丢 | **禁止**在 C2 中改 identity 逻辑 |

回滚：单 PR 粒度，git revert 即可。

---

## 7. 与审计 A 的交叉

- README 已声明高级写入含「QGJ 设置」不在范围——与本清单「可删凭证」一致。  
- 包名仍含 `ble` 属**历史身份**，不是功能回潮；项目信息中已注明。

---

## 8. 检查命令（删除 PR 用）

```bash
# 残留检索（删除后应只剩云字段 / 文档 / 包名）
rg -n "qgjLoginPassword|updateQgjCredentials|QgjSoundEffects|hasQgjCredentials" lib test

# 门禁
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-warnings --fatal-infos
flutter test --coverage
dart tool/check_coverage.dart coverage/lcov.info 40
```

预期：PR-C2 后 `rg` 在 `lib/` 对凭据 API 应为空；`btmac`/`bleConnect`/`VehicleProtocol.qgj` 仍可存在。
