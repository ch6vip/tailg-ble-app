# 官方云端复刻方案

方向更新：当前项目改为 **官方 App 复刻优先**。自建云端不再作为近期主线，官方账号、官方车辆列表、官方云端状态和官方云端控车已接入 Flutter App，并已通过真实官方账号和车辆完成真机验证（2026-06-05）。BLE 直连能力继续保留，作为官方云不可用时的本地兜底。

## 总体原则

- **官方流程优先**：登录、车辆列表、车辆状态和云端控车优先对齐官方 App。
- **合法账号边界**：必须由用户使用自己的官方账号和验证码登录，不绕过官方登录和车辆绑定关系。
- **BLE 本地兜底**：断网、官方 token 失效或官方接口不可用时，本地 BLE 仍可控车。
- **功能分层**：官方云能力和 BLE 本地能力分开封装，页面只通过统一控制入口选择通道。
- **危险动作防误触**：设防、断电、上电、开坐垫等危险动作保持本地防误触和结果提示。
- **不碰高风险闭环**：支付、续费、充电桩交易、远程 OTA、NFC 真加钥匙仍暂不复刻。

## 与 `tailg-ble-web` 的关系

`E:\aaatest\tailg-ble-web` 已经验证了一组官方云接口，可作为 Flutter 迁移参考。

可迁移内容：

- `src/cloud/api.ts`
  - `app/getCode`
  - `app/login`
  - `app/centralControl/carStatus`
  - `app/device/cmd/lock`
  - `app/device/cmd/unlock`
  - `app/device/cmd/start`
  - `app/device/cmd/stop`
  - `app/device/cmd/search`
  - `app/device/cmd/openCushion`
- 反编译官方 `TailgService.java`
  - `app/device/cmd/status`
  - `Forward-Service-Ip`
- `src/cloud/types.ts`
  - `CarInfo`
  - `CloudCmd`
  - `modelType -> imeiGps` 命令 IMEI 选择逻辑
- `worker/index.ts`
  - 官方域名白名单
  - 路径白名单
  - CORS 边界

迁移时不直接照搬 Web 端 token 存储方式。Flutter 侧已使用本地安全存储保存官方 token/手机号，并在日志和诊断报告中脱敏 token、手机号、IMEI 等敏感字段。

## 推荐架构

```text
Flutter App
  ├─ Official Cloud Layer
  │   ├─ 短信验证码
  │   ├─ 官方账号登录
  │   ├─ token 保存/失效处理
  │   ├─ 官方车辆列表
  │   ├─ 官方车辆状态
  │   └─ 官方云端控车
  │
  ├─ BLE Local Layer
  │   ├─ 扫描/连接/重连
  │   ├─ QGJ/fee5 控车
  │   ├─ 本地车库
  │   └─ 本地诊断/BMS/日志
  │
  └─ Unified Vehicle Layer
      ├─ 车辆选择
      ├─ 控车通道选择
      ├─ 状态聚合
      └─ 操作反馈

Optional Proxy
  ├─ 官方接口白名单
  ├─ CORS/网络限制处理
  └─ 不保存用户 token
```

## 第一阶段：官方账号登录和车辆列表

目标：在 App 内完成官方账号登录，并显示官方账号绑定车辆。

代码状态：已接入并完成真机验证（2026-06-05，真实官方账号短信验证码登录、token 处理通过）。

已完成：

- 新增 `OfficialCloudApi`：
  - 获取短信验证码。
  - 短信验证码登录。
  - token 使用 `flutter_secure_storage` 保存和清理。
  - 旧版 `shared_preferences` token/手机号一次性迁移后清理。
  - 车辆列表和云端控车统一 token 失效检测。
- 新增官方车辆模型：
  - `imei`
  - `imeiGps`
  - `carId`
  - `carName`
  - `carNickName`
  - `carPhoto`
  - `frame`
  - `defenceStatus`
  - `acc`
  - `electricQuantity`
  - `voltage`
  - `online`
  - `btname`
  - `btmac`
  - `longitude`
  - `latitude`
  - `modelType`
  - `mileage`
- 新增官方账号页面：
  - 未登录状态。
  - 手机号和验证码输入。
  - 已登录账号状态。
  - 退出登录。
- 新增官方车辆列表：
  - 官方车辆名称。
  - 在线状态。
  - 电量/电压。
  - 设防/ACC 状态。
  - 蓝牙名和蓝牙 MAC。

验收：

- `flutter analyze` 已通过。
- `flutter test` 已通过。
- 用户可以通过自己的官方账号验证码登录。
- 登录成功后能拉取官方绑定车辆。
- token 失效后自动清理登录态并提示重新登录。
- 登录失败、验证码失败、网络失败都有明确提示。

## 第二阶段：官方云端控车

目标：接入官方云端控车命令，并和现有 BLE 控车入口并存。

代码状态：已接入并完成真机验证（2026-06-05，真实车辆云端设防/解防/上电等命令生效）。

已完成：

- 新增官方云控车命令映射：
  - 设防 -> `lock`
  - 解防 -> `unlock`
  - 上电 -> `start`
  - 断电 -> `stop`
  - 寻车 -> `search`
  - 开坐垫 -> `openCushion`
- 复刻 Web 端 `getCommandImei()` 逻辑：
  - `modelType` 属于 GPS 车型时优先使用 `imeiGps`。
  - 其他车型使用 `imei`。
- 控制页支持通道选择：
  - 官方云端。
  - BLE 直连。
  - 自动：官方车辆有关联本地车辆时，仅关联的本地默认车 ready 才优先 BLE，否则走官方云端；未关联时保持 BLE ready 优先。
- 每次云控车后刷新车辆状态。
- 云控车失败时不影响 BLE 通道。
- 官方请求头兼容 `Forward-Service-Ip` 和 Web 侧历史 `Forward-ServiceIp`。

验收：

- `flutter analyze` 已通过。
- `flutter test` 已通过。
- 官方云端 `设防/解防/上电/断电/寻车/开坐垫` 可发送并展示结果。
- 云端命令失败时按钮状态能恢复。
- 危险动作仍有防误触。
- 云端和 BLE 的状态提示不会互相覆盖。

## 第三阶段：官方车辆详情和状态页

目标：把官方 App 的车辆详情字段接入当前车辆详情/设备信息页。

代码状态：已接入并完成真机验证（2026-06-05，真实车辆详情/状态展示通过）。

已完成：

- 官方云端车辆详情：
  - 车辆照片。
  - 车辆昵称。
  - 车架号。
  - 官方 IMEI/GPS IMEI。
  - 设防状态。
  - ACC 状态。
  - 电量、电压、里程。
  - 在线状态。
  - 经纬度。
- 和本地车库关联：
  - 通过 `btmac` / `btname` / 车辆名辅助匹配本地 BLE 车辆。
  - 用户可以手动把官方车辆和本地车辆绑定，绑定后同步切换本地默认车辆。
- 云端自检：
  - 已接入 `app/device/cmd/status`。
  - 当前只展示返回状态和原始字段摘要，字段含义待真实车辆确认。
- 状态来源标记：
  - 官方云端。
  - BLE 心跳。
  - 本地缓存。

验收：

- `flutter analyze` 已通过。
- `flutter test` 已通过。
- 用户能看出每个状态字段来自官方云、BLE 还是本地缓存。
- 官方车辆可以关联到本地 BLE 车辆。
- 官方云状态不覆盖未确认的 BLE/BMS 字段。
- 云端自检可发送并展示成功/失败，字段解释不做猜测。

## 第四阶段：官方服务生态页面复刻

目标：先复刻页面结构和低风险功能，不接入支付交易。

可做：

- 官方账号中心页面。
- 多车管理入口。
- 消息中心结构。
- 服务网点页面壳。
- 保养记录页面壳。
- 售后反馈页面壳。
- 家庭共享页面壳。
- 电子围栏页面壳。
- 骑行记录页面壳。

暂不做：

- 充电桩真实支付。
- 官方续费。
- 保险、商城、金融服务。
- 远程 OTA 写入。
- NFC 真加钥匙。
- 未验证的 ECU 高级写入。

验收：

- 页面流程接近官方 App。
- 没有后端数据时显示明确空状态。
- 不把占位功能伪装成已完成官方服务。

## 第五阶段：自建云端暂停项

`E:\aaatest\tailg-ble-cloud` 作为云端工作区保留，但近期暂停自建后端主线。

暂停内容：

- 自建账号系统。
- 自建车辆云同步。
- 自建家庭共享。
- 自建诊断报告云存储。
- 自建 BMS 历史曲线。

后续只有在官方云能力不足、接口不稳定或需要独立数据沉淀时，再恢复自建云端。

## 安全边界

- 不绕过官方短信验证码和 token 机制。
- 不绕过官方车辆绑定关系。
- 不公开或共享用户 token。
- 不把 token、手机号、IMEI 明文写入日志。
- 不做公共官方云代理服务。
- 不实现支付、续费、充电交易等高合规服务。
- 不开放未真机验证的 ECU 写入、OTA 或 NFC 真加钥匙。

## 建议执行顺序

1. 从 `tailg-ble-web` 梳理官方云接口，迁移 DTO 和命令映射。
2. App 新增 `OfficialCloudApi` 和 token 管理。
3. 新增官方账号登录页和官方车辆列表页。
4. 控制页接入官方云端控车通道。
5. 车辆详情页展示官方云端状态。
6. 再复刻官方服务生态页面壳。
