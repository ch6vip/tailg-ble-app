# Cloud-only 对齐进度（非蓝牙）

> 状态：P0 已完成；P0.5 路径优化已完成  
> 更新：2026-07-11  
> 定位：官方账号 + 云端控车；**不做绑定闭环，不做 BLE 相关能力**

本文记录「对齐官方 App」的产品与工程进度，聚焦 **P0**，并给出后续优先级。  
相关历史文档见 `official_3_5_6_deep_comparison.md` / `cloud_architecture_plan.md`（已标记历史，不作为当前架构依据）。

---

## 1. 当前基线（已完成）

### 1.1 产品边界
- [x] 本地 BLE 栈移除（扫描 / GATT / 协议 / 感应解锁）
- [x] 控车通道仅官方云端
- [x] 删除扫码 / IMEI / 门店绑定 / 绑定帮助入口
- [x] 添加车辆仅保留「官方账号同步」
- [x] 占位入口统一「暂未开放」提示（NFC / 投屏 / 仪表 / 充电站等）

### 1.2 已接通的云端主路径
| 能力 | 接口 / 实现 | 状态 |
| --- | --- | --- |
| 短信登录 / 会话 | `app/getCode` `app/login` | 已有 |
| 车辆状态 | `app/centralControl/carStatus` | 已有 |
| 云端控车 | `app/device/cmd/*` | 已有 |
| 电池信息 | `app/mine/batteryInfo` | 已有 |
| 停车位置 | `app/car/extend/getByCarId` | 已有 |
| 电子围栏读取 | `app/device/getFenceData` | 已有 |
| 历史轨迹 | `deviceTravel` / `deviceTravelDetail` | 已有 |
| 车辆消息 | `app/msg/pageOfCarMsg` / `pageOfSysMsg` | **P0-1 已接** |
| 打开 App / 回前台 / 切回控车页自动刷新状态 | `refreshVehicles(silent:true, force:true)` | 已有（2026-07-11） |
| 下拉刷新车辆状态 | 控车页 RefreshIndicator | 已有 |
| 控车后状态确认轮询 | 锁/电门确认 | 已有 |
| 控车页「最后同步时间」 | `lastVehiclesRefreshAt` | **P0-2 已接** |
| 电池页「最后同步时间」 | `lastBatteryRefreshAt` | **P0-4 已接** |

### 1.3 P0 增强后的现状
| 模块 | P0 后状态 | 仍待办（二期） |
| --- | --- | --- |
| 消息中心 | 接官方 `pageOfCarMsg` / `pageOfSysMsg`，本地已读/清空 | 推送开关、服务端删除 |
| 控车反馈 | 最后同步时间、命令态文案统一、busy=「同步中」 | 真机确认弱网/超时体感 |
| 定位/轨迹/围栏 | 空态、刷新成功/失败反馈、登录引导、force 刷新 | 围栏写入（`updFenceData`） |
| 电池页 | 最后同步卡、成功/空态反馈、force 刷新 | BMS 写入/校准不做 |

---

## 2. P0 任务结果

> 原则：提升 cloud-only 的「可信控车 + 车况感知」，不扩生态功能。

### P0-1 车辆消息中心（官方消息）
**目标**：消息页从“本地日志映射”升级为“官方消息列表”。

官方参考接口：
- `app/msg/pageOfCarMsg`
- `app/msg/pageOfSysMsg`
- `app/msg/delMsg`（二期）
- `app/msg/getMessageControl` / `messageControl`（二期）
- `app/msg/setMessagePushConfig`（二期）

验收（已完成）：
- [x] 已登录可拉取车辆消息 / 系统消息
- [x] 首屏 + 下拉刷新
- [x] 详情 bottom sheet
- [x] 本地已读 / 本地清空（服务端删除二期）
- [x] 未登录空态引导登录
- [x] 失败可重试，不崩溃
- [x] 单测覆盖 parser + 关键 UI

### P0-2 控车结果与状态可信度
**目标**：用户始终知道「现在车什么状态、是否同步成功」。

范围（已完成）：
- [x] 控车页展示 **最后同步时间**（来自最近一次成功 `carStatus`）
- [x] 命令态：发送中 / 成功 / 失败 / 超时 文案统一
- [x] 控车成功后强制刷新状态 + 可见反馈
- [x] 同步失败明确提示，不误导为“已离线/未登录”
- [x] busy 状态显示「同步中」，不再出现错误登录提示

验收：
- [x] 已登录选车后，右滑启动/锁车反馈正确（代码层统一，待真机确认）
- [x] 弱网有失败提示且可重试（代码层统一，待真机确认）
- [x] 页面可见「刚刚同步 / x 分钟前同步」

### P0-3 定位 / 轨迹 / 围栏打磨
**目标**：现有页面“能用且稳”，不新开大模块。

范围（已完成）：
- [x] 停车位置刷新成功/失败态
- [x] 无位置 / 无轨迹空态文案
- [x] 轨迹按天浏览基础体验
- [x] 围栏只读信息完整（开关、半径、时间若有）
- [x] force 刷新（`refreshVehicleLocation` / `refreshFenceData` / `refreshTravelHistory`）
- [ ] 可选：围栏写入（`updFenceData`）——不做不阻塞 P0

验收：
- [x] 有车时位置页不空白
- [x] 无数据有明确说明
- [x] 刷新不会卡死或重复报错刷屏

### P0-4 电池信息增强（轻量）
**目标**：电池页成为可信信息页。

范围（已完成）：
- [x] 巩固 `mine/batteryInfo` 展示
- [x] 补充温度/电压/更新时间（最后同步卡）
- [x] 加载/失败/空态统一
- [x] force 刷新 + 成功/空态反馈
- [x] 不接复杂 BMS 设置

验收：
- [x] 登录有车时能看到电量与电压
- [x] 刷新行为可预期

---

## 3. 执行顺序（已完成）

```text
P0-1 消息中心（官方消息 API）        ✅
  ↓
P0-2 控车状态可信（最后同步时间 + 反馈） ✅
  ↓
P0-3 定位/轨迹/围栏打磨               ✅
  ↓
P0-4 电池页增强                       ✅
```

说明：
1. **消息**补“车找人”的感知；
2. **状态可信**补“人控车”的确定性；
3. **定位/电池**补日常查车信息。

---

## 4. 任务看板

| ID | 项 | 状态 | 备注 |
| --- | --- | --- | --- |
| P0-1 | 官方消息中心 | **已完成** | 已接 pageOfCarMsg/pageOfSysMsg；CI 通过 |
| P0-2 | 控车状态可信 | **已完成** | 最后同步时间 + 命令反馈统一 + busy/同步中；CI 通过 |
| P0-3 | 定位轨迹围栏打磨 | **已完成** | 空态/刷新反馈/登录引导 + force 刷新；CI 通过 |
| P0-4 | 电池信息增强 | **已完成** | 最后同步时间 + 成功/空态反馈 + force 刷新；CI 通过 |

### 进度统计
- P0 完成：**100%**（P0-1/2/3/4 全部完成，CI 通过）
- 当前动作：**P0 全部完成；建议真机回归后发 v1.0.13**

### P0-1 接口规格（来自官方反编译）

| 用途 | 方法 | 路径 | Body |
| --- | --- | --- | --- |
| 车辆消息 | POST | `app/msg/pageOfCarMsg` | `uid`, `pageSize`, `nowPageIndex` |
| 系统消息 | POST | `app/msg/pageOfSysMsg` | `pageSize`, `nowPageIndex` |
| 清空消息 | POST | `app/msg/delMsg` | 无 body（二期） |

车辆消息 record 关键字段：`msgId` / `title` / `content` / `sendTime` / `messageCode` / `carId`  
系统消息 record 关键字段：`sysMessageRecordId` / `title` / `content` / `sendTime` / `messageCode` / `url`  
分页外壳：`records` / `current` / `pages` / `total` / `size`

---

## 5. P0.5 高价值路径优化（已完成）

在 P0 可信控车基线上，吸收官方爱车双态 / 自动回首页 / 功能门禁 / 返回刷新。

详见专项进度：**[p0_5_high_value_path_progress.md](p0_5_high_value_path_progress.md)**

| ID | 项 | 状态 |
| --- | --- | --- |
| A1 | `ControlHomeMode` 状态机 | **已完成** |
| A2 | 登录/同步成功自动回爱车 bound | **已完成** |
| A3 | 未绑定绑定路径诚实化 | **已完成** |
| A4 | 统一 `requireCloudVehicle` 门禁 | **已完成** |
| A5 | 子页返回爱车 silent refresh | **已完成** |

---

## 6. 后续优先级（先不做，仅登记）


### P1
- 多车切换体验 / 当前车标识
- 云端车辆设置（昵称、围栏写入、通知偏好）
- 骑行统计 / 碳排
- 家庭共享（基础）

### P2 / 暂缓
- 充电站、商城、积分、社区
- OTA / 保险 / 支付
- 投屏、智能仪表真实能力
- 任何绑定新车流程、NFC 写入、BLE 相关

---

## 7. 非目标（明确不做）

- 扫码绑定 / IMEI 绑定 / 门店绑定
- 本地 BLE 控车、感应解锁、GATT 诊断
- 为“功能数量”复刻官方全量页面

---

## 8. 验收与发版建议

### P0 完成后建议
1. 真机回归：登录、控车六键、消息、定位、电池、回前台刷新  
2. 打 `v1.0.13`（或下一版本）release  
3. Release notes 写清：cloud-only + 消息/状态/定位/电池增强

完整可勾选清单见：**[device_regression_checklist_v1_0_13.md](device_regression_checklist_v1_0_13.md)**

### 真机最小清单
- [ ] 冷启动已登录 → 自动出最新电量/设防
- [ ] 回前台 → 状态刷新
- [ ] 控车页显示「刚刚同步 / N分钟前同步」
- [ ] 锁/解/上电/断电/寻车/开坐垫（成功/失败/未确认反馈）
- [ ] 消息列表有官方数据（车辆 + 系统）
- [ ] 位置/轨迹有数据或明确空态；未登录有引导
- [ ] 电池页显示电量/电压/温度 + 最后同步
- [ ] busy 时不再误提示「请登录」

---

## 9. 变更日志

| 日期 | 内容 |
| --- | --- |
| 2026-07-11 | 建立本文；确认先做 P0；记录 cloud-only 基线与自动刷新/busy 修复 |
| 2026-07-11 | 删除绑定入口；对齐官方“打开/回前台刷新 carStatus” |
| 2026-07-11 | P0-1：消息中心接入官方 `pageOfCarMsg` / `pageOfSysMsg` |
| 2026-07-11 | P0-2：控车页最后同步时间 + 命令反馈统一 |
| 2026-07-11 | P0-3：定位/轨迹/围栏空态与刷新反馈打磨 |
| 2026-07-11 | P0-4：电池页增加最后同步时间 + 成功/空态反馈 |
| 2026-07-11 | P0 全部完成，CI 通过；文档同步为完成态 |
| 2026-07-11 | 新增 P0.5 高价值路径优化进度文档（A1–A5） |
| 2026-07-11 | P0.5 A1–A5 全部完成（状态机/回爱车/诚实绑定/门禁/RouteAware 刷新） |

---

## 10. 相关代码入口

- 控车页：`lib/pages/control_page.dart` / `control_page_home_overview.dart`
- 云服务：`lib/services/official_cloud_service.dart`（`refreshMessages` / `lastVehiclesRefreshAt` / `lastBatteryRefreshAt`）
- 消息页：`lib/pages/vehicle_message_page.dart`
- 消息模型/解析：`lib/models/official_vehicle.dart`（`OfficialCloudMessage`）/ `lib/services/official_cloud_data_parser.dart`
- 定位：`lib/pages/location_page.dart` + tabs
- 电池：`lib/pages/battery_details_page.dart`
- 同步时间格式：`lib/services/display_time_formatter.dart`（`formatRelativeSyncText`）
- 生命周期刷新：`lib/main.dart`（`AppLifecycleState.resumed` / 切回车辆 Tab）
| 2026-07-11 | 新增真机回归 checklist（P0+P0.5 / v1.0.13） |
