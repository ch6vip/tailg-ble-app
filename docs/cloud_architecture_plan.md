# 云端功能方案

目标：在不破坏本地 BLE 控车能力的前提下，逐步补齐账号、云同步、多车、多成员、诊断历史和可选官方云桥接。项目核心仍以本地 BLE 控车为主，云端作为同步、管理和服务层。

## 总体原则

- **本地 BLE 优先**：断网时仍应可以扫描、连接和控车。
- **自建云端优先**：账号、车库、日志、诊断、电池历史和共享能力由自建后端负责。
- **官方云桥接可选**：官方账号登录和官方云端控车只作为实验模式，不作为 App 核心依赖。
- **敏感数据最小化**：QGJ 登录密码、官方 token、车辆 IMEI 等敏感字段必须明确存储边界，默认不上传明文。
- **危险动作可审计**：设防、解防、上电、断电、开坐垫等动作必须记录操作者、车辆、时间、通道和结果。

## 推荐架构

```text
Flutter App
  ├─ BLE Local Layer
  │   ├─ 扫描/连接/重连
  │   ├─ QGJ/fee5 控车
  │   ├─ 本地车库
  │   └─ 本地诊断/BMS/日志
  │
  ├─ Cloud Sync Layer
  │   ├─ 自建账号
  │   ├─ 车辆档案同步
  │   ├─ 诊断报告上传
  │   ├─ 电池快照上传
  │   └─ 操作审计
  │
  └─ Official Bridge Layer (optional)
      ├─ 官方短信登录
      ├─ 官方车辆列表
      ├─ 官方车辆状态
      └─ 官方云端控车

Self-hosted Backend
  ├─ Auth API
  ├─ Vehicle API
  ├─ Telemetry API
  ├─ Audit API
  ├─ Sharing API
  └─ Notification API
```

## 与 `tailg-ble-web` 的关系

`E:\aaatest\tailg-ble-web` 已实现官方云接口桥接，可作为 Flutter App 官方账号模式的参考，但不应直接当作正式后端。

可参考内容：
- `src/cloud/api.ts`：官方 `getCode`、`login`、`carStatus`、`device/cmd/*` 调用方式。
- `src/cloud/types.ts`：官方车辆字段、`modelType` 和 `imeiGps` 命令 IMEI 选择逻辑。
- `worker/index.ts`：Cloudflare Worker 白名单代理思路。

不建议直接复用为正式云端的原因：
- 没有自建用户数据库。
- 没有车辆绑定关系、成员共享和权限模型。
- token 存储简单，不适合正式移动端长期使用。
- 依赖官方接口，接口变更、token 失效或风控会导致不可用。

## 第一阶段：账号与云同步 MVP

目标：实现用户自己的云端数据同步，不碰官方云控车。

任务：
- 新增自建账号登录。
- 同步本地车辆档案：
  - 车辆名称
  - BLE 名称
  - remoteId/MAC
  - 协议类型
  - 默认车辆标记
  - 创建/更新时间
- 上传诊断报告。
- 上传 BMS/电池快照。
- 上传操作日志：
  - 命令名称
  - BLE/云端通道
  - 成功/失败
  - 错误码或错误文案
  - App 版本和 Git commit
- 支持换手机登录后恢复车辆档案。

验收：
- 断网时本地车库和 BLE 控车不受影响。
- 登录后可以把本地车辆同步到云端。
- 新设备登录后能拉回车辆档案。
- 诊断报告和 BMS 快照能在后端查询。

## 第二阶段：多车与家庭共享

目标：补齐官方 App 中高频的多车和家庭成员管理能力。

任务：
- 一个账号支持多辆车。
- 一辆车支持多个成员。
- 权限分级：
  - 车主：管理车辆、删除车辆、邀请成员、移除成员。
  - 家庭成员：控车、查看状态、查看诊断。
  - 只读成员：查看车辆、位置和诊断，不允许控车。
- 所有危险动作进入审计记录。
- 分享邀请使用链接、二维码或邀请码，不依赖官方授权。

验收：
- 成员权限变更后立即影响 App 可用操作。
- 操作记录能准确显示操作者、车辆、动作、时间和结果。
- 只读成员无法执行控车命令。

## 第三阶段：云端状态、历史和告警

目标：把本地诊断、位置、电池和 BLE 稳定性数据沉淀成可查询历史。

任务：
- 电池历史曲线：
  - SOC
  - 电压
  - 温度
  - 故障状态
- 最近位置云同步。
- 故障诊断历史。
- BLE 连接质量统计：
  - 断连次数
  - Android 133
  - 写入超时
  - 重连成功率
- 基础告警：
  - 低电量
  - 连续控车失败
  - 长时间未连接
  - 故障诊断异常

验收：
- 能按车辆查看历史电池、位置、诊断和控车记录。
- 告警只基于真实本地数据，不伪造官方云状态。

## 第四阶段：官方账号模式

目标：可选接入用户自己的官方账号能力，作为实验通道。

参考能力：
- 获取短信验证码。
- 官方账号登录。
- 拉取官方绑定车辆。
- 显示官方云端车辆状态。
- 发送官方云端命令：
  - 设防
  - 解防
  - 上电
  - 断电
  - 寻车
  - 开坐垫

边界：
- 必须由用户输入自己的官方账号验证码完成登录。
- 不绕过官方登录。
- 不绕过官方车辆绑定关系。
- 不把官方 token 公开给其他用户。
- UI 中明确标记为“官方账号模式 / 实验功能”。

验收：
- 官方账号模式关闭时，App 的自建云端和 BLE 控车不受影响。
- 官方接口失败时，只影响官方云控车，不影响本地 BLE。
- token 失效时能清理登录态并提示重新登录。

## 第五阶段：服务生态

目标：只做可独立实现或低耦合的服务能力，暂不复刻支付和官方重服务闭环。

可做：
- 保养记录。
- 售后反馈记录。
- 服务网点收藏。
- 车辆使用统计。
- 电子围栏云同步。
- 消息中心云同步。
- OTA 版本记录和前置检测报告。

暂不建议做：
- 充电桩支付。
- 官方续费。
- 官方保险、商城和金融服务。
- 远程 OTA 写入。
- 未授权官方服务端闭环。

## 后端数据模型草案

### User

- `id`
- `phone` 或 `email`
- `displayName`
- `createdAt`
- `lastLoginAt`

### Vehicle

- `id`
- `ownerUserId`
- `name`
- `bleName`
- `remoteId`
- `protocol`
- `modelType`
- `officialImei`
- `officialImeiGps`
- `isDefault`
- `createdAt`
- `updatedAt`

### VehicleMember

- `vehicleId`
- `userId`
- `role`
- `invitedBy`
- `createdAt`

### OperationAudit

- `id`
- `vehicleId`
- `userId`
- `channel`
- `command`
- `success`
- `errorCode`
- `errorMessage`
- `appVersion`
- `gitCommit`
- `createdAt`

### BatterySnapshot

- `id`
- `vehicleId`
- `soc`
- `voltage`
- `temperature`
- `soh`
- `current`
- `cycleCount`
- `rawSource`
- `createdAt`

### DiagnosticReport

- `id`
- `vehicleId`
- `userId`
- `protocol`
- `deviceName`
- `remoteId`
- `services`
- `logs`
- `createdAt`

## App 侧代码任务

建议新增抽象：
- `CloudAuthService`
- `CloudVehicleService`
- `CloudTelemetryService`
- `CloudAuditService`
- `OfficialCloudBridge`

建议页面：
- 云账号登录页
- 云同步设置页
- 云端车辆列表页
- 车辆成员页
- 操作记录页
- 官方账号模式页

建议状态：
- `offline`
- `localOnly`
- `cloudSignedIn`
- `syncing`
- `syncFailed`
- `officialBridgeSignedIn`

## 安全与合规边界

- 不上传 QGJ ECU 登录密码明文，除非后续有明确加密方案和用户确认。
- 官方 token 只能存储在本机安全存储或受控后端，不写入公开日志。
- 诊断报告导出前应允许用户确认是否包含设备 ID、位置和日志。
- 官方云接口只允许用户自己的账号使用，不做公共代理服务。
- 危险控车命令必须保留本地防误触和云端审计。

## 建议执行顺序

1. 写 `Cloud*Service` 接口和本地 mock 实现。
2. 建自建后端最小 API：账号、车辆、诊断、电池、操作记录。
3. App 接入登录和车辆档案同步。
4. 接入诊断报告/BMS 快照上传。
5. 加多成员和权限控制。
6. 最后接入官方账号模式。
