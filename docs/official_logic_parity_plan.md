# 官方 App 功能与逻辑完全复刻计划

> **状态**：计划文档（逻辑/功能导向）  
> **建立**：2026-07-18  
> **范围**：**功能 + 业务逻辑 + 数据通道 + 状态机**；**明确不含 UI/视觉 1:1 复刻**  
> **对照源**：官方反编译 `E:\ctf-aaa\tlddc\decompiled`（`com.tailg.run.intelligence`）  
> **实现分支参考**：`feature/ble-adaptation`（进行中实验）  
> **主线文档**：`master` 仍为 cloud-only；本计划描述「若要对齐官方完整能力」的目标蓝图，不自动改产品边界  

---

## 0. 文档目的

回答三件事：

1. **官方 App 有哪些功能与逻辑域**（与皮肤无关）  
2. **每个域的正确行为是什么**（通道、状态、失败语义）  
3. **若要「完全 / 完美」复刻，分哪些阶段做、如何验收**  

本计划**不要求**：

- 像素级 UI、动效、运营弹窗样式  
- 商城/支付/保险等非控车主业若明确砍掉可整域剔除（见 §2 范围分层）  

本计划**要求**：

- 与官方一致的**能力边界、通道选择、状态流转、接口语义、失败与确认行为**  

---

## 1. 成功标准（Definition of Done）

### 1.1 完全复刻（Complete）

在**不依赖官方 UI** 的前提下：

| 维度 | 标准 |
| --- | --- |
| 功能覆盖 | §3 各 P0/P1 功能域均有可用实现（可非官方皮肤） |
| 通道逻辑 | 控车分流与官方 `ControlFragment` + `ControlTypeUtil` 一致 |
| 近场 | 登录选车进爱车可自动/点连 BLE；LOGIN 后本地控车 |
| 远程 | 允许远程时 MQTT 主路径；状态回包更新 ACC/设防 |
| 数据 | 车辆列表、状态、电池、定位、轨迹、围栏、消息与官方 API 语义一致 |
| 失败语义 | 未登录 / 无车 / 蓝牙未开 / 未 LOGIN / 无网 / MQTT 未连 / 指令未确认 均有明确结果 |
| 验收 | 自动化测试覆盖纯逻辑；真机清单覆盖近场+远程主路径 |

### 1.2 完美复刻（Perfect）

在完全复刻之上额外满足：

| 维度 | 标准 |
| --- | --- |
| 车型矩阵 | 官方已知 modelType 全覆盖（含空分支/特例有文档说明） |
| QGJ 完整 | 登录凭据、感应解锁、音效/灵敏度/HID 等设置读写 |
| 绑定闭环 | 扫码/IMEI/门店/换绑/解绑/转让（若产品选择纳入） |
| OTA | 报警器/中控/仪表等固件升级主流程可跑通 |
| NFC | 官方支持的钥匙管理读写（若纳入） |
| 旁路一致 | Widget、推送唤起、多端踢下线等边缘路径 |
| 回归 | 真机多车型矩阵 + 弱网/断连/杀进程恢复 |

---

## 2. 范围分层

按「是否属于控车主业」分层，避免完美复刻被运营功能拖死。

### L0 — 必须（控车主路径）

- 登录会话、车辆同步与选车  
- 爱车状态机（已绑定 / 未绑定 / 需登录 / 加载）  
- 六键控车 + 通道分流（BLE / MQTT / 不可用）  
- 近场连接与重连  
- 远程 MQTT + 状态确认  
- 电池、定位、消息的基础读取  

### L1 — 高价值（官方重度使用）

- 轨迹 / 围栏读写  
- 骑行统计  
- 车辆昵称、消息已读/删除、通知偏好  
- 车库多车切换与本地关联  
- 权限与蓝牙/定位服务引导  

### L2 — 车型深度（完美复刻）

- QGJ / C39 / BB 等设置全集  
- 感应解锁 / 靠近解锁  
- OTA 多通道  
- NFC 钥匙  
- 音效、灵敏度、座桶/边撑等 ECU 项  

### L3 — 可剔除或后置（非控车主业）

- 商城、支付、保险、积分、直播、圈子、充电桩运营、皮肤商城等  
- 纯运营弹窗、广告位  

> **建议**：完全复刻 = **L0 + L1**；完美复刻 = **L0 + L1 + L2**；L3 默认不做，单独立项。

---

## 3. 功能域清单（逻辑规格）

每项格式：

- **目标行为**：官方逻辑应是什么  
- **关键输入**：状态/字段  
- **输出/副作用**  
- **现状**（相对当前代码库大致判断）  
- **验收要点**

### 3.1 账号与会话（L0）

| 能力 | 目标行为 | 关键输入 | 现状 | 验收 |
| --- | --- | --- | --- | --- |
| 短信登录 | 校验手机号/验证码 → 存 token/userId/phone | 手机号、验证码 | 已有 | 登录成功进入会话 |
| Token 会话 | 冷启动恢复；失效清会话 | secure storage | 已有 | 杀进程后仍登录 |
| 退出登录 | 清凭据、选车、MQTT 断开、回未登录态 | 用户操作 | 部分 | 退出后不可控车、MQTT 断 |
| 多设备/失效 | 401/鉴权失败引导重登 | API 错误 | 部分 | 不静默假成功 |

### 3.2 车辆域（L0/L1）

| 能力 | 目标行为 | 关键字段 | 现状 | 验收 |
| --- | --- | --- | --- | --- |
| 车辆列表同步 | 拉取账号下车辆并缓存 | carId/imei/btmac/modelType/isGps… | 已有 | 列表与官方账号一致 |
| 选车 | 选中后成为控车目标；触发 MQTT 预连与近场目标绑定 | selectedVehicle | 已有 | 换车后通道目标更新 |
| bindingCar | 未绑定走未绑定态，不暴露假六键 | bindingCar/perfectStatus | 部分 | 无车/未绑定 UI 逻辑正确 |
| 本地关联 | 官方车 ↔ 本地 BLE 设备 id（MAC） | localVehicleLinks / btmac | 部分 | 连错车要拦截 |
| 昵称写回 | 改昵称同步云端 | carNickName | 已有 | 刷新后仍在 |
| 绑定闭环 | 扫码/IMEI/门店/解绑/转让 | L2/产品选择 | 基本不做 | 若纳入再写专章 |

### 3.3 爱车状态机（L0）

官方：`ControlFragment` ↔ `UnControlFragment` 互斥；事件 518/519 等。

| 模式 | 条件（逻辑） | 行为 |
| --- | --- | --- |
| needLogin | 无 token | 引导登录，不发令 |
| unbound | 已登录无可用绑定车 | 引导加车/同步，不发令 |
| loading | 刷新中且尚无可用车况 | 加载态，不闪六键 |
| bound | 有选中车 | 展示车况 + 允许按通道控车 |

**现状**：Aurora 爱车页有门禁，需持续对齐边界文案与切换时机。  
**验收**：登录/选车/退出/清车 四种切换无错误六键、无错误通道。

### 3.4 控车通道决策（L0 · 核心）

官方真相源：`ControlFragment.lock/start/find…` + `ControlTypeUtil`。

#### 3.4.1 输入

- `modelType`  
- `isGps`（0/1/null）  
- `bleReady`（协议 LOGIN，不是仅 GATT 连上）  
- `networkReady`  
- `cloudSessionReady`（已登录+选车；官方另要求 MQTT connected）  
- `bindingCar`  

#### 3.4.2 决策表（必须实现）

| modelType | 决策 |
| --- | --- |
| 1 KKS | BLE LOGIN → 本地；否则 → 远程 |
| 2 YJ | **仅远程** |
| 8 / 283 QGJ | `isGps==1 && !LOGIN` → 远程；否则必须 BLE(QGJ 栈) |
| 10 / 14 C39 | 同上，BLE(standard) |
| 401 / 928 / 2103 / 2201 | `!LOGIN` → 远程；LOGIN → BLE（**无 isGps 门闩**） |
| 1501 / 1601 / 1701 | 按 GPS 组合处理（官方 lock 空分支需文档标注） |
| 3 BB / 默认 | isGps 门闩 + BLE(standard) |

#### 3.4.3 输出

- `transport ∈ {ble, cloud, unavailable}`  
- `bleStack ∈ {standard, qgj, none}`  
- 人类可读 `reason`  

**现状**：`OfficialControlRoute` 已落地。  
**验收**：单测覆盖表中每一行；真机抽测 KKS/QGJ/仅云 至少各一类。

### 3.5 近场 BLE（L0/L2）

| 能力 | 目标行为 | 现状 | 验收 |
| --- | --- | --- | --- |
| 打开爱车自动连 | 有 btmac 则设目标并扫描连接 | 已有（实验分支） | 近场车可进 ready |
| 点按连接 | 用户可手动触发再扫连 | 已有横幅 | 权限不足有提示 |
| 协议握手 | Standard token 或 QGJ login → LOGIN/ready | 部分（QGJ 凭据=0） | ready 后可发令 |
| 指令 | 设防/解防/上电/断电/寻车/开座 | ConnectionManager 有 | 六键本地成功 |
| 重连 | 异常断连自动重连（上限/退避） | ConnectionManager 有 | 走远再靠近可恢复 |
| 回前台 | onResume 再尝试近场 + MQTT | 部分 | 回前台可恢复通道 |
| QGJ 设置读写 | 感应/音效/灵敏度等 | 未做 | L2 |
| 感应解锁 | 靠近自动解/落锁 | 未做 | L2 |

**关键逻辑**：

- MAC 匹配忽略分隔符与大小写  
- 自动连可被「手动模式」抑制  
- 官方车已 link 到其它本地设备时，禁止连错车发令  

### 3.6 远程控车（L0）

#### 3.6.1 MQTT（主路径）

| 项 | 规格 |
| --- | --- |
| 连接时机 | 选车 / 进爱车 / 回前台预连 |
| KKS/YJ broker | `tcp://www.tailgdd.com:1883` |
| 其它 broker | `ssl://www.tailgdd.com:6668` 或 `mqHost:mqPort` |
| 鉴权 | `client_app` / `123456` |
| clientId | KKS/YJ：`app_{imei}{rand3}`；其它：`app_{imeiGps}_{uid}_android_{rand3}` |
| 发令 topic | KKS/YJ：`app-update-kks|yunjia/{imei}`；其它：`APP_S/CMD/{imei}` |
| payload | `{"imei","command"}`，command=lock/unlock/start/stop/search/openCushion… |
| QoS | 0 |
| 订阅 | 状态/OTA/充电器/自检等相关 topic |
| 回包 | 解析 ACC/defenceStatus，更新当前车并驱动 UI 逻辑状态 |

**现状**：实验分支已实现主路径。  
**完美要求**：回包确认与官方事件一致；MQTT 未连时的排队/重试策略与官方对齐。

#### 3.6.2 HTTP（辅/兜底）

- `POST app/device/cmd/{lock,unlock,start,stop,search,openCushion,status}`  
- body 含 `imei`（注意 commandImei 与 imeiGps 选择）  
- **完全复刻**：可作兜底  
- **完美复刻**：明确哪些官方路径走 HTTP、哪些只走 MQTT，避免双发  

#### 3.6.3 控车确认

- 发送中 / 成功 / 失败 / 超时 / 未确认  
- 需要状态确认的指令（设防/上电等）应轮询或等 MQTT 回包  
- 确认期间 dual-send 防抖  

**现状**：有确认与防抖；需与 MQTT 回包路径统一。

### 3.7 车况与刷新（L0）

| 数据 | 来源 | 逻辑 |
| --- | --- | --- |
| defenceStatus / acc / online / 电量 | 云列表 + MQTT 回包 +（近场时）BLE 状态 | 本地优先或时间戳合并策略要文档化 |
| 下拉刷新 | 强制拉车辆 + 电池 + 位置 + 今日里程 | 失败可部分成功 |
| 静默刷新 | 回页/回前台/控车后 | 节流，避免打爆 API |
| 可见刷新 | 子页返回爱车 | 已有 P0.5 思路，需保持 |

### 3.8 电池（L0/L1）

- 云电池详情、电压/温度/循环等  
- 有 BLE 时是否覆盖显示 → 需定义优先级  
- 空数据不造假  

### 3.9 定位 / 轨迹 / 围栏（L1）

| 能力 | 逻辑要点 |
| --- | --- |
| 停车位置 | 官方 `bleConnect*` 字段 + 车辆经纬度；近零坐标剔除 |
| 轨迹列表/详情 | 按月/按天；空态诚实 |
| 围栏 | 读取开关/半径/时段；写入后回读确认 |
| 地图 | 逻辑上能展示点/线/圆即可，不要求官方底图皮肤 |

### 3.10 消息（L1）

- 车辆消息 / 系统消息分页  
- 已读本地或云端策略  
- 删除（失败保留）  
- 通知偏好读写  

### 3.11 服务与扩展（L1/L2/L3）

| 域 | 层级 | 说明 |
| --- | --- | --- |
| 骑行统计 / 碳排 | L1 | 已有基础 |
| 家庭分享 | L2/产品 | 曾降范围，是否纳入需决策 |
| 充电站 | L3/运营 | 默认可剔除 |
| 智能座舱/投屏/摄像头 | L2 | 按能力位 `supports*` 门禁 |
| 商城/支付/保险/圈子 | L3 | 默认剔除 |

### 3.12 权限与系统（L0）

- 蓝牙开关检测与引导  
- 扫描/连接权限（Android 12+）  
- 定位权限（扫 BLE / 记位置）  
- 通知权限（消息）  
- 拒绝与永久拒绝的可操作错误  

### 3.13 诊断与可观测（L1）

- 操作日志（BLE/MQTT/云）脱敏  
- 诊断导出不含 token/密码  
- 通道与指令结果可追踪  

---

## 4. 领域状态机（必须统一）

### 4.1 BLE 连接

```text
disconnected → connecting → connected → ready(LOGIN)
       ↑            │            │
       └────────────┴────────────┘ 失败/断开
ready → reconnecting → ready | disconnected
```

### 4.2 MQTT

```text
disconnected → connecting → connected
connected → disconnected（登出/换车/网络丢失）
```

### 4.3 单次控车指令

```text
idle → debounced? → policy_check → channel_resolve
  → sending → (ack/status) → confirmed | failed | timeout | unconfirmed
```

### 4.4 爱车页模式

见 §3.3。任何模式切换不得出现「不可用通道仍显示成功」。

---

## 5. 数据模型最低字段（逻辑）

### OfficialVehicle（云车）

必含：`carId, imei, imeiGps, btmac, btname, modelType, isGps, mqHost, mqPort, defenceStatus, acc, online, electricQuantity, voltage, mileage, frame, carNickName, carPhoto, raw…`

### 本地 VehicleProfile

必含：`id(MAC或设备id), name, protocol, lastConnectedAt, lastLocation…`  
QGJ 凭据：完美复刻时需安全存储策略（当前实验为 0）。

### 指令

统一 `CommandCode` ↔ 云 apiName ↔ BLE 帧/opCode ↔ MQTT command 字符串。

---

## 6. 阶段实施计划

### Phase A — 主路径闭环（完全复刻的骨架）✅ 实验分支大部分完成

- [x] BLE 协议 + ConnectionManager  
- [x] 官方分流表  
- [x] MQTT 发令/预连/回包  
- [x] 爱车近场自动连 + 点连  
- [x] 顶栏通道状态  
- [ ] **真机 A 验收**（阻塞）  

**A 验收清单（真机）**

1. 登录 → 有车 → 进爱车  
2. 近场自动或点连 → BLE 直连 → 寻车/设防成功  
3. 关蓝牙或远离 → 有远程能力时 MQTT 远程成功  
4. 回包或刷新后 ACC/设防 UI 正确  
5. 退出登录后不可控车、MQTT 断开  

### Phase B — L1 数据域扎实

- [ ] 轨迹/围栏/消息/电池与官方字段边角一致  
- [ ] 控车确认与 MQTT/HTTP 统一  
- [ ] 权限与错误文案体系  
- [ ] 弱网：超时、未确认、部分刷新  

### Phase C — L2 车型深度（完美复刻）

- [ ] QGJ 凭据与 LOGIN 真源  
- [ ] 感应解锁  
- [ ] 设置项读写矩阵（按 modelType 门禁）  
- [ ] OTA 主流程  
- [ ] NFC（若纳入）  

### Phase D — 收尾与合入

- [ ] 主线文档解禁 / 产品边界变更评审  
- [ ] 安全收紧（SSL 证书、密钥、日志）  
- [ ] 回归矩阵与发布门禁  
- [ ] 决定是否合入 `master` 或长期双轨  

---

## 7. 测试策略（无 UI 像素要求）

### 7.1 纯逻辑单测（必须）

- `OfficialControlRoute` 全 modelType 表  
- MQTT topic/clientId/payload  
- MQTT 回包解析与确认  
- 控车 policy / debounce / confirmation  
- 近场 MAC 匹配、自动连门禁、手动模式  

### 7.2 集成/Widget（逻辑级）

- 爱车模式切换（登录/无车/有车）  
- 通道文案随 BLE/MQTT 状态变化  
- 选车触发预连（可 mock client）  

### 7.3 真机矩阵

| 车型样本 | 近场 | 远程 | 备注 |
| --- | --- | --- | --- |
| KKS/标准 | ✓ | ✓ | modelType 1 |
| QGJ | ✓ | isGps=1 时 | 凭据 |
| 仅云/YJ | — | ✓ | modelType 2 |
| GPS 组合 | ✓ | ✓ | 401 等 |

---

## 8. 明确不做（默认）

除非产品书面变更：

1. 商城 / 支付 / 保险 / 积分 / 直播 / 圈子  
2. UI 像素级复刻、运营弹窗皮肤  
3. 以官方包名/签名冒充上架  
4. 未授权的安全绕过、破解他人车辆  

---

## 9. 与现有文档关系

| 文档 | 关系 |
| --- | --- |
| [ble_adaptation_progress.md](ble_adaptation_progress.md) | **实验分支执行日志**；本计划是总蓝图 |
| [archive/cloud_only_alignment_progress.md](archive/cloud_only_alignment_progress.md) | master 已完成的 cloud-only P0（归档） |
| [cloud_architecture_plan.md](cloud_architecture_plan.md) | master 架构边界（与本计划冲突处以产品决策为准） |
| [qgj_ble_residual_inventory.md](qgj_ble_residual_inventory.md) | 残留审计；完美复刻时多处将反转 |
| [FEATURES.md](../FEATURES.md) | 当前对外功能清单（master 视角） |

---

## 10. 决策清单（开工完美复刻前必须拍板）

1. **完全 vs 完美**：只做 L0+L1，还是包含 L2？  
2. **绑定闭环**是否纳入？  
3. **家庭分享 / NFC / OTA** 是否纳入？  
4. **L3 运营功能**是否永久剔除？  
5. **合入策略**：长期实验分支，还是未来改 master 为 hybrid？  
6. **真机资源**：可测车型列表与时间表  

---

## 11. 建议的下一步（执行）

1. 用本计划 §6 Phase A 真机清单做一次验收，标注通过/失败项  
2. 失败项映射回 §3 对应域，开任务  
3. 若目标是「完全复刻」：优先 Phase B  
4. 若目标是「完美复刻」：在 B 稳定后启动 Phase C，并先定 §10 决策  

---

## 12. 修订记录

| 日期 | 变更 |
| --- | --- |
| 2026-07-18 | 初版：功能/逻辑完全与完美复刻蓝图；不含 UI |
