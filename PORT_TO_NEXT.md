# tailg-next 稳定能力移植清单

> 源：`tailg-ble-app`（测试 / 官方逻辑复刻线）
> 目标：`tailg-next`（生产线，`com.ch6vip.tailg.next`）
> 核验日期：2026-07-27 · 源基线：`2671ea7`

本文只列出适合移植到生产线的能力和证据边界。`tailg-ble-app`
中的代码不会自动进入 `tailg-next`，每一批移植都需要在目标仓库独立评审。

## 移植原则

1. 优先移植纯逻辑、协议和状态机，不复制页面实现。
2. 保持 `tailg-next` 的 applicationId、品牌、账号配置和设计系统不变。
3. 有 S + T 证据的逻辑可以进入候选；缺 A/D 的能力必须继续标记待实测。
4. 不复制 token、手机号、IMEI、MAC、车辆凭据、抓包或本仓环境配置。
5. 每批移植记录源提交、目标提交、测试结果和真实设备验收状态。

证据口径与 [PLAN.md](PLAN.md) 一致：S 为官方源码，T 为自动化测试，A 为真实
官方账号/API，D 为真实车辆/手机。

## 第一批：控车核心

| 能力 | 源落点 | 当前证据 | 目标侧验收 |
|------|--------|----------|------------|
| modelType / isGps / LOGIN 路由 | `OfficialControlRoute` | S + T | 表驱动覆盖所有车型分支 |
| 通道可用性与命令分流 | `ControlChannelResolver`、`ControlCommandRoute` | S + T | BLE/MQTT/不可用组合 |
| MQTT 优先、HTTP 回落 | `OfficialMqttService.sendCommandPreferMqtt` | S + T，缺 D | broker 与真车回执 |
| publish 不等于执行 | `ControlCommandConfirmation` | S + T | 锁、电门、寻车超时与错误 |
| MQTT 单命令错误 | `OfficialMqttStatusPayload` | S + T | `accErrorStatus` / `defenceErrorStatus` |
| 智能服务 code 7/9 | `OfficialSmartServiceStatus` | S + T，缺 A | 按 modelType 阻断、提示或忽略 |
| 车辆操作人同步 | `OfficialCarOperatorPolicy`、`setCarOperator` | S + T，缺 A | 自有车/共享车通电与断电 |
| 命令防连点和目标绑定 | 控车页 + executor/confirmation guard | T | 发令期间换车、换通道 |

## 第二批：连接与感应

| 能力 | 源落点 | 当前证据 | 目标侧验收 |
|------|--------|----------|------------|
| GATT connected 与协议 LOGIN 分离 | `ConnectionManager.isProtocolLoggedIn` | S + T，缺 D | 未 LOGIN 禁止控车 |
| 换车、登出清理会话 | `AutoConnectService`、logout side effects | T，缺 D | BLE/MQTT 不串车 |
| QGJ HID + proximity | `InductionModeService`、`InductionSettingsPage` | S + T，缺 D | 真车读写、配对、回滚 |
| TLink mode + distance | `InductionModeService` | S + T，缺 D | 真车开关与距离读回 |
| KKS HID + RSSI | `InductionModeService`、Android foreground service | S + T，缺 D | 后台、锁屏、停止行为 |

真车验收统一参考 [INDUCTION_ACCEPTANCE.md](INDUCTION_ACCEPTANCE.md)，不要把 mock
结果写成设备验收。

## 第三批：云端业务

| 能力 | 源落点 | 当前证据 | 目标侧验收 |
|------|--------|----------|------------|
| 登录、token 恢复与失效 | `OfficialCloudService` | T，缺稳定 A | 真实账号生命周期 |
| 车辆同步、选车与切换 | `OfficialCloudService`、vehicle store | T，缺多车 A/D | 多车一致性 |
| IMEI 绑定与解绑 | `bindVehicleByImei`、`unbindVehicle` | T，缺 A | 权限与错误码 |
| 电池、定位、轨迹、围栏、消息 | cloud models/services | T，缺多车型 A | 脱敏 contract 记录 |

## 暂缓移植

- 只有页面或本地 SharedPreferences 演示、没有官方云语义的功能。
- 未完成真车闭环的 OTA、NFC 写车和完整车型矩阵。
- 商城、支付、保险、积分、社区、广告等范围外运营能力。
- `tailg-ble-app` 的 VOID COCKPIT 页面；生产线继续使用自己的设计系统。

## 每批完成定义

- [ ] 记录唯一的源提交与目标提交。
- [ ] 目标仓库补齐对应单元/集成测试并通过 CI。
- [ ] 保留源逻辑的失败语义、脱敏和权限边界。
- [ ] 需要 A/D 的能力明确记录实测结果；未实测不得标完成。
- [ ] 在 `tailg-next` 的版本说明中记录移植批次和回滚点。
