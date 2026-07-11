# P0.5 高价值路径优化进度

> 状态：**已完成（5/5）**  
> 建立：2026-07-11  
> 更新：2026-07-11  
> 定位：在 cloud-only 边界内，吸收官方「爱车双态 / 状态驱动切换 / 功能门禁 / 可见刷新」的高价值逻辑  
> 上游分析：官方 `HomeActivity` + `ControlFragment` / `UnControlFragment` 跳转显示逻辑；本项目当前 `ControlPage` 双态实现

本文记录 **A 类高价值优化** 的任务拆分、验收标准与进度。  
不扩 BLE、不接圈子/商城、不做运营弹窗。

相关主线：

- [cloud_only_alignment_progress.md](cloud_only_alignment_progress.md)（P0 已完成）
- [FEATURES.md](../FEATURES.md)

---

## 1. 目标与原则

### 1.1 目标
把官方最有用的四件事落到 cloud-only：

1. **爱车单入口 + 内部分态**（bound / unbound / loading / needLogin）
2. **车辆状态变化后自动切 UI**（登录成功、同步选车、退出登录）
3. **功能入口统一门禁**（无车/未登录不乱跳）
4. **可见时刷新 + 控车后确认**（返回爱车页再 silent refresh）

### 1.2 非目标
- [x] 不做 BLE 绑定 / 扫码 IMEI / 门店绑定闭环
- [x] 不做到期提醒、直播跳转等运营弹窗
- [x] 不恢复圈子 / 商城 Tab
- [x] 不照搬官方 EventBus 魔法数字（518/519），只吸收状态语义

### 1.3 官方参考（摘要）

| 官方机制 | 含义 | 我们映射 |
| --- | --- | --- |
| `ControlFragment` / `UnControlFragment` 互斥 | 爱车双态 | `ControlPage` 内模式切换 |
| `bindingCar` + `modelType` + `isTelligence` | 是否显示控车壳 | cloud `selectedVehicle` + `modelType` + 登录态 |
| Event `519` / `518` | 跳已绑定 / 未绑定 | 本地状态机 + 导航回根 |
| 各入口先查 `bindingCar` | 功能门禁 | `requireCloudVehicle` 一类统一 gate |
| `onResume` / 下拉 / 换车刷新 | 状态可信 | 回前台 + 下拉 + **子页返回** silent refresh |

---

## 2. 任务看板

| ID | 项 | 状态 | 优先级 | 预估 | 备注 |
| --- | --- | --- | --- | --- | --- |
| A1 | 爱车页显式状态机 `ControlHomeMode` | **已完成** | P0.5 | 0.5–1d | 替换粗粒度 `showUnboundHome` bool |
| A2 | 登录/同步成功后自动回爱车 bound | **已完成** | P0.5 | 0.5d | 最大体感提升 |
| A3 | 未绑定绑定热区路径诚实化 | **已完成** | P0.5 | 0.5d | 去掉仅一项的假绑定方式弹窗 |
| A4 | 统一 `requireCloudVehicle` 功能门禁 | **已完成** | P0.5 | 0.5–1d | 定位/电池/消息/服务卡复用 |
| A5 | 子页返回爱车 silent refresh | **已完成** | P0.5 | 0.5d | 补齐可见刷新 |

### 进度统计
- 完成：**5 / 5**
- 进行中：**0**
- 阻塞：无

---

## 3. 任务明细

### A1 爱车页显式状态机

**现状（实现后）**

- `lib/services/control_home_mode.dart`：`ControlHomeMode` + 纯函数 `ControlHomeModeResolver.resolve`
- `control_page.dart` `_HomeBodyState` 使用 `ValueNotifier<ControlHomeMode>`
- 模式：
  - `bound` → bound-home
  - `loading` → `ValueKey('control-home-loading')` + CircularProgressIndicator
  - `needLogin` / `unbound` → `_UnboundVehicleHome`

**验收**
- [x] 模式切换有单测（纯函数优先）→ `test/control_home_mode_test.dart`
- [x] 未登录打开爱车：未绑定/需登录 UI，不闪 bound 控车六键
- [x] 登录并选中车后：自动进 bound（配合 A2）
- [x] 退出登录或清空车辆：回 unbound
- [x] 刷新过程有 loading（`cloudState.loading` 且无车时）

**状态**：已完成

---

### A2 登录 / 同步成功后自动回爱车 bound

**实现**
- `lib/services/app_navigation.dart`：`AppNavigation.returnToVehicleHome` / `focusVehicleTabAfterSignOut`
- 登录页成功路径与 `stateStream signedIn`：回根 + `homeTabIndex=1` + silent force refresh
- 云车辆卡 `selectVehicle` 后 `returnToVehicleHome`
- 退出登录（云页 / 我的）后切回爱车 Tab

**验收**
- [x] 登录成功自动落在爱车（有车 bound / 无车 unbound）
- [x] 云车辆页选中车辆后自动回爱车并 force 刷新
- [x] 退出登录回到爱车 unbound
- [x] 导航经 `AppServices`，避免 circular import

**状态**：已完成

---

### A3 未绑定绑定热区路径诚实化

**实现**
- 删除 `_showBindSheet` / `_UnboundBindMethodSheet` / `_BindMethodTile`
- 绑定热区：未登录 → `LoginPage`；已登录 → `AddVehiclePage`
- 保留登录按钮、消息、详情、无车 toast

**验收**
- [x] 绑定热区不再出现蓝牙选项 / 绑定方式 sheet
- [x] 未登录一点即达登录
- [x] 已登录一点即达添加车辆
- [x] widget 测试更新并通过

**状态**：已完成

---

### A4 统一功能门禁 `requireCloudVehicle`

**实现**
- `lib/widgets/cloud_vehicle_gate.dart`
- 策略：**snack + 立即跳转**（无 snack action，避免双导航）
- 接入：
  - `service_hub_page.dart` `_open`（官方账号 `requireVehicle: false`）
  - `control_page_service_cards.dart` `_open`
  - `control_page_home_overview.dart` 电池 / 快捷设置

**验收**
- [x] 未登录点车辆能力：统一文案 + 去登录
- [x] 已登录无车：统一文案 + 去同步车辆
- [x] 有车：静默放行
- [x] 不破坏 `featureUnavailable` 占位路径

**状态**：已完成

---

### A5 子页返回爱车 silent refresh

**实现**
- `main.dart`：`appRouteObserver` + `MaterialApp.navigatorObservers`
- `ControlPage`：`RouteAware` + `AutomaticKeepAliveClientMixin`
- `didPopNext` → silent force refresh（已登录）
- 保留 initState / Tab 切回 / 回前台刷新

**验收**
- [x] 从子页返回爱车触发 silent 刷新
- [x] 切 Tab 回爱车仍刷新
- [x] 未登录不发起无效请求

**状态**：已完成

---

## 4. 建议执行顺序

```text
A1–A5 已全部落地（实现顺序：A1/A5 核心壳 → A2 导航 → A3 诚实绑定 → A4 门禁）
```

---

## 5. 与已完成工作的衔接

| 已完成 | 与本清单关系 |
| --- | --- |
| P0 消息/控车可信/定位/电池 | 基线；A 类在其上做路径与状态机 |
| UnControl 官方布局重做 | A3 的 UI 基础 |
| 去掉蓝牙绑定入口 | A3 继续做「路径诚实」 |
| 回前台/下拉刷新 | A5 补「子页返回」缺口 |
| `OfficialVehicle.modelType` 已解析 | A1 降级策略可用，不整页打回 unbound |

---

## 6. 代码入口（当前）

| 区域 | 路径 |
| --- | --- |
| 爱车壳 / 双态 | `lib/pages/control_page.dart` |
| 未绑定 UI | `lib/pages/control_page_unbound_home.dart` |
| 已绑定 UI | `lib/pages/control_page_home_overview.dart` |
| 主 Tab / RouteObserver | `lib/main.dart`（`homeTabIndex` / `appRouteObserver`） |
| 模式解析 | `lib/services/control_home_mode.dart` |
| 导航回爱车 | `lib/services/app_navigation.dart` |
| 功能门禁 | `lib/widgets/cloud_vehicle_gate.dart` |
| 云状态 | `lib/services/official_cloud_service.dart` |
| 模式单测 | `test/control_home_mode_test.dart` |
| 未绑定测试 | `test/control_page_unbound_home_test.dart` |

---

## 7. 验收总清单（P0.5 完成定义）

- [x] A1–A5 全部勾选完成
- [x] 相关单测 / widget 测通过（见变更日志）
- [ ] 真机最小路径（完整清单：[device_regression_checklist_v1_0_13.md](device_regression_checklist_v1_0_13.md)）：
  - [ ] 冷启动未登录 → 爱车未绑定
  - [ ] 登录有车 → 自动回爱车并可控
  - [ ] 登录无车 → 爱车未绑定空态清晰
  - [ ] 未登录点定位/电池 → 统一引导
  - [ ] 子页返回爱车状态会更新
- [x] 文档本页状态改为「已完成」并回写 `cloud_only_alignment_progress.md`

---

## 8. 实现说明（摘要）

1. **A1**：`ControlHomeModeResolver` 纯函数 + `_HomeBody` 四态切换；bound 优先于 loading。
2. **A2**：`AppNavigation.returnToVehicleHome` 统一 popUntil 根 + 切爱车 Tab + silent force 刷新；登录/选车复用。
3. **A3**：绑定热区直达登录或添加车辆，删除单卡 sheet。
4. **A4**：`requireCloudVehicle` snack + 立即导航；服务中心 / 控车服务卡 / 电池入口接入。
5. **A5**：全局 `appRouteObserver`；`ControlPage.didPopNext` silent refresh。

---

## 9. 变更日志

| 日期 | 内容 |
| --- | --- |
| 2026-07-11 | 建立本文；收录 A1–A5 高价值优化项、验收与执行顺序；进度 0/5 |
| 2026-07-11 | 完成 A1–A5：ControlHomeMode / AppNavigation / 诚实绑定 / requireCloudVehicle / RouteAware silent refresh；相关测试通过；进度 5/5 |
| 2026-07-11 | 关联真机回归 checklist：device_regression_checklist_v1_0_13.md |
