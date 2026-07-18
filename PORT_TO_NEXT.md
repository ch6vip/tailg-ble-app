# 稳定能力移植 tailg-next 清单（PLAN P4-6）

> 源：`tailg-ble-app`（官方完全复刻线）  
> 目标：`tailg-next`（正式版，`com.ch6vip.tailg.next`）  
> 建立：2026-07-18 · 对照工作区 `版本说明.md`

## 原则

1. **先在 ble-app 验收**（单测 / 冒烟 / 真机）再移植  
2. 保持 next 的 applicationId / 品牌 / 云账号配置不变  
3. 优先移植「通道与状态机」，UI 用 next 现有设计系统

## 已具备、建议优先移植

| 能力 | ble-app 落点 | next 建议接入点 | 验收 |
|------|--------------|-----------------|------|
| 官方通道路由表 | `OfficialControlRoute` | 控车 service | 单测表驱动 |
| 通道 resolver | `ControlChannelResolver` | 同上 | 登录/无车/LOGIN 组合 |
| MQTT 优先 + HTTP 回落 | `OfficialMqttService.sendCommandPreferMqtt` | 远程控车 | mock 成功/回落 |
| 命令确认（publish≠执行） | `ControlCommandConfirmation` | 爱车发令 | 未确认文案 |
| LOGIN ≠ GATT ready | `ConnectionManager.isProtocolLoggedIn` | BLE 连接机 | 未 LOGIN 不 willUseBle |
| 换车断旧 BLE | `AutoConnectService.linkOfficialTarget` | 选车 | 不串车 |
| 登出断 MQTT/BLE | `afterLogoutSideEffects` | 会话层 | 退出不可发令 |
| 顶栏通道四态 | `ControlTopBarChannel` | 爱车顶栏 | 四态文案 |
| IMEI 绑车 / 解绑 | `bindVehicleByImei` / `unbindVehicle` | 添加车辆 / 设置 | API mock |
| QGJ 感应解锁读写 | `QgjSettingsPage` + 0x2030/31 | 设置 | LOGIN 后读写 |

## 移植步骤（每个能力）

1. 复制纯逻辑文件（尽量无 Flutter UI 依赖）  
2. 接 next 的 DI / service locator  
3. 补 next 侧单测（可复用 ble-app 表驱动用例）  
4. 真机或 mock 冒烟  
5. 在 next 发版说明中记录来源 commit

## 暂不移植

- 像素级官方 UI / 商城等 L3  
- 未在 ble-app 关门的 P3 深度（完整 OTA 分片写包、真 NFC 写车）  

## 完成定义

- [ ] 上表「建议优先移植」逐项在 next 有对应代码与测试  
- [ ] next CI 全绿  
- [ ] 版本说明中记录移植批次
