# BLE / MQTT 适配实验（feature/ble-adaptation）

> **状态**：实验分支 · 软件侧主路径已通 · 待真机验收  
> **建立**：2026-07-17  
> **更新**：2026-07-18  
> **分支**：`feature/ble-adaptation`（自 `master` `a9e1b5d` 切出）  
> **远端**：`origin/feature/ble-adaptation`

---

## 0. 边界（读前必看）

| 项 | 说明 |
| --- | --- |
| 本文范围 | **仅描述本实验分支**，不代表 `master` 已改为 hybrid |
| 产品文档 | `AGENTS.md` / `cloud_only_alignment_progress.md` / `qgj_ble_residual_inventory.md` **暂未解禁**「不恢复 BLE」 |
| 历史基线 | BLE 移除提交 `58b320e`；恢复参考 `58b320e^` |
| 官方对照 | 反编译目录 `E:\ctf-aaa\tlddc\decompiled`（`ControlFragment` / `MqttUtil` / `ControlTypeUtil`） |

---

## 1. 目标与非目标

### 1.1 目标（已基本落地）

- 本地 BLE：协议层 + 连接层 + 扫描 + 爱车近场自动连  
- 远程控车：官方 **MQTT 优先**，HTTP `device/cmd` 兜底  
- 通道路由：**完全按官方** `modelType` + `isGps` + BLE LOGIN 决策表  
- 使用路径接近官方：登录 → 选车 → 打开爱车 → 近场自动/点连 BLE，远程直接 MQTT  

### 1.2 非目标（本分支仍不做）

- 合入 `master` / 改主线产品定位  
- 感应解锁（Proximity）  
- OTA / 设备信息 / QGJ 高级设置整页恢复  
- 本地 QGJ password/userId 持久化（当前固定 0）  
- 改 applicationId / 包名  

---

## 2. 怎么用（对齐官方路径）

```text
1. 登录官方账号
2. 同步并选中账号下已绑定车辆
3. 打开爱车 Tab
4. 近场：
   - 车辆有 btmac → 自动设为目标并扫描连接
   - 未连上 → 顶栏横幅点「连接蓝牙」
   - 连上后顶栏：BLE 直连 → 本地控车
5. 远程（不在身边、有远程能力）：
   - 直接点设防/启动等 → MQTT 下发
   - 顶栏：MQTT 远程 / MQTT 连接中 / 云端待命
```

扫描页（添加车辆 → 扫描附近车辆）**保留为兜底**，不再是近场控车必经入口。

### 顶栏通道文案

| 文案 | 含义 |
| --- | --- |
| `BLE 直连` | 当前会走本地 BLE |
| `MQTT 远程` | MQTT 已连接，远程主路径可用 |
| `MQTT 连接中` | 预连接进行中 |
| `云端待命` | 允许远程但 MQTT 尚未连上（发令会尝试 MQTT / HTTP 兜底） |

---

## 3. 进度看板

| ID | 项 | 状态 | 说明 |
| --- | --- | --- | --- |
| B0 | 调研旧 BLE 栈 | **完成** | `58b320e` / 反编译 |
| B1 | 协议层 + 单测 | **完成** | hex/AES/parser/protocol/QGJ |
| B2 | ConnectionManager + 权限 | **完成** | Android/iOS BLE 权限 |
| B3 | locator / 扫描 / 自动连 / 双通道 | **完成** | 接线 + UI 入口 |
| B4 | 官方 modelType/isGps 分流表 | **完成** | `OfficialControlRoute` |
| B5 | 官方 MQTT 发令 + 预连接 + 状态回包 | **完成** | `OfficialMqttService` |
| B6 | 爱车通道状态展示 | **完成** | 顶栏 BLE/MQTT 文案 |
| B7 | 爱车近场自动连（官方路径） | **完成** | `linkOfficialTarget` + 横幅点连 |
| B8 | 真机冒烟 | **未做** | 扫描/GATT/MQTT/实车指令 |
| B9 | QGJ 凭据策略 | **未做** | 依赖真车 |
| B10 | 通道偏好持久化 | **未做** | 当前固定 automatic |
| B11 | 权限/失败文案体系化 | **部分** | 有基础提示，未统一 |
| B12 | Proximity / OTA / 高级设置 | **暂缓** | |
| B13 | 主线文档解禁 + 合入 master | **暂缓** | 真机通过后再议 |

**统计**：软件主路径 **B0–B7 完成**；阻塞真机 **B8–B9**；增强/收尾 **B10–B13**。

---

## 4. 架构

```text
登录 / 选车
    │
    ▼
VehicleControlHomePage（爱车）
    ├─ 近场：official btmac → AutoConnectService.linkOfficialTarget
    │         → 扫描匹配 MAC → ConnectionManager.connect → ready
    ├─ MQTT：OfficialMqttService.attach/preconnect（选车/进页/回前台）
    │
    ▼
ControlChannelResolver.automatic
    └─ OfficialControlRoute.resolve(modelType, isGps, bleReady, …)
            │
            ├─ willUseBle  → ConnectionManager.sendCommand
            └─ cloud       → OfficialMqttService.publish
                               └─ 失败 → HTTP app/device/cmd/*
```

### 4.1 官方分流表（`OfficialControlRoute`）

| modelType | 行为 |
| --- | --- |
| 1 KKS | BLE LOGIN 优先，否则云 |
| 2 YJ | **仅云** |
| 8 / 283 QGJ | `isGps==1` 且未 LOGIN → 云，否则必须 BLE(QGJ) |
| 10 / 14 C39 | 同上，BLE(standard) |
| 401 / 928 / 2103 / 2201 / 1501 / 1601 / 1701 | 未 LOGIN → 云，否则 BLE（无 isGps 门闩） |
| 3 BB / 默认 | isGps 门闩 + BLE(standard) |

`bleReady` ≈ 官方 `LoginStatus.LOGIN`（`ConnectionState.ready`）。

### 4.2 MQTT（对齐 `MqttUtil` / `TailgMqttUtil`）

| 项 | 值 |
| --- | --- |
| KKS/YJ broker | `tcp://www.tailgdd.com:1883` |
| 其它 broker | `ssl://www.tailgdd.com:6668` 或车辆 `mqHost:mqPort` |
| 账号 | `client_app` / `123456` |
| QoS | 0 |
| KKS topic | `app-update-kks/{imei}` |
| YJ topic | `app-update-yunjia/{imei}` |
| 其它 topic | `APP_S/CMD/{imei}` |
| payload | `{"imei":"...","command":"lock"}` |
| 状态回包 | 解析 `ACC` / `defenceStatus` → `applyMqttVehicleStatus` |

### 4.3 关键代码

| 路径 | 职责 |
| --- | --- |
| `lib/ble/*` | 协议 + ConnectionManager |
| `lib/services/official_control_route.dart` | 官方分流纯函数 |
| `lib/services/control_channel_resolver.dart` | 通道可用性 / UI 文案 |
| `lib/services/control_command_executor.dart` | BLE/云执行器 |
| `lib/services/official_mqtt_*.dart` | MQTT 配置 / 客户端 / 回包 |
| `lib/services/auto_connect_service.dart` | 近场自动连 + `linkOfficialTarget` |
| `lib/pages/vehicle_control_home_page.dart` | 爱车主路径 UI |
| `lib/pages/scan_page.dart` | 手动扫描兜底 |
| `lib/models/official_vehicle.dart` | `isGps` / `mqHost` / `mqPort` / `copyWith` |

### 4.4 依赖与平台

- Dart：`flutter_blue_plus`、`encrypt`、`permission_handler`、`mqtt_client`
- Android：`BLUETOOTH*`、`BLUETOOTH_SCAN/CONNECT`、`bluetooth_le`
- iOS：`NSBluetooth*`、`bluetooth-central`

---

## 5. 与 master（cloud-only）差异

| 点 | master | 本分支 |
| --- | --- | --- |
| 本地 BLE | 已移除 | 已恢复 |
| 远程控车 | HTTP only | MQTT 优先 + HTTP 兜底 |
| 通道路由 | 仅云可用 | 官方 modelType/isGps 表 |
| 近场入口 | 无 | 爱车自动连 + 扫描兜底 |
| 产品文档边界 | 不恢复 BLE | **暂不改**主线文档 |

---

## 6. 与官方 App 使用差异（诚实对照）

| 维度 | 像官方？ | 说明 |
| --- | --- | --- |
| 点按钮走 BLE 还是云 | **是** | 同一决策表 |
| 远程 MQTT 发令 | **是** | 参数/topic 对齐 |
| 打开爱车近场自动连 | **基本是** | 有 MAC 即扫连；官方部分车型策略更细 |
| 感应解锁 / 高级设置 | **否** | 未做 |
| UI 视觉 | **否** | Aurora 自研壳 |
| QGJ 凭据 | **否** | 固定 0 |

---

## 7. 提交记录（本分支相对 master）

| Commit | 说明 |
| --- | --- |
| `8ad0ee5` | 协议层 + 单测 |
| `9cbc0f7` | ConnectionManager + 平台权限 |
| `f269f2a` | locator / 扫描 / 自动连 / hybrid 接线 |
| `0836707` | 首版进度文档 |
| `18700ae` | 初版官方分流对齐 |
| `e1b7313` | 完整 modelType/isGps 决策表 |
| `93585d9` | MQTT 发令 + HTTP 兜底 |
| `f7d76f0` | MQTT 预连 + 状态回包 |
| `367426d` | 爱车 BLE/MQTT 状态展示 |
| `c082daa` | 爱车近场自动连（官方路径） |

---

## 8. 验证

### 已覆盖（单测）

- `ble_hex_test` / `ble_parser_test`
- `connection_manager_*`
- `auto_connect_service_test`
- `official_control_route_test`
- `official_mqtt_config_test` / `official_mqtt_payload_test`
- `official_cloud_test`（分流 + executor）
- `service_locator_test` / `add_vehicle_page_test` 等

### 未覆盖（真机）

- [ ] 登录选车进爱车是否自动找到车并 BLE ready  
- [ ] 本地六键指令是否成功  
- [ ] MQTT 远程设防/启动/寻车  
- [ ] 回包是否刷新上电/设防 UI  
- [ ] 断连/回前台重连  

---

## 9. 下一步

### P0（真机）

1. 实车冒烟清单（上节 checklist）  
2. 若 QGJ 握手失败 → 定凭据方案（B9）  

### P1（体验）

3. 通道偏好持久化（自动 / 仅 BLE / 仅云）  
4. 权限拒绝、蓝牙关闭、扫不到车的统一文案  
5. 登出/切车时 MQTT 状态更稳的展示  

### P2（增强 / 收尾）

6. Proximity / OTA / 高级设置（按需）  
7. 真机通过后：更新主线文档并评估合入 master  

---

## 10. 风险

1. **QGJ 凭据为 0**：可能 GATT 通但协议 LOGIN 失败  
2. **MQTT 依赖公网 broker**：网络/证书/账号策略变化会导致远程失败（已有 HTTP 兜底）  
3. **SSL trust-all**：与官方一致，仅实验可接受，量产需收紧  
4. **AES 车型密钥在客户端**：历史设计风险  
5. **文档边界冲突**：合入 master 前必须正式解禁主线文档  

---

## 11. 相关文档

- [项目文档索引](README.md)  
- [官方功能逻辑复刻计划](official_logic_parity_plan.md)（完全/完美复刻蓝图，不含 UI）  
- [QGJ/BLE 残留清单](qgj_ble_residual_inventory.md)（master 审计基线）  
- [Cloud-only 对齐进度](cloud_only_alignment_progress.md)（产品主线）  
- 历史移除：`58b320e`  
- 本分支：`feature/ble-adaptation`
