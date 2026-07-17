# 计划任务 · tailg-ble-app

> **依据：** 当前 `master` 源码（`lib/` · `test/` · `pubspec.yaml`），**不是**旧文档。  
> **目标：** 官方 App（台铃智能）功能 / 通道 / 状态机完全复刻。  
> **对照：** `E:\ctf-aaa\tlddc\decompiled`（`ControlFragment` / `ControlTypeUtil` / `MqttUtil` 等）  
> **建立：** 2026-07-18  

勾选：`[ ]` 未做 · `[~]` 代码已有但未验收/不完整 · `[x]` 完成并验收 · `[!]` 阻塞  

---

## 1. 代码现状快照（审计结论）

### 1.1 已经接上的主链路

| 域 | 现状（以代码为准） | 主要落点 |
|----|-------------------|----------|
| 账号 | 短信登录、token 登录、会话恢复、退出、资料/昵称 | `OfficialCloudService` |
| 车辆 | 列表刷新、选车、本地关联 link/unlink、昵称回写 | 同上 + `vehicle_store` |
| 六键命令 | `lock/unlock/powerOn/powerOff/find/openSeat` + 读状态码 | `CommandCode` |
| 通道分流 | 官方 `modelType`/`isGps`/BLE ready 决策表 | `OfficialControlRoute` |
| 通道解析 | automatic / 强制 BLE / 强制云 | `ControlChannelResolver` |
| 发令执行 | BLE sender + 云 sender；自动通道优先 BLE | `ControlCommandExecutor` |
| 远程发令 | **MQTT 优先**，失败回落 HTTP `sendCommand` | `OfficialMqttService.sendCommandPreferMqtt` |
| MQTT 会话 | 选车预连接、link 状态流、状态回包 `applyMqttVehicleStatus` | `OfficialMqttService` + `main.dart` attach |
| 近场 BLE | 连接/重连/ready、协议 standard·qgj、发令 | `lib/ble/connection_manager.dart` 等 |
| 近场自动连 | 爱车 `linkOfficialTarget`（btmac） | `AutoConnectService` + 爱车页 |
| 扫描 | 添加车辆 → 扫描附近 BLE | `scan_page.dart` |
| 车况读 | 电池、定位、围栏读写、轨迹/详情、今日里程、消息、自检 | `OfficialCloudService` 一串 `refresh*` |
| 爱车 UI | 通道态、六键、确认/失败文案、预连 MQTT | `vehicle_control_home_page.dart` |
| 依赖 | `flutter_blue_plus` · `mqtt_client` · `permission_handler` · `encrypt` | `pubspec.yaml` |

### 1.2 半成品 / 壳 / 与官方不一致处（任务来源）

| 点 | 代码事实 | 风险 |
|----|----------|------|
| 「BLE ready」 | 路由用 `connectionManager.state == ready`，是否严格等于官方 `LoginStatus.LOGIN` 需核对 | 未 LOGIN 可能误放行或误拒绝 |
| MQTT 与路由表注释 | `OfficialControlRoute` 文件头仍写「远程以 HTTP 为 stand-in / 未单独建模 MQTT」——**实现已 MQTT**，注释与测试语义需对齐 | 文档/测试误导 |
| HTTP 回落 | MQTT 失败才 `cloud.sendCommand`；成功路径只 delay 后 `refreshVehicles`，确认依赖 MQTT 状态回包 + 轮询 | 弱网下「成功」可能未确认 |
| QGJ | 有 `qgj_protocol.dart` 与路由 `qgjModelTypes`，**无设置页/凭据持久化 UI** | 车型 8/283 深度能力缺 |
| 绑车 | `add_vehicle_page` 仅「官方同步」+「BLE 扫描」；**无扫码/IMEI/门店** | 新车无法走官方绑定闭环 |
| NFC / 分享用车 | `NfcKeyPage` / `ShareBikePage` 走 **本地 `ReplicaFeatureStore`**，不是官方 NFC/家庭共享 API | 易被当成已复刻 |
| 电子围栏双入口 | `location_fence_tab`（云）与 `ElectricFencePage`（replica 本地配置）并存 | 行为分裂 |
| 售后等 | `AppSnack.notYetOpen` 类入口仍在 | 范围噪音 |
| MQTT 单测 | 有 config/payload 测；**无** `sendCommandPreferMqtt` / 连接态集成测 | 远程主路径易回归 |
| ConnectionManager | 体量大（重连、优先级队列）；真机稳定性未在本文件背书 | 必须真机关门 |
| `AppServices` | **未**挂载 `OfficialMqttService`（单例自行 attach） | 测试替换/生命周期不统一 |

### 1.3 命令与页面资产（便于派工）

**命令：** `lock` `unlock` `openSeat` `powerOn` `powerOff` `find`（另有 `readState`/`readAntiTheft` 偏协议）

**主要页面：** 爱车、登录、添加车辆、扫描、定位三 Tab、电池、消息、车库、设置/偏好、服务中心、诊断、日志、官方云账号、车辆设置、NFC/围栏/分享/骑行记录（replica）等。

**相关测试（已有）：**  
`official_control_route_test` · `official_mqtt_config/payload_test` · `auto_connect_service_test` · `connection_manager_*` · `ble_*` · `control_command_confirmation_test` 等（约 61 个 `*_test.dart`）。

---

## 2. 阶段与出口

```text
P0 通道可证伪 ──► P1 爱车/多车可信 ──► P2 数据域去分裂
        │                                    │
        └──────── 完全复刻（主路径） ──────────┘
                         │
                         ▼
              P3 官方深度（绑车/QGJ/OTA/真 NFC…）
                         │
                         ▼
              P4 工程化（测试/生命周期/移植 next）
```

| 阶段 | 出口一句话 |
|------|------------|
| **P0** | 真机近场六键 + 远程六键可重复成功；失败不装成功 |
| **P1** | 换车/断连/回前台后状态与通道不撒谎 |
| **P2** | 定位·消息·围栏等只保留一条真实数据源语义 |
| **P3** | 选定的官方深度能力有 API/真机证据 |
| **P4** | 主路径有自动化护栏，MQTT 进 locator 可测 |

---

## 3. P0 — 通道可证伪（立刻做）

### P0-A 近场 BLE

| ID | 任务 | 状态 | 改哪里 | 验收 |
|----|------|------|--------|------|
| P0-A1 | 厘清 `ConnectionState.ready` 与官方 LOGIN 等价条件；不足则增加显式 login 标志再喂给路由 | [ ] | `connection_manager.dart` · resolver 调用点 | 未完成协议登录时 `willUseBle==false` 有文案 |
| P0-A2 | 未 ready 时六键：禁用或点击即失败原因（蓝牙关/连接中/未 LOGIN） | [~] | `vehicle_control_home_page.dart` | 无「点了没反应」 |
| P0-A3 | 断蓝牙、离车、杀进程恢复：顶栏态与 `ConnectionManager.state` 一致 | [~] | 连接机 + 爱车监听 | 手工 3 场景通过 |
| P0-A4 | 换车：断开旧 BLE、清 pending 命令、按新车 `btmac` 再 `linkOfficialTarget` | [ ] | `auto_connect_service` · 爱车/选车 | 不出现 A 车连着控 B 车 |
| P0-A5 | 真机：1 台车六键近场全通并记 modelType | [ ] | 真机表 §7 | 录像或勾选 |

### P0-B 远程 MQTT + HTTP

| ID | 任务 | 状态 | 改哪里 | 验收 |
|----|------|------|--------|------|
| P0-B1 | 梳理成功判定：MQTT publish 成功 ≠ 车已执行；与 `ControlCommandConfirmation` 对齐 | [~] | mqtt + confirmation + 爱车 `_sendCommand` | 未确认走 unconfirmed 文案 |
| P0-B2 | 回落 HTTP 时 UI/日志可区分「MQTT 成功 / HTTP 回落成功 / 全失败」 | [~] | `sendCommandPreferMqtt` 返回值语义 | 用户或日志能看出通道 |
| P0-B3 | token 失效、无网、broker 连不上的错误不吞掉 | [ ] | mqtt ensureConnected · cloud auth | 引导重登/检查网络 |
| P0-B4 | 预连接：选车后 `preconnect` 失败可重试，不挡首次发令的 ensureConnected | [~] | `OfficialMqttService` | 断网恢复后可再连 |
| P0-B5 | 真机：远程六键（车型允许时）全通 | [ ] | 真机表 §7 | |

### P0-C 分流表

| ID | 任务 | 状态 | 改哪里 | 验收 |
|----|------|------|--------|------|
| P0-C1 | 修正 `official_control_route.dart` 过时注释（远程已是 MQTT） | [ ] | 该文件头注释 | 与实现一致 |
| P0-C2 | 路由单测补：各 modelType 分支 + bleReady/network/session 组合 | [~] | `official_control_route_test.dart` | 表驱动，防回归 |
| P0-C3 | 顶栏四态与 resolver/mqtt/ble 真相源单一化（避免文案手写分叉） | [~] | 爱车页 channel 文案 | 4 态人工对照 |

**P0 出口：** P0-A5 + P0-B5 + P0-A1 + P0-C2 为 `[x]`。

---

## 4. P1 — 爱车 / 多车 / 会话可信

| ID | 任务 | 状态 | 说明 |
|----|------|------|------|
| P1-1 | 爱车空态：未登录 / 无选中车 / 刷新中 / 错误 四态组件化 | [~] | 减少「空白页」 |
| P1-2 | 回前台、切回爱车 Tab：刷新 `carStatus` + 视需要 `preconnect` | [~] | 已有部分逻辑，列回归用例 |
| P1-3 | 命令进行中防连点、通道切换中禁用 | [~] | busy 与 executor 一致 |
| P1-4 | 退出登录：断 MQTT、断 BLE、清选中车、回登录态 | [ ] | `logout` 与 `OfficialMqttService.disconnect` 串联 |
| P1-5 | 本地车库 profile 与官方车 link 冲突策略写清并实现 | [~] | `linkLocalVehicle` 已有，补切换/删除场景 |
| P1-6 | 权限：蓝牙+定位拒绝后的设置跳转与返回重试 | [~] | `permission_service` + 扫描/自动连 |

**P1 出口：** P1-4、P1-5、P0 回归仍绿。

---

## 5. P2 — 数据域去分裂、去掉假复刻感

| ID | 任务 | 状态 | 说明 |
|----|------|------|------|
| P2-1 | 围栏：**只保留云围栏一条主路径**；`ElectricFencePage` 本地配置要么接云 API 要么降级标明「本地草稿/非官方」 | [ ] | 消灭双源 |
| P2-2 | NFC 页：标明本地演示或改为官方钥匙 API；禁止暗示已写车 | [~] | `NfcKeyPage` + store |
| P2-3 | 分享用车：接官方家庭共享或降级/隐藏 | [~] | `ShareBikePage` |
| P2-4 | 服务中心 `notYetOpen` 入口：隐藏或「非复刻范围」统一文案 | [~] | `service_hub_page` |
| P2-5 | 定位/轨迹：无权限、无数据、HTTP 错 三态 | [~] | location_* tabs |
| P2-6 | 消息已读/清空与云端一致性回归 | [~] | message store + cloud |
| P2-7 | 电池 force 刷新失败可重试 | [~] | battery page |

**P2 出口：** 用户路径上不出现「看起来官方、实际只写本地 SharedPreferences」的硬伤（或有明确标注）。

→ **P0+P1+P2 勾完 = 主路径「完全复刻」可对外演示**

---

## 6. P3 — 官方深度（按需排序）

> 先做能对照反编译、且有车可测的；没车标 `[!]`。

| ID | 任务 | 状态 | 依赖 |
|----|------|------|------|
| P3-1 | 扫码绑定 / IMEI 绑定（先做一种） | [ ] | 官方绑定 API + 相机/输入 |
| P3-2 | 解绑 / 换绑（确认账号权限） | [ ] | 云 API |
| P3-3 | QGJ 常用设置读写 UI + 本地/协议凭据 | [ ] | `qgj_protocol` · 反编译设置页 |
| P3-4 | 感应解锁 / 靠近解锁 | [ ] | BLE 后台 · 耗电策略 |
| P3-5 | OTA 一类固件端到端 | [ ] | 官方 OTA 流 |
| P3-6 | 真 NFC 钥匙（非本地列表） | [ ] | 机型 NFC · 官方指令 |
| P3-7 | modelType 真车矩阵表（实测填） | [ ] | 挂在本文件附录，不靠猜 |

---

## 7. P4 — 工程化

| ID | 任务 | 状态 | 说明 |
|----|------|------|------|
| P4-1 | `OfficialMqttService` 纳入可替换生命周期（或 `AppServices` 持有） | [ ] | 便于测与 dispose |
| P4-2 | 单测：`sendCommandPreferMqtt` mock client（成功/失败回落） | [ ] | 无真 broker |
| P4-3 | 单测：爱车发令在 ble/cloud/unavailable 三分支 | [ ] | executor + 假 availability |
| P4-4 | 集成冒烟（mock 云）：登录态 → 爱车渲染 | [ ] | integration_test |
| P4-5 | CI 保持 master 全绿 | [x] | 现有 workflow |
| P4-6 | 稳定能力移植 `tailg-next` 的清单（另开） | [ ] | 见工作区版本说明 |

---

## 8. 真机验收（最小集，复制到 Issue）

```
环境：手机______ 系统______ 车 modelType____ isGps____ commit______

近场
[ ] 授权蓝牙+定位
[ ] 进爱车自动连或点连 → ready
[ ] 顶栏为 BLE 直连语义
[ ] 设防 解防 通电 断电 寻车 开坐垫
[ ] 关蓝牙 → 明确失败 → 恢复可连

远程（车型允许时）
[ ] MQTT 预连或首令可连
[ ] 顶栏远程语义
[ ] 至少设防+通电成功且车况有变
[ ] 飞行模式失败提示

数据
[ ] 电池/定位/消息打开不崩
[ ] 换车后名称与通道对象正确

登出
[ ] 退出后不可发令，MQTT/BLE 断开
```

---

## 9. 本周推荐队列（只排 5 个）

1. **P0-A1** — LOGIN/ready 语义对齐（正确性根基）  
2. **P0-B1** — 命令成功/未确认与 MQTT 回包对齐  
3. **P0-A4** — 换车不断错车  
4. **P0-C2** — 路由表单测补全  
5. **P0-A5 / P0-B5** — 真机各打通一辆车  

没有真机结果前，不进入 P3。

---

## 10. 不做

- 商城 / 支付 / 保险 / 积分 / 社区运营  
- 像素级抄官方 UI  
- 修改 applicationId 伪装官方包  
- 未授权车辆  

---

## 11. 附录 · 关键调用链（读代码入口）

```text
main.dart
  └─ OfficialMqttService.attachToCloud(officialCloudService)

vehicle_control_home_page
  ├─ AutoConnectService.linkOfficialTarget(...)
  ├─ ControlChannelResolver.resolve(bleReady: state==ready, ...)
  └─ ControlCommandExecutor.send
        ├─ BLE → ConnectionManager.sendCommand
        └─ Cloud → OfficialMqttService.sendCommandPreferMqtt
              ├─ publishCommand (MQTT)
              └─ catch → OfficialCloudService.sendCommand (HTTP)

OfficialControlRoute.resolve(modelType, isGps, bleReady, ...)
  └─ 供 Resolver 决定 canUseBle / canUseCloud
```

---

## 12. 变更记录

| 日期 | 说明 |
|------|------|
| 2026-07-18 | 初版曾误以旧功能清单为源 |
| 2026-07-18 | **重写：仅依据当前源码审计** |
| 2026-07-18 | 删除根目录 `FEATURES.md`，任务/现状只维护本文件 |
