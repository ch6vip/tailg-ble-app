# 功能清单 · 官方 App 完全复刻

> 产品目标：**完全复刻官方台铃智能 App 的功能与业务逻辑**（通道、状态机、API 语义）。  
> UI 为 Aurora，不要求像素 1:1。  
> 更新：2026-07-18 · 以当前 `feature/ble-adaptation` 代码为准

图例：✅ 已有可用实现 · 🟡 部分/实验 · ⏳ 未做 · ❌ 明确不做

---

## 范围分层

| 层 | 含义 | 本仓态度 |
|----|------|----------|
| **L0** | 控车主路径（登录、选车、六键、BLE/MQTT 分流） | **必须** |
| **L1** | 官方重度：轨迹围栏、消息、骑行统计、多车、权限引导 | **完全复刻必达** |
| **L2** | 车型深度：QGJ 全集、感应解锁、OTA、NFC、完整绑车 | **完美复刻** |
| **L3** | 商城/支付/保险/社区等运营 | **❌ 默认不做** |

**完全复刻 = L0 + L1** · **完美复刻 = L0 + L1 + L2**

---

## L0 — 控车主路径

| 能力 | 状态 | 说明 |
|------|------|------|
| 短信登录 / 会话保持 / 退出 | ✅ | `OfficialCloudService` + secure storage |
| 车辆列表同步与选车 | ✅ | 账号下车辆、默认车、多车切换 |
| 爱车主页状态机 | 🟡 | 登录/有车/加载等；持续按官方态对齐 |
| 六键控车（设防/解防/通电/断电/寻车/开坐垫） | ✅ | 命令态：发送中/成功/失败/未确认 |
| 通道分流 `modelType` + `isGps` + BLE LOGIN | ✅ | `OfficialControlRoute` |
| 近场 BLE：扫描、连接、LOGIN、本地发令 | 🟡 | `lib/ble/` + `ConnectionManager` + 自动连；真机矩阵待补 |
| 爱车近场自动连 / 横幅点连 | ✅ | `AutoConnectService` / `linkOfficialTarget` |
| 远程 MQTT 发令 + 预连接 + 状态回包 | 🟡 | `OfficialMqttService`；弱网/杀进程恢复待加强 |
| HTTP `device/cmd` 兜底 | ✅ | 与 MQTT 组合使用 |
| 电池基础信息 | ✅ | 电量/电压/温度等 + 刷新 |
| 失败语义（未登录/无蓝牙/未 LOGIN/无网…） | 🟡 | 主路径有反馈；边界用例持续补测试 |

---

## L1 — 高价值

| 能力 | 状态 | 说明 |
|------|------|------|
| 停车定位 | ✅ | 地图页 + 刷新/空态 |
| 历史轨迹 | ✅ | |
| 电子围栏读写 | ✅ | |
| 车辆消息 / 系统消息 | ✅ | `pageOfCarMsg` / `pageOfSysMsg`、已读、清空 |
| 通知偏好 | ✅ | |
| 骑行统计 / 碳排估算 | ✅ | |
| 车辆昵称回写 | ✅ | `updateCarInfo` |
| 车库 / 本地车辆档案 | ✅ | |
| 诊断记录 / 操作日志 / 导出 | ✅ | 日志含脱敏 |
| 应用偏好 / 关于 | ✅ | |
| 蓝牙·定位权限引导 | 🟡 | 有权限服务；系统设置跳转体验可再打磨 |
| 车况「最后同步 / 同步中」 | ✅ | 打开 App / 回前台 / 回爱车刷新 |

---

## L2 — 完美复刻（待做）

| 能力 | 状态 | 说明 |
|------|------|------|
| 扫码 / IMEI / 门店绑定 | ⏳ | 入口曾删；复刻需恢复闭环 |
| 解绑 / 换绑 / 转让 | ⏳ | |
| QGJ 高级设置全集 | ⏳ | 协议层有基础；设置页与持久化未齐 |
| 感应解锁 / 靠近解锁 | ⏳ | |
| OTA（报警器/中控/仪表） | ⏳ | |
| NFC 钥匙管理 | ⏳ | |
| 胎压 / 深度 ECU·BMS 写入 | ⏳ | |
| 家庭共享授权 | ⏳ | |
| 官方 modelType 全矩阵验收 | ⏳ | 需真机多车型 |
| Widget / 推送唤起 / 多端踢下线 | ⏳ | |

---

## L3 — 不做

| 能力 | 状态 |
|------|------|
| 商城、支付、保险、积分 | ❌ |
| 社区、直播、皮肤商城 | ❌ |
| 充电桩运营交易 | ❌ |
| 广告 / 纯运营弹窗 | ❌ |

占位入口若存在，应提示「非复刻范围」或移除，避免伪装已实现。

---

## 通道与数据（实现索引）

| 模块 | 路径 |
|------|------|
| BLE 协议 / 连接 | `lib/ble/` |
| 自动连 | `lib/services/auto_connect_service.dart` |
| 控车执行 / 策略 | `lib/services/control_command_*.dart` |
| 官方分流表 | `lib/services/official_control_route.dart` |
| MQTT | `lib/services/official_mqtt_*.dart` |
| 云 API | `lib/services/official_cloud_*.dart` |
| 爱车 UI | `lib/pages/vehicle_control_home_page.dart` |
| 扫描兜底 | `lib/pages/scan_page.dart` |

云端车辆 JSON 中的 `btname` / `btmac` / `bleConnect*` **会驱动近场连接**（与旧 cloud-only 叙事相反）。

---

## 验收方式

| 类型 | 要求 |
|------|------|
| 自动化 | `flutter test`；逻辑/路由/解析优先单测 |
| 静态 | `dart format` + `flutter analyze` |
| 真机（复刻主路径） | 登录 → 选车 → 近场 BLE 六键；远程 MQTT 六键；断蓝牙/断网失败语义 |
| 发布 | 测试线验证通过后再考虑移植正式线 `tailg-next` |

---

## 工程结构（源码）

```text
lib/
  ble/        近场
  services/   云 + MQTT + 路由 + 持久化
  models/
  pages/
  widgets/
  theme/
```

历史 cloud-only 进度文档与 `docs/` 目录已废弃删除；只维护本文件 + [README.md](README.md) + [AGENTS.md](AGENTS.md)。
