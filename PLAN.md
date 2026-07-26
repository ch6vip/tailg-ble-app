# 实施计划 · 官方 3.5.9 证据基线

> 更新时间：2026-07-27
> 代码基线：`08b9571`
> 官方样本：`E:\ctf-aaa\tlddc\台铃智能_3.5.9.apk`
> 目标：复刻官方功能、通道选择、协议状态机与 API 语义；UI 继续使用 VOID COCKPIT，不做像素级皮肤复制。

本文只记录能由当前源码、自动化测试、真实账号或真车结果支持的结论。旧版按 checkbox 推导出的 94.7% 不再使用。

---

## 0. 进度口径

### 0.1 状态与证据

| 状态 | 分值 | 必须满足 |
|------|------|----------|
| `[x]` | 1.0 | 已实现，并有官方源码对照与自动化测试；任务要求真车/API 时还必须有实测记录 |
| `[~]` | 0.5 | 已有代码或测试，但链路不完整、未接线，或缺少真实账号/真车验收 |
| `[ ]` | 0.0 | 未实现或当前实现没有官方证据 |
| `[!]` | 0.0 | 受账号、车辆、固件或外部服务阻塞；必须写明阻塞条件 |

证据缩写：

- **S**：官方 3.5.9 反编译源码
- **T**：单元、组件或集成测试
- **A**：真实官方账号/API 请求与响应
- **D**：真实车辆/手机验收记录

只存在 mock 或源码字符串扫描时，协议/API 任务最高只能标 `[~]`。

### 0.2 当前得分

| 范围 | 任务数 | 得分 | 进度 |
|------|--------|------|------|
| C1 控车与通道 | 12 | 9.5 | **79.2%** |
| C2 BLE 与感应 | 11 | 5.0 | **45.5%** |
| C3 云端与数据 | 11 | 6.0 | **54.5%** |
| **核心复刻** | **34** | **20.5** | **60.3%** |
| D 深度车辆能力 | 8 | 3.0 | **37.5%** |
| E 工程护栏 | 8 | 7.0 | **87.5%** |

```text
核心复刻 = (9.5 + 5.0 + 6.0) / 34 = 60.3%
深度能力 = 3.0 / 8 = 37.5%
工程护栏 = 7.0 / 8 = 87.5%
```

### 0.3 对外表述门禁

| 表述 | 条件 |
|------|------|
| 代码实验可运行 | CI 全绿，核心复刻 >= 50% |
| 真车内测可用 | C1-11 或 C1-12 至少一项有 D 证据，并完成对应车型记录 |
| 核心逻辑已复刻 | C1、C2、C3 全部 `[x]` |
| 深度能力已对齐 | 核心逻辑全 `[x]`，且 D 全部 `[x]` |

未达到门禁时禁止使用“完全复刻”“已完全对齐官方”等表述。

---

## 1. 官方对照源

### 1.1 固定基线

| 项 | 实际路径 |
|----|----------|
| 反编译根 | `E:\ctf-aaa\tlddc\3.5.9` |
| Java 源码 | `E:\ctf-aaa\tlddc\3.5.9\sources` |
| Android 资源 | `E:\ctf-aaa\tlddc\3.5.9\resources` |
| 包根 | `E:\ctf-aaa\tlddc\3.5.9\sources\com\tailg\run\intelligence` |
| APK | `E:\ctf-aaa\tlddc\台铃智能_3.5.9.apk` |
| 上一版本对照 | `E:\ctf-aaa\tlddc\3.5.8` |

旧文档中的 `E:\ctf-aaa\tlddc\decompiled` 当前不存在，不再作为有效路径。

### 1.2 控车关键类

| 领域 | 官方文件 |
|------|----------|
| 六键、车型分支、远近场选择 | `model\home\fragment\ControlFragment.java` |
| modelType 家族 | `model\home\util\ControlTypeUtil.java` |
| MQTT 客户端 | `model\home\mqtt\MqttUtil.java` |
| MQTT topic/命令 | `model\home\mqtt\TailgMqttUtil.java` |
| TLink BLE | `tlink_ble\TLinkBleManager.java` |

修改控车路由、MQTT、BLE、感应或命令反馈前，必须先打开 3.5.9 对应方法。升级官方样本时先做版本差异表，不能直接覆盖当前结论。

---

## 2. 当前审计结论

### 2.1 已由源码和测试支持

| 结论 | 证据 |
|------|------|
| modelType 1 为 KKS，2 为远程 YJ，8/283 为 QGJ，3/10/14 与 401/928/2103/2201 按 LOGIN/isGps 分流 | S + T |
| 1501/1601/1701 在官方 `start/lock/find` 主控分支中为空操作，当前六键禁用正确 | S + T |
| 开坐垫只允许本地 BLE，并检查车辆能力；QGJ 还需查询座桶支持 | S + T |
| BLE raw connected 不能替代协议 LOGIN | S + T |
| MQTT publish 不代表车辆执行，锁、电门需要状态或 ACK 确认 | S + T |
| 换车、退出登录会清理旧 BLE/MQTT 会话 | T |

### 2.2 已确认缺口

| 缺口 | 当前事实 | 优先级 |
|------|----------|--------|
| 智能服务门禁缺真实 API 证据 | code 9/7 已按车型实现阻断、提示或忽略；尚未用真实账号核对响应 | P0 |
| 共享车操作人缺真实 API 证据 | `setCarOperator` 路径与车型策略已接；尚未用真实共享车辆核对 | P0 |
| 三套 BLE 没有真车握手证据 | 只有实现、mock 和状态机测试 | P0 |
| 感应解锁没有真车结果 | `INDUCTION_ACCEPTANCE.md` 尚无勾选 | P1 |
| 真实账号 API contract 不完整 | 云端页面和解析器已写，但绑定、解绑、数据域缺请求/响应证据 | P1 |
| integration_test 未进入 CI | 存在 `integration_test/app_smoke_test.dart`，workflow 未执行 | P2 |

---

## 3. C1 · 控车与通道

| ID | 任务 | 状态 | 证据/完成条件 |
|----|------|------|---------------|
| C1-1 | `lock/start/find` 的 modelType、isGps、LOGIN 路由矩阵 | [x] | S: ControlFragment；T: `official_control_route_test` |
| C1-2 | 路由只接受协议 LOGIN，不接受单纯 GATT connected | [x] | `isProtocolLoggedIn` + 状态测试 |
| C1-3 | 状态未知时不猜测锁/电门方向；刷新失败给出明确反馈 | [x] | 控车页守卫 + widget/source tests |
| C1-4 | 指令 busy、防连点、切通道期间禁用 | [x] | 控车页 + executor tests |
| C1-5 | BLE 命令等待对应 ACK，旧 ACK 不串命令 | [x] | connection manager tests |
| C1-6 | MQTT 连接、topic、payload、订阅和重连与官方一致 | [~] | S + T 已有；缺真实 broker/车辆确认 |
| C1-7 | 远程锁/解锁/通电/断电必须确认，超时不报假成功 | [x] | confirmation tests |
| C1-8 | 把 `accErrorStatus/defenceErrorStatus/bikeSetSourceValue` 接入控车策略 | [x] | S: `mqttMsgDialog`；T: payload、回执等待与页面接线测试 |
| C1-9 | 接入智能服务到期、云盒销号门禁 | [~] | S + T：code 9/7 已按 modelType 阻断/提示/忽略；缺真实 A |
| C1-10 | 接入共享车辆 `setCarOperator` 语义 | [~] | S + T：KKS/YJ 双向、其他家族共享通电；缺真实共享 A |
| C1-11 | 近场六键真车验收 | [~] | mock 矩阵已有；至少一台车六键 D 证据 |
| C1-12 | 远程六键真车验收 | [~] | mock 矩阵已有；允许远控车型的 D 证据 |

出口：C1-9、C1-10 补齐真实 API 证据，且 C1-11、C1-12 至少覆盖实际支持的车型/命令组合。

---

## 4. C2 · BLE 与感应

| ID | 任务 | 状态 | 证据/完成条件 |
|----|------|------|---------------|
| C2-1 | KKS 配对、登录、特征与连接恢复 | [~] | 代码/T 已有；缺 D |
| C2-2 | TLink Token -> 密码/UID -> LOGIN | [~] | 代码/T 已有；缺 D |
| C2-3 | QGJ identity MAC、凭据、LOGIN | [~] | 代码/T 已有；缺 D |
| C2-4 | 自动连接、断线重连、用户断开、换车清理 | [~] | 状态机 T 已有；缺 D |
| C2-5 | KKS 六键帧与 ACK | [~] | 协议 T 已有；缺 D/抓包 |
| C2-6 | TLink 85 命令帧与 ACK | [~] | 协议 T 已有；缺 D/抓包 |
| C2-7 | QGJ 命令与座桶能力查询 | [~] | 协议 T 已有；缺 D/抓包 |
| C2-8 | QGJ HID + proximity 开关、距离与配对回滚 | [~] | 状态机 T 已有；缺 D |
| C2-9 | TLink openMode/closeMode/distance 与 bond | [~] | 状态机 T 已有；缺 D |
| C2-10 | KKS 云端 HID + RSSI 分步控车 + Android 前台服务 | [~] | 逻辑 T 和 CI 构建通过；缺后台真机 D |
| C2-11 | modelType/手机/车辆实测矩阵 | [ ] | 每个可用家族记录车型、固件、手机、结果和抓包摘要 |

真车结果统一写入 `INDUCTION_ACCEPTANCE.md` 和本节矩阵，不用口头“可用”替代证据。

---

## 5. C3 · 云端与数据

| ID | 任务 | 状态 | 证据/完成条件 |
|----|------|------|---------------|
| C3-1 | 短信登录、token 恢复、失效与退出 | [~] | 解析/T 已有；缺稳定 A |
| C3-2 | 车辆同步、选车、多车切换和本地 BLE 关联 | [~] | 代码/T 已有；缺多车 A+D |
| C3-3 | 扫码/IMEI 绑定 | [~] | UI/API 已有；缺真实绑定 A |
| C3-4 | 解绑、换绑与共享车权限 | [~] | UI/API 已有；缺真实权限 A |
| C3-5 | 电池、BMS、换电入口和失败重试 | [~] | 解析/widget T 已有；缺多车型 A |
| C3-6 | 定位、停车点、轨迹、围栏 | [~] | 页面/API/T 已有；缺真实数据 A |
| C3-7 | 车辆消息、系统消息、已读和清空 | [~] | 页面/store/T 已有；缺云端一致性 A |
| C3-8 | 今日骑行、月统计和轨迹详情 | [~] | 页面/API/T 已有；缺官方数据 A |
| C3-9 | 加载、空数据、权限拒绝、HTTP 错误和重试状态 | [x] | widget/service tests |
| C3-10 | 本地 NFC/家庭共享不冒充官方云能力 | [x] | 明确标记本地演示或隐藏 |
| C3-11 | 真实账号 API contract 记录 | [ ] | 以上领域保存脱敏后的 endpoint、字段和结果证据 |

禁止将 SharedPreferences 写入成功展示成官方云端成功。

---

## 6. D · 深度车辆能力

| ID | 能力 | 状态 | 完成条件 |
|----|------|------|----------|
| D-1 | 扫码/IMEI 真实绑定闭环 | [~] | A + D |
| D-2 | 解绑、换绑、转让和权限闭环 | [~] | A + D |
| D-3 | QGJ 常用设置完整读写 | [~] | 车辆读回一致 |
| D-4 | QGJ/TLink/KKS 感应解锁 | [~] | 三类路径按验收表完成 |
| D-5 | OTA 下载、校验、分片 ACK、断点和恢复 | [~] | 一类真实固件端到端 |
| D-6 | NFC 动态钥匙、索引和车辆 ACK | [~] | 非本地列表，真实车辆确认 |
| D-7 | 官方家庭共享 | [ ] | 真实 API 与权限语义 |
| D-8 | modelType 真车能力矩阵 | [ ] | 支持/禁用/回落均有 D 证据 |

商城、支付、保险、积分、社区、广告和充电交易不计入 D。

---

## 7. E · 工程护栏

| ID | 任务 | 状态 | 证据/完成条件 |
|----|------|------|---------------|
| E-1 | CI format + analyze + unit/widget test + coverage gate | [x] | `build.yml` |
| E-2 | GitHub Actions 签名 arm64 release APK | [x] | run `30216766500` 成功 |
| E-3 | 路由、MQTT、BLE、云解析和命令状态自动化测试 | [x] | `test/` |
| E-4 | integration_test 在 CI 执行 | [~] | smoke 文件存在，workflow 未接入 |
| E-5 | token、手机号、IMEI、MAC 与日志脱敏 | [x] | redactor/masker tests |
| E-6 | 诊断导出与命令活动记录 | [x] | service/tests |
| E-7 | 真车验收模板与可追溯结果 | [~] | 模板已有，结果为空 |
| E-8 | 文档固定到真实 3.5.9 源路径并同步进度 | [x] | 本文 + README |

代理不得在本地编译 APK。需要 APK 时推送 GitHub，由 Actions 构建；本地只运行与改动风险匹配的测试、格式和静态分析。

---

## 8. 真机与真实账号记录格式

每条 A/D 证据至少记录：

| 字段 | 要求 |
|------|------|
| 日期与 commit | 可定位到唯一代码版本 |
| 官方 App 版本 | 当前基线 3.5.9 |
| modelType/车型 | 不记录完整 IMEI/MAC |
| 手机/Android | 蓝牙和后台策略会影响结果 |
| 通道 | BLE 栈、MQTT 或 HTTP |
| 操作与期望 | 单一可复现步骤 |
| 实际结果 | 成功、失败、错误码、脱敏日志摘要 |

原始 token、手机号、IMEI、MAC、车辆凭据和抓包不得提交仓库。

---

## 9. 下一执行队列

严格按以下顺序推进：

1. C1-9/C1-10：用脱敏真实账号响应核对 SIM 状态与 `setCarOperator` contract。
2. C1-11/C1-12：完成一台近场车和一台远程车六键验收。
3. C2-1~C2-11：按实际可用车辆建立 KKS/TLink/QGJ 握手和感应矩阵。

完成一项立即补测试、证据、状态和 §0/README 进度；不积攒到最后统一改数字。

---

## 10. 关键调用链

```text
CyberVehicleControlPageV2
  -> ControlCommandPolicy
  -> ControlCommandRoute
  -> ControlChannelResolver
       -> OfficialControlRoute(modelType, isGps, protocol LOGIN)
  -> OfficialCloudService.resolveSelectedRemoteControlServiceDecision
  -> ControlCommandExecutor
       -> BLE: ConnectionManager.sendCommand
       -> Remote: OfficialMqttService.sendCommandPreferMqtt
            -> MQTT publish/status
            -> HTTP command fallback
  -> ControlCommandConfirmation
  -> OfficialCloudService.syncCarOperatorAfterCommand
```

感应链路：

```text
InductionSettingsPage / control card
  -> InductionModeService
       -> QGJ: HID + proximity + bond
       -> TLink: mode + distance + bond
       -> KKS: cloud HID + RSSI loop + foreground service
```

---

## 11. 维护规则

1. 本文是唯一进度源；README 只显示 §0.2 摘要。
2. checkbox、任务总数或分值变化时，必须在同一提交中重算 §0.2 并同步 README。
3. `[x]` 必须写证据；协议/API/真车任务不能用 mock 代替 A/D。
4. 官方版本升级时新增版本差异，不静默把 3.5.9 结论套到新版本。
5. 控车、MQTT、BLE 改动必须先读对应官方类，再改实现与测试。
6. UI 可使用 VOID COCKPIT 风格，但按钮可用条件、数据语义、状态机和错误反馈必须服从官方逻辑。
7. 不修改 applicationId 冒充官方，不支持未授权车辆，不提交任何凭据。
