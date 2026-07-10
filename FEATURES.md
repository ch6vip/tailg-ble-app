# Tailg Cloud App - 功能清单

台铃电动车 **官方云端** 控制 App（Flutter）。本地 BLE 直连栈已移除，控车与状态同步仅走官方云 API。

> 历史 BLE 协议、GATT、感应解锁等描述已过时；以下清单按当前 cloud-only 代码整理。

## 当前主线能力

- **官方账号登录**：短信验证码登录 / 退出 / 会话保持
- **车辆列表与详情**：账号下车辆、在线/电量/电压/设防/ACC 等状态
- **云端控车**：设防、解防、上电、断电、寻车、开坐垫
- **定位与轨迹**：位置、历史轨迹、电子围栏入口
- **电池详情**：云端电量与库仑计相关展示
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

- 扫码/IMEI/门店绑定流程未完整实现
- NFC、投屏、智能仪表、充电站等多为入口或占位
- OTA / 胎压 / 高级 ECU 写入未开放

详见 `docs/official_3_5_6_deep_comparison.md`。

## 工程结构（当前）

```
lib/
  services/   云端 API、持久化、控车路由、日志、定位
  models/     官方车辆与遥测模型
  pages/      控车主页、地图、车库、诊断、设置等
  widgets/    通用组件
  theme/      设计 token
```
