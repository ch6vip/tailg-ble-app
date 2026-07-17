# BLE 适配实验进度（feature/ble-adaptation）

> 状态：**实验分支进行中**  
> 建立：2026-07-17  
> 更新：2026-07-17  
> 分支：`feature/ble-adaptation`（自 `master` a9e1b5d 切出）  
> 定位：在**不修改 master 产品边界文档**的前提下，评估并试做本地 BLE 恢复路径  
> 上游背景：`58b320e` 曾完整移除 BLE 栈；`docs/qgj_ble_residual_inventory.md` / `docs/cloud_only_alignment_progress.md` 仍写 cloud-only

---

## 0. 重要边界（读前必看）

1. **本文件只描述实验分支**，不代表 `master` 已改为 hybrid 产品。
2. **暂不改** `AGENTS.md`、`cloud_only_alignment_progress.md`、`qgj_ble_residual_inventory.md` 中的「不恢复 BLE」表述；方案稳定后再统一更新。
3. 目标是可编译、可单测、可真机联调的 **spike**，不是一次性完整恢复历史 BLE 产品面。
4. 历史参考基线：`58b320e^`（移除前最后一版完整 BLE 实现）。

---

## 1. 目标与非目标

### 1.1 目标
- 恢复本地 BLE **协议层 / 连接层 / 扫描入口**
- 控车通道支持 **BLE 优先 + 云端回退（automatic）**
- 用单测锁定纯逻辑与通道路由，降低回归成本
- 产出可继续迭代的优先级清单

### 1.2 非目标（当前不做）
- 不在 `master` 上直接合入并改产品定位
- 不恢复完整历史设置页（OTA / QGJ 高级设置 / 设备信息页）
- 不恢复感应解锁（Proximity）为首批范围
- 不恢复本地 QGJ 登录密码/userId 持久化（仍固定 0 默认，待真机决策）
- 不改 applicationId / 包名

---

## 2. 进度看板

| ID | 项 | 状态 | 备注 |
| --- | --- | --- | --- |
| B0 | 调研旧 BLE 栈与恢复成本 | **已完成** | 对照 `58b320e` / `58b320e^` |
| B1 | 纯逻辑协议层恢复 + 单测 | **已完成** | `8ad0ee5` |
| B2 | ConnectionManager + 平台权限 | **已完成** | `9cbc0f7` |
| B3 | Service locator / 扫描 / 自动连接 / 双通道控车 | **已完成** | `f269f2a` |
| B4 | 真机联调冒烟（扫描→连接→指令） | **未开始** | P0 最高优先 |
| B5 | 启动/回前台触发 `tryAutoConnect` | **未开始** | 服务已 init，触发点待补 |
| B6 | QGJ 凭据策略决策与实现 | **未开始** | 依赖真车协议 |
| B7 | 爱车页 BLE/通道状态可见 | **未开始** | P1 |
| B8 | 通道偏好持久化（自动/仅BLE/仅云） | **未开始** | P1 |
| B9 | 权限/失败文案统一 | **未开始** | P1 |
| B10 | Proximity 感应解锁 | **暂缓** | P2 |
| B11 | 设备信息 / OTA / QGJ 高级设置 | **暂缓** | P2 |
| B12 | 更新产品边界文档并解禁 | **暂缓** | 方案稳定后 |

### 进度统计
- 已完成：**B0–B3**
- 未开始（P0/P1）：**B4–B9**
- 暂缓：**B10–B12**

---

## 3. 已落地提交

| Commit | 说明 |
| --- | --- |
| `8ad0ee5` | `feat(ble): restore pure protocol logic layer and tests` |
| `9cbc0f7` | `feat(ble): restore connection manager and platform BLE permissions` |
| `f269f2a` | `feat(ble): wire hybrid control, scan page, and service locator` |

远端分支：`origin/feature/ble-adaptation`

---

## 4. 当前架构（实验态）

```text
UI
  添加车辆 → 扫描附近车辆 → ScanPage
  爱车页 VehicleControlHomePage
        │
        ▼
ControlChannelResolver (automatic | ble | officialCloud)
        │
        ├─ BLE ready → ConnectionManager.sendCommand
        └─ else      → OfficialCloudService.sendCommand (HTTP)

AppServices
  connectionManager
  autoConnectService
  manualModeService
  officialCloudService / vehicleStore / ...
```

### 4.1 协议层（`lib/ble/`）
| 文件 | 职责 |
| --- | --- |
| `hex.dart` | hex 编解码 |
| `aes.dart` | AES-ECB 加解密（依赖 `encrypt`） |
| `protocol.dart` | Standard 帧（token / command） |
| `qgj_protocol.dart` | QGJ `0xA7` 帧 |
| `parser.dart` | Standard 响应解析 |
| `constants.dart` | UUID、时序、ModelType 密钥、BikeState 等 |
| `connection_manager.dart` | 扫描后的连接/握手/收发/重连状态机 |

### 4.2 服务与控车
| 组件 | 现状 |
| --- | --- |
| `ControlCommandTransport` | `ble` / `officialCloud` / `unavailable` |
| `ControlChannelResolver` | 默认 `automatic`：BLE ready 优先 |
| `ControlCommandExecutor` | 按 availability 路由 BLE/云 |
| `AutoConnectService` | 已恢复；**尚未在启动路径主动 tryAutoConnect** |
| `ManualModeService` | 已恢复；手动模式跳过自动连接 |
| `AppPermissionService.requestBleScanPermissions` | 已恢复 |

### 4.3 平台
- 依赖：`flutter_blue_plus`、`encrypt`、`permission_handler`
- Android：`BLUETOOTH*` + `bluetooth_le` feature
- iOS：`NSBluetooth*` + `bluetooth-central` background mode

### 4.4 入口
- `AddVehiclePage` →「扫描附近车辆」→ `ScanPage`
- 连接成功：`vehicleStore.upsert(..., makeDefault: true)`
- 爱车控车：`VehicleControlHomePage` 注入 BLE + 云发送器

---

## 5. 与 cloud-only 基线的关键差异

| 点 | master / 文档 | 本实验分支 |
| --- | --- | --- |
| 本地 BLE 栈 | 已移除 | 已恢复（协议+连接+扫描） |
| 控车通道 | 仅官方云端 | automatic：BLE 优先，云回退 |
| QGJ 本地凭据 | 已出清 | 仍不持久化；连接时 password/userId=0 |
| 产品文档边界 | 明确不恢复 BLE | **暂不改文档**，仅本文件记录实验 |

---

## 6. 验证情况（截至 2026-07-17）

已跑通（代表项）：
- `ble_hex_test` / `ble_parser_test`
- `connection_manager_state_test` / `connection_manager_reconnect_test`
- `auto_connect_service_test`（逻辑/门禁）
- `ControlChannelResolver` / `ControlCommandExecutor` hybrid 用例
- `add_vehicle_page_test`（扫描入口）
- `service_locator_test`

**尚未做**：真机扫描、GATT 握手、实车控车回归。

---

## 7. 下一步优先级（建议）

### P0 — 真机闭环
1. **B4** 真机冒烟：扫描 → 连接 → ready → 发指令 → 断连/重连  
2. **B5** 启动/回前台触发 `tryAutoConnect`  
3. **B6** 若车为 QGJ：决定凭据来源并实现（云字段 / 安全存储 / 临时输入）

### P1 — 体验与边界
4. **B7** 爱车页显示通道：`BLE已连接 / 官方云端 / 不可用`  
5. **B8** 通道偏好开关与持久化  
6. **B9** 权限拒绝、蓝牙关闭、握手超时统一文案

### P2 — 增强
7. **B10** Proximity  
8. **B11** 设备信息 / OTA / QGJ 高级设置  
9. **B12** 方案稳定后更新产品边界文档并评估合入 master

### 决策依赖（阻塞 B6/部分 B4）
- 目标车型协议：Standard AES / QGJ / 两者  
- 是否有可联调真机  

---

## 8. 风险与已知缺口

1. **QGJ 登录默认 0**：可能连上 GATT 但握手/登录失败。  
2. **自动连接未主动触发**：用户需手动扫描连接后，后续才可能依赖已存默认车。  
3. **通道偏好未持久化**：始终 automatic。  
4. **文档/产品边界冲突**：合入 master 前必须显式改边界文档与 CI 叙述。  
5. **历史页面未恢复**：诊断、OTA、高级设置仍缺失。  
6. **安全**：AES 车型密钥仍在客户端（历史设计）；后续若上生产需单独评估暴露面。

---

## 9. 关键路径速查

```text
lib/ble/*
lib/services/auto_connect_service.dart
lib/services/manual_mode_service.dart
lib/services/ble_connection_snapshot_guard.dart
lib/services/control_channel_resolver.dart
lib/services/control_command_executor.dart
lib/services/control_command_result.dart
lib/services/service_locator.dart
lib/pages/scan_page.dart
lib/pages/add_vehicle_page.dart
lib/pages/vehicle_control_home_page.dart
lib/main.dart
android/app/src/main/AndroidManifest.xml
ios/Runner/Info.plist
```

---

## 10. 相关文档

- [QGJ/BLE 残留清单](qgj_ble_residual_inventory.md)（cloud-only 审计基线）  
- [Cloud-only 对齐进度](cloud_only_alignment_progress.md)（产品主线）  
- 历史移除提交：`58b320e`  
- 本实验分支：`feature/ble-adaptation`
