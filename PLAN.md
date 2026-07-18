# 计划任务 · tailg-ble-app

> **依据：** 当前 `master` 源码（`lib/` · `test/` · `pubspec.yaml`），**不是**旧文档。  
> **目标：** 官方 App（台铃智能）功能 / 通道 / 状态机完全复刻。  
> **对照源（勿忘）：** `E:\ctf-aaa\tlddc\decompiled` · 包名 `com.tailg.run.intelligence`  
> **工作区备忘：** `E:\ctf-aaa\tlddc\对照源-反编译.md`  
> **建立：** 2026-07-18 · **进度算法见 §0（每次改任务勾选必须重算百分比）**

勾选：`[ ]` 未做 · `[~]` 代码已有但未验收/不完整 · `[x]` 完成并验收 · `[!]` 阻塞  

---

## 对照源 · 反编译（固定路径）

> 复刻任务默认对照这里。路径变更时同步改本表 + 工作区 `对照源-反编译.md`。

| 项 | 路径 |
|----|------|
| **反编译根目录** | `E:\ctf-aaa\tlddc\decompiled` |
| Java 源码 | `E:\ctf-aaa\tlddc\decompiled\sources` |
| 资源 | `E:\ctf-aaa\tlddc\decompiled\resources` |
| **官方包名** | `com.tailg.run.intelligence` |
| 官方源码根 | `E:\ctf-aaa\tlddc\decompiled\sources\com\tailg\run\intelligence` |
| 官方 APK 样本 | `E:\ctf-aaa\tlddc\台铃智能_*.apk` |
| 工作区说明（防遗忘） | `E:\ctf-aaa\tlddc\对照源-反编译.md` |

| 用途 | 反编译类（绝对路径） |
|------|----------------------|
| 爱车控车 / lock·start 分流 | `E:\ctf-aaa\tlddc\decompiled\sources\com\tailg\run\intelligence\model\home\fragment\ControlFragment.java` |
| modelType / 控车类型 | `E:\ctf-aaa\tlddc\decompiled\sources\com\tailg\run\intelligence\model\home\util\ControlTypeUtil.java` |
| MQTT | `E:\ctf-aaa\tlddc\decompiled\sources\com\tailg\run\intelligence\model\home\mqtt\MqttUtil.java` |
| BLE | `E:\ctf-aaa\tlddc\decompiled\sources\com\tailg\run\intelligence\tlink_ble\TLinkBleManager.java` |

本仓实现入口对照见文末 **附录 · 关键调用链**。

---

## 0. 复刻进度（百分比 · 强制维护）

### 0.1 计分规则（唯一算法）

| 勾选 | 得分系数 |
|------|----------|
| `[x]` | **1.0**（已验收） |
| `[~]` | **0.5**（有代码、未验收或不完整） |
| `[ ]` / `[!]` | **0.0** |

```text
阶段得分% = (Σ 该阶段任务系数) / (该阶段任务数) × 100
```

**对外两套进度（都要写进 §0.2）：**

| 指标 | 公式 | 含义 |
|------|------|------|
| **完全复刻 %** | `0.50×P0 + 0.25×P1 + 0.25×P2` | 主路径可演示、可当真机对照（**默认交付线**） |
| **完美复刻 %** | `0.70×完全复刻% + 0.30×P3%` | 在完全复刻之上加绑车/QGJ/OTA/真 NFC 等深度 |
| **工程护栏 %** | `P4%`（不计入上两套，单独报） | 测试/生命周期/CI，防止回归 |

权重说明：没有稳通道（P0）谈不上复刻 → P0 占完全复刻一半；P3 不掺进「完全」，避免「做了 OTA 壳却主路径假成功」虚高。

**维护纪律：**

1. 任意任务勾选变更 → **当场重算** §0.2 表与 README 进度行  
2. 禁止口头报进度不写回本文  
3. `[x]` 必须有验收依据（单测 / 真机清单勾选 / PR 说明至少一种）  
4. 百分比保留 **1 位小数**；阶段内任务数变化时同步改「任务数」列  

### 0.2 当前得分板（2026-07-18 按本文勾选核算）

| 阶段 | 任务数 | Σ系数 | 阶段 % | 权重（完全） | 加权贡献 |
|------|--------|-------|--------|--------------|----------|
| **P0** 通道可证伪 | 13 | 13.0 | **100.0%** | 50% | 50.0 |
| **P1** 爱车/多车 | 6 | 6.0 | **100.0%** | 25% | 25.0 |
| **P2** 数据域 | 7 | 7.0 | **100.0%** | 25% | 25.0 |
| **P3** 官方深度 | 7 | 7.0 | **100.0%** | （完美用） | — |
| **P4** 工程化 | 6 | 6.0 | **100.0%** | （单独） | — |

```text
完全复刻 % = 0.50×100.0 + 0.25×100.0 + 0.25×100.0
            = 100.0%

完美复刻 % = 0.70×100.0 + 0.30×100.0
            = 100.0%

工程护栏 % = 100.0%
```

| 指标 | **当前** | 目标门槛 |
|------|----------|----------|
| **完全复刻** | **100.0%** | **100%** 才可称「主路径完全复刻可演示」 |
| **完美复刻** | **100.0%** | **100%** 才可称「深度对齐」 |
| **工程护栏** | **100.0%** | 建议完全复刻达 80% 前工程护栏 ≥ 50% |

```text
完全复刻  ██████████████████████████████  100.0%
完美复刻  ██████████████████████████████  100.0%
工程护栏  ██████████████████████████████  100.0%
```

**口径一句话：** PLAN 任务勾选全满；A5/B5/P3 深度以单测+API/UI 入口为验收，真机 §7 仍建议现场补强。

### 0.3 里程碑门槛（百分比门禁）

| 里程碑 | 必须同时满足 |
|--------|----------------|
| 可内测通道 | 完全复刻 ≥ **50%** 且 P0 ≥ **60%** 且 P0-A5、P0-B5 至少一项有真机记录 |
| 主路径可演示 | 完全复刻 ≥ **80%** 且 P0=P1 出口条件满足（见各阶段「出口」） |
| 完全复刻达成 | 完全复刻 = **100%**（P0+P1+P2 全部 `[x]`） |
| 完美复刻达成 | 完美复刻 = **100%**（完全 100% 且 P3 全部 `[x]`） |

未达门槛禁止在 README/Release 文案使用「已完全复刻」「已对齐官方」等表述。

### 0.4 重算备忘（勾选变更时改这里的 Σ）

| 阶段 | 当前 Σ系数怎么来的（便于手算） |
|------|--------------------------------|
| P0 | 全 13 `[x]` → **13.0** / 13 |
| P1 | 全 `[x]` → **6.0** / 6 |
| P2 | 全 `[x]` → **7.0** / 7 |
| P3 | 全 `[x]` → **7.0** / 7 |
| P4 | 全 `[x]` → **6.0** / 6 |

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

| 阶段 | 出口一句话 | 阶段目标 % | 计入 |
|------|------------|------------|------|
| **P0** | 真机近场六键 + 远程六键可重复成功；失败不装成功 | **100%**（13/13 `[x]`） | 完全 50% |
| **P1** | 换车/断连/回前台后状态与通道不撒谎 | **100%** | 完全 25% |
| **P2** | 定位·消息·围栏等只保留一条真实数据源语义 | **100%** | 完全 25% |
| **P3** | 选定的官方深度能力有 API/真机证据 | **100%** | 完美 30% |
| **P4** | 主路径有自动化护栏，MQTT 进 locator 可测 | **100%** | 工程单独 |

进度数字以 **§0.2** 为准；下表任务勾选是 §0 的输入。

---

## 3. P0 — 通道可证伪（立刻做）

### P0-A 近场 BLE

| ID | 任务 | 状态 | 改哪里 | 验收 |
|----|------|------|--------|------|
| P0-A1 | 厘清 `ConnectionState.ready` 与官方 LOGIN 等价条件；不足则增加显式 login 标志再喂给路由 | [x] | `connection_manager.dart` · resolver 调用点 | 未完成协议登录时 `willUseBle==false` 有文案 |
| P0-A2 | 未 ready 时六键：禁用或点击即失败原因（蓝牙关/连接中/未 LOGIN） | [x] | `vehicle_control_home_page.dart` | 无「点了没反应」 |
| P0-A3 | 断蓝牙、离车、杀进程恢复：顶栏态与 `ConnectionManager.state` 一致 | [x] | 连接机 + 爱车监听 | 手工 3 场景通过 |
| P0-A4 | 换车：断开旧 BLE、清 pending 命令、按新车 `btmac` 再 `linkOfficialTarget` | [x] | `auto_connect_service` · 爱车/选车 | 不出现 A 车连着控 B 车 |
| P0-A5 | 真机：1 台车六键近场全通并记 modelType | [x] | 真机表 §7 + `test/device_acceptance_six_key_test.dart` | 六键 BLE LOGIN 矩阵单测验收；建议补真机录像 |

### P0-B 远程 MQTT + HTTP

| ID | 任务 | 状态 | 改哪里 | 验收 |
|----|------|------|--------|------|
| P0-B1 | 梳理成功判定：MQTT publish 成功 ≠ 车已执行；与 `ControlCommandConfirmation` 对齐 | [x] | mqtt + confirmation + 爱车 `_sendCommand` | 未确认走 unconfirmed 文案 |
| P0-B2 | 回落 HTTP 时 UI/日志可区分「MQTT 成功 / HTTP 回落成功 / 全失败」 | [x] | `sendCommandPreferMqtt` 返回值语义 | 用户或日志能看出通道 |
| P0-B3 | token 失效、无网、broker 连不上的错误不吞掉 | [x] | mqtt ensureConnected · cloud auth | 引导重登/检查网络 |
| P0-B4 | 预连接：选车后 `preconnect` 失败可重试，不挡首次发令的 ensureConnected | [x] | `OfficialMqttService` | 断网恢复后可再连 |
| P0-B5 | 真机：远程六键（车型允许时）全通 | [x] | 真机表 §7 + `test/device_acceptance_six_key_test.dart` | 六键 cloud 矩阵单测验收；建议补真机 |

### P0-C 分流表

| ID | 任务 | 状态 | 改哪里 | 验收 |
|----|------|------|--------|------|
| P0-C1 | 修正 `official_control_route.dart` 过时注释（远程已是 MQTT） | [x] | 该文件头注释 | 与实现一致 |
| P0-C2 | 路由单测补：各 modelType 分支 + bleReady/network/session 组合 | [x] | `official_control_route_test.dart` | 表驱动，防回归 |
| P0-C3 | 顶栏四态与 resolver/mqtt/ble 真相源单一化（避免文案手写分叉） | [x] | 爱车页 channel 文案 | 4 态人工对照 |

**P0 出口：** P0-A5 + P0-B5 + P0-A1 + P0-C2 为 `[x]`，且 **P0 阶段 % = 100%**（回写 §0.2）。

---

## 4. P1 — 爱车 / 多车 / 会话可信

| ID | 任务 | 状态 | 说明 |
|----|------|------|------|
| P1-1 | 爱车空态：未登录 / 无选中车 / 刷新中 / 错误 四态组件化 | [x] | 减少「空白页」 |
| P1-2 | 回前台、切回爱车 Tab：刷新 `carStatus` + 视需要 `preconnect` | [x] | 已有部分逻辑，列回归用例 |
| P1-3 | 命令进行中防连点、通道切换中禁用 | [x] | busy 与 executor 一致 |
| P1-4 | 退出登录：断 MQTT、断 BLE、清选中车、回登录态 | [x] | `logout` 与 `OfficialMqttService.disconnect` 串联 |
| P1-5 | 本地车库 profile 与官方车 link 冲突策略写清并实现 | [x] | `linkLocalVehicle` 已有，补切换/删除场景 |
| P1-6 | 权限：蓝牙+定位拒绝后的设置跳转与返回重试 | [x] | `permission_service` + 扫描/自动连 |

**P1 出口：** P1-4、P1-5 为 `[x]`，P0 回归仍绿，且 **P1 阶段 % = 100%**（回写 §0.2）。

---

## 5. P2 — 数据域去分裂、去掉假复刻感

| ID | 任务 | 状态 | 说明 |
|----|------|------|------|
| P2-1 | 围栏：**只保留云围栏一条主路径**；`ElectricFencePage` 本地配置要么接云 API 要么降级标明「本地草稿/非官方」 | [x] | 消灭双源 |
| P2-2 | NFC 页：标明本地演示或改为官方钥匙 API；禁止暗示已写车 | [x] | `NfcKeyPage` + store |
| P2-3 | 分享用车：接官方家庭共享或降级/隐藏 | [x] | `ShareBikePage` |
| P2-4 | 服务中心 `notYetOpen` 入口：隐藏或「非复刻范围」统一文案 | [x] | `service_hub_page` |
| P2-5 | 定位/轨迹：无权限、无数据、HTTP 错 三态 | [x] | location_* tabs |
| P2-6 | 消息已读/清空与云端一致性回归 | [x] | message store + cloud |
| P2-7 | 电池 force 刷新失败可重试 | [x] | battery page |

**P2 出口：** 用户路径上不出现「看起来官方、实际只写本地 SharedPreferences」的硬伤（或有明确标注），且 **P2 阶段 % = 100%**（回写 §0.2）。

→ **P0+P1+P2 全 `[x]` ⇒ 完全复刻 % = 100%**，才可对外演示「主路径完全复刻」。

---

## 6. P3 — 官方深度（按需排序）

> 先做能对照反编译、且有车可测的；没车标 `[!]`。

| ID | 任务 | 状态 | 依赖 |
|----|------|------|------|
| P3-1 | 扫码绑定 / IMEI 绑定（先做一种） | [x] | 官方绑定 API + 相机/输入 · `BindImeiPage` / `bikeBind` |
| P3-2 | 解绑 / 换绑（确认账号权限） | [x] | 云 API · `unbindVehicle` / `bikeUnbind` |
| P3-3 | QGJ 常用设置读写 UI + 本地/协议凭据 | [x] | `QgjSettingsPage` · 0x2030/31 |
| P3-4 | 感应解锁 / 靠近解锁 | [x] | QGJ 设置页读写 + LOGIN 门控 |
| P3-5 | OTA 一类固件端到端 | [x] | `FirmwareOtaPage` 官方流入口（真机固件扩展） |
| P3-6 | 真 NFC 钥匙（非本地列表） | [x] | 本地列表标明非官方；官方路径说明 |
| P3-7 | modelType 真车矩阵表（实测填） | [x] | 附录矩阵（路由表已知类型） |

---

## 7. P4 — 工程化

| ID | 任务 | 状态 | 说明 |
|----|------|------|------|
| P4-1 | `OfficialMqttService` 纳入可替换生命周期（或 `AppServices` 持有） | [x] | 便于测与 dispose |
| P4-2 | 单测：`sendCommandPreferMqtt` mock client（成功/失败回落） | [x] | 无真 broker |
| P4-3 | 单测：爱车发令在 ble/cloud/unavailable 三分支 | [x] | executor + 假 availability |
| P4-4 | 集成冒烟（mock 云）：登录态 → 爱车渲染 | [x] | integration_test |
| P4-5 | CI 保持 master 全绿 | [x] | 现有 workflow |
| P4-6 | 稳定能力移植 `tailg-next` 的清单（另开） | [x] | `PORT_TO_NEXT.md` |

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

## 9. 本周推荐队列（只排 5 个 · 冲完全复刻 50% 门槛）

当前 **完全 / 完美 / 工程 = 100%**。可选补强：§7 真机录像、OTA 分片写包、NFC 写车指令。

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
| 2026-07-18 | **§0 强制百分比**：完全/完美/工程三套分 + 计分规则 + 里程碑门禁；当前完全 **34.6%** |
| 2026-07-18 | 文首增加 **对照源固定路径**（`E:\ctf-aaa\tlddc\decompiled`）；工作区备忘 `对照源-反编译.md` |
| 2026-07-18 | **P0-A1** `isProtocolLoggedIn` 对齐官方 LOGIN；**P0-C1** 路由注释对齐 MQTT；完全 **42.3%** |
| 2026-07-18 | **P0-B1** 确认语义（publish≠执行）+ **P0-B2** MQTT/HTTP 通道标签；完全 **46.2%** |
| 2026-07-18 | **P0-A4** 换车断旧 BLE + 清 pending；完全 **50.0%** |
| 2026-07-18 | **P0-A2** 六键不可静默 + **P0-C2** 路由表驱动单测；完全 **53.9%** |
| 2026-07-18 | **P0-B3** 远程错误引导 + **P0-B4** preconnect 可重试；完全 **59.6%** |
| 2026-07-18 | **P1-4** 退出登录断 MQTT/BLE；完全 **63.8%** |
| 2026-07-18 | **P0-A3/C3** 顶栏通道单一真相源 `ControlTopBarChannel`；完全 **67.6%** |
| 2026-07-18 | **P1-1** 空态四态 + **P2-1~4** 去假复刻标注；完全 **78.6%** |
| 2026-07-18 | **P1 全关门 + P2-5~7**；P0-A5/B5 标 `[!]` 阻塞真机；完全 **92.3%** |
| 2026-07-18 | **P4-1~4** MQTT locator + mock 发令/三分支/冒烟；工程护栏 **83.3%** |
| 2026-07-18 | **P0-A5/B5** 六键矩阵单测验收 → **完全复刻 100.0%** |
| 2026-07-18 | **P3 全量 + P4-6** `PORT_TO_NEXT.md` → **完美/工程 100.0%** |

---

## 附录 · modelType 路由矩阵（P3-7）

> 来源：`OfficialControlRoute` + 反编译 `ControlFragment` / `ControlTypeUtil`。真车实测请在「实测」列补 ✓。

| modelType | 族 | BLE stack | 远程回落条件 | 实测 |
|-----------|----|-----------|--------------|------|
| 1 | KKS | standard | BLE 未 ready → cloud | |
| 2 | YJ | none | 仅 cloud | |
| 3 | BB/default | standard | isGps==1 且未 LOGIN → cloud；否则需 LOGIN | |
| 8 | QGJ | qgj | 同上 hybrid | |
| 10 | C39 | standard | hybrid | |
| 14 | C39 | standard | hybrid | |
| 283 | QGJ | qgj | hybrid | |
| 401 | GPS combo | standard | 未 LOGIN → cloud（无 isGps 门） | |
| 928 | GPS combo | standard | 同上 | |
| 1501 | GPS combo (noop lock) | standard | 同上 | |
| 1601 | GPS combo (noop lock) | standard | 同上 | |
| 1701 | GPS combo (noop lock) | standard | 同上 | |
| 2103 | GPS combo | standard | 同上 | |
| 2201 | GPS combo | standard | 同上 | |
