# Tailg Cloud App - 功能清单

台铃电动车 **官方云端** 控制 App（Flutter）。本地 BLE 直连栈已移除，控车与状态同步仅走官方云 API。

> BLE 协议、GATT、扫描、感应解锁及所有实体车辆验收均已从产品范围移除；以下清单按当前 cloud-only 代码整理。

## 当前主线能力

- **官方账号登录**：短信验证码登录 / 退出 / 会话保持
- **车辆列表与详情**：账号下车辆、在线/电量/电压/设防/ACC 等状态
- **多车与骑行数据**：多车快速切换、月度骑行统计与碳排估算
- **云端控车**：设防、解防、上电、断电、寻车、开坐垫；命令态（发送中/成功/失败/未确认）统一反馈
- **车况可信**：打开 App / 回前台 / 切回控车页自动刷新 `carStatus`；控车页显示「最后同步时间」；busy 显示「同步中」
- **车辆消息中心**：官方车辆消息 / 系统消息（`pageOfCarMsg` / `pageOfSysMsg`），服务端清空与本地已读状态，未登录引导
- **定位与轨迹**：停车位置、历史轨迹、电子围栏及围栏设置；空态与刷新成功/失败反馈
- **电池详情**：电量/电压/温度/BMS 信息 +「最后同步」；force 刷新
- **诊断与日志**：历史诊断记录、操作日志、诊断导出
- **车库 / 设置 / 个人中心**：本地车辆档案与应用偏好

## 已移除

- `lib/ble/` 协议与 `ConnectionManager`
- 扫描页、设备信息页、OTA 前置页、QGJ 高级设置页
- `flutter_blue_plus` / `permission_handler`（BLE）/ AES 本地协议加密依赖
- Android / iOS 蓝牙权限声明
- 近场连接（本地 BLE 关联）空壳 UI

## 官方 API 字段说明

云端车辆 JSON 仍可能返回 `btname` / `btmac` / `bleConnect*` 等字段，仅作展示或兼容映射，**不驱动本地蓝牙连接**。

## 与官方 App 差距（摘要）

- 扫码/IMEI/门店绑定入口已删除，仅支持官方账号同步车辆
- NFC、投屏、智能仪表、充电站等多为入口或占位
- OTA / 胎压 / 高级 ECU 写入未开放

详见 `docs/official_3_5_6_deep_comparison.md`。

## 工程结构（当前）

```
lib/
  services/   云端 API、持久化、控车路由、日志、定位
  models/     官方车辆与遥测模型
  pages/      Aurora 控车主页、地图、车库、诊断、设置等
  widgets/    通用组件（AppPressable / VehicleStage / StatusBadge …）
  theme/      设计 token
```

QGJ/BLE 命名残留与可删除评估见 [docs/qgj_ble_residual_inventory.md](docs/qgj_ble_residual_inventory.md)。

爱车 Tab 主入口为 `lib/pages/vehicle_control_home_page.dart`（Open Design Aurora）。官方复刻 `ControlPage` / `ControlCard` 已于 2026-07-16 移除。
## 车辆添加策略

仅保留官方账号同步：

- 入口：添加车辆 →「我的车辆」→ 官方云端登录/车辆列表
- 已删除：扫码绑定、输入车架号/IMEI、门店购车绑定、绑定帮助

其他未实现能力（NFC、投屏、仪表、充电站等）统一提示「暂未开放，可先使用官方云端控车」。

## 对齐进度

当前主线见：

- [docs/cloud_only_alignment_progress.md](docs/cloud_only_alignment_progress.md)（P0 总览）
- [docs/p0_5_high_value_path_progress.md](docs/p0_5_high_value_path_progress.md)（P0.5 已完成）
- [docs/device_regression_checklist_v1_0_13.md](docs/device_regression_checklist_v1_0_13.md)（已废弃的真机/BLE 历史清单）

**P0 已全部完成并通过 CI**（非蓝牙）：

1. ✅ 官方消息中心（`pageOfCarMsg` / `pageOfSysMsg`）
2. ✅ 控车状态可信（最后同步时间 / 命令反馈统一 / busy=同步中）
3. ✅ 定位·轨迹·围栏打磨（空态 / 刷新反馈 / force 刷新）
4. ✅ 电池信息增强（最后同步 / 成功空态反馈 / force 刷新）

当前发布依据：**格式检查、静态分析、自动化测试、覆盖率门禁和 CI APK 构建**；不要求真机、实体车辆或 Bluetooth 回归。后续按 cloud-only API 和自动化测试推进 P1/P2。
