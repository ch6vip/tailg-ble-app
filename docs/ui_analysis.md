# Tailg BLE App — UI 界面全面分析报告

> 分析日期: 2026-06-26 | 基于 v8 "Aurora Cockpit" 设计语言

---

## 一、UI 架构总览

```
main.dart (入口 + 根路由)
  ├── Tab 0: ControlPage       — 控车（主页面，10 个 part 子文件）
  ├── Tab 1: LocationPage      — 定位（3 个 part 子文件：地图/轨迹/围栏）
  ├── Tab 2: GaragePage        — 车库（车辆列表管理）
  ├── Tab 3: ProfilePage       — 我的（v8 个人中心）
  └── 子页面（Navigator.push）:
       ├── BLE: ScanPage
       ├── 车辆: BatteryDetailsPage / DeviceInfoPage / VehicleSettingsPage
       ├── 诊断: DiagnosticPage / OtaPrecheckPage / QgjAdvancedSettingsPage
       ├── 云端: OfficialCloudPage / CloudTokenPage
       ├── 复刻: NfcKeyPage / ElectricFencePage / ShareBikePage 等
       └── 系统: SettingsPage / LogPage / VehicleMessagePage / AboutAppPage
```

**导航策略**: 无命名路由，全部使用 `Navigator.push(MaterialPageRoute(...))`。底部 4 个 Tab 使用 `IndexedStack` 保持状态，通过 `TickerMode` 暂停非活跃页面动画。

---

## 二、设计系统 (Design Tokens)

### 2.1 配色方案

| 类别 | Token | 值 | 用途 |
|------|-------|----|------|
| **主色** | `primary` | `#00C896` | 按钮、强调元素、品牌色 |
| **主色深** | `primaryDark` | `#00A57C` | 按压态、渐变终点 |
| **背景** | `pageBg` | `#F5F5F7` | 全局页面底色（冷灰，M3 风格） |
| **表面** | `surface` | `#FFFFFF` | 卡片、容器底色 |
| **文字主** | `textPrimary` | `#1A1A1A` | 标题、正文 |
| **文字辅** | `textSecondary` | `#666666` | 副标题、描述 |
| **功能色** | `success` `#00A896` / `warning` `#FF9800` / `danger` `#FF5252` | 状态指示 |
| **v8 强调** | `dark` `#1A1A1A` / `inkBtn` `#1B2230` / `energyGreen` `#00C896` | 深色面板、能量色 |
| **v8 辅助** | `accentViolet` `#7C6CFF` / `accentSky` `#2E9BFF` / `accentAmber` `#F5A623` | 差异化强调 |

### 2.2 圆角系统

```
xs(6) → sm(10) → md(14) → card(12) → tile(8) → lg(20) → sheet(18) → pill(999)
```

### 2.3 阴影系统（M3 3 级 elevation）

| 级别 | 用途 |
|------|------|
| `elevation1` | 卡片、Tile（轻微浮起） |
| `elevation2` | 浮动按钮、底部导航栏 |
| `elevation3` | 底部面板、Dialog |

### 2.4 间距系统

```
screenX: 20     — 屏幕水平边距
sectionGap: 20  — 区块间距
cardPadding: 16 — 卡片内边距
cardGap: 12     — 卡片之间间距
sectionTop: 16  — 区块顶部间距
```

### 2.5 文字系统（15+ 预定义样式）

`pageTitle(24)` → `subPageTitle(20)` → `cardTitle(17)` → `subtitle(16)` → `itemTitle(15)` → `bodyLarge(14)` → `bodyMedium(13)` → `valueText(13)` → `smallText(12)` → `caption(12)` → `sectionLabel(11)`

### 2.6 图标尺寸（4 级）

`sm(16)` → `md(20)` → `lg(24)` → `xl(48)`

### 2.7 Theme 配置

- **Material 3** — 使用 `ColorScheme.fromSeed`
- **明暗主题接线** — `ThemeMode.system` + `lightTheme`/`darkTheme` 已接入；硬编码颜色与 Token 对比度仍需专项审计
- **统一按钮**: `RoundedRectangleBorder` 14dp 圆角
- **Switch**: teal 轨道 + 白色 thumb
- **SnackBar**: floating + 10dp 圆角
- **Card**: 0 阴影白色底 + 12dp 圆角
- **TextScale**: 可配置跟随系统（默认 clamp 0.9-1.3x）
- **转场动画**: 统一淡入 + 轻微上滑（`_FadeUpPageTransitionsBuilder`）

---

## 三、页面结构分析

### 3.1 控车页 (ControlPage) — 应用核心

**架构**: 使用 Dart `part` 机制拆分为 12 个子文件，每个负责一个视觉区域。

| 子文件 | 职责 | 设计要点 |
|--------|------|---------|
| `control_page_hero.dart` | v8 Hero 区域 | 大电量百分比 + SOC 进度条 + 车辆名 + 连接标签 |
| `control_page_home_overview.dart` | 首页顶部区域 | Hero + 车辆 SVG 插图 + 状态芯片 + 控制卡片 |
| `control_page_main_controls.dart` | 主控区域 | SlideToAction 滑块 + 可排序按钮网格 + 编辑页 |
| `control_page_quick_controls.dart` | 快捷功能编辑 | 可配置快捷入口拖拽排序 |
| `control_page_service_cards.dart` | 服务卡片 + "全部功能" | v8 底部弹出面板 |
| `control_page_control_widgets.dart` | 连接控制 | 连接通道显示 + 手动模式 |
| `control_page_mode_widgets.dart` | 骑行模式 | Eco/Standard/Sport 选择器 |
| `control_page_vehicle_overview.dart` | 车辆概览 | 状态概览卡片 |
| `control_page_unbound_home.dart` | 未绑定引导 | 品牌 Logo + Banner + 操作按钮 |
| `control_page_visuals.dart` | CustomPainter 集 | 车辆插图、迷你地图、声波动画、扫光、脉冲 |

**数据流**: 组合多个 Stream 创建统一数据管道（`StreamController<List<dynamic>>`）

### 3.2 定位页 (LocationPage) — 三 Tab 结构

| Tab | 内容 | 技术栈 |
|-----|------|--------|
| 地图 | 瓦片地图 + 定位标注 + 围栏显示 | `flutter_map` + `CachedTileProvider` |
| 轨迹 | 月份选择器 + 按日期分组卡片 + 详情 sheet | 时间轴 UI（起点/终点 dot + 连接线） |
| 围栏 | 全屏出血地图 + 浮动底部面板 | `fullBleed` 布局 |

### 3.3 车库页 (GaragePage)

- 车辆卡片列表（VehicleStagePainter 缩略图）
- 默认车辆标识（teal 边框 + "默认"标签）
- 车辆操作菜单（重命名/删除/设默认/QGJ 凭证）
- 快捷操作（定位/控车按钮）

### 3.4 我的页 (ProfilePage) — v8 风格

- 用户头像 (teal 渐变圆形) + 昵称 + 金色渐变会员 pill
- 数据概览卡片（里程/次数/天数，竖向分隔线）
- 深色渐变会员横幅 (#1B2230 → #2A3342)
- 服务 + 设置分组（带红色 badge 的 Tile）
- 退出登录按钮

### 3.5 BLE 扫描页 (ScanPage)

- 雷达扫描动画（`_RadarPainter` CustomPainter: 同心圆 + 扇形扫光）
- 设备卡片入场动画（淡入 + 上滑）
- 信号强度可视化（4 格信号条，颜色区分强/中/弱）
- TAILG 设备自动高亮
- 底部圆形扫描 FAB（灰色停止 / 绿色扫描中 + 阴影）

### 3.6 电池详情页 (BatteryDetailsPage)

- 大号 Hero 区域（88px 数字 + BatteryReplicaPainter + 健康标签）
- 数据源标识条
- 深色 Summary Grid（4 格等分：里程/电压/容量/温度）
- 响应式 Metric Grid（Wrap 1-2 列）
- 故障卡片 + BMS 详情行（带数据源芯片）

### 3.7 设置页体系

| 页面 | 功能 |
|------|------|
| `SettingsPage` | 6 大分组（连接/通用/车辆/高级/调试/关于），卡片包裹 + 内置分隔线 |
| `LanguageSettingsPage` | Radio 选项 + 底部确认 |
| `UnitSettingsPage` | 单位选择 + 即时生效 |
| `AboutAppPage` | 版本信息 |

### 3.8 云端页面

| 页面 | 功能 |
|------|------|
| `OfficialCloudPage` | 登录/车辆列表/控车通道/关联本地车辆 |
| `CloudTokenPage` | Token 查看/保存/复制 |

### 3.9 复刻页面

`NfcKeyPage` / `ElectricFencePage` / `ShareBikePage` / `RideRecordPage` / `QgjSoundEffectsPage`

- 统一设计模式：`_ReplicaNotice` 告知"仅本地复刻，不写入车辆"
- 功能占位为主，数据持久化用 SharedPreferences

---

## 四、通用组件体系

| 组件 | 文件 | 用途 |
|------|------|------|
| `AppPageHeader` | `app_chrome.dart` | 统一标题栏（返回+标题+操作按钮） |
| `AppCard` | `app_chrome.dart` | 统一卡片容器（白底+20dp圆角+elevation1） |
| `AppSectionLabel` | `app_chrome.dart` | 分组标签（全大写+字母间距） |
| `ConnectionStatusBanner` | `app_chrome.dart` | BLE 连接状态横幅 |
| `AppSkeleton` | `app_chrome.dart` | 骨架屏（呼吸动画灰色条） |
| `AppEmptyState` | `app_chrome.dart` | 空状态（图标+标题+副标题） |
| `AppPressable` | `app_pressable.dart` | 通用按压反馈（缩放+颜色+haptic） |
| `AppSnack` | `app_snack.dart` | 统一 SnackBar（error/success/info） |
| `AppToast` | `app_toast.dart` | 顶部滑入 Toast（Overlay 实现） |
| `SlideToAction` | `slide_to_action.dart` | 滑动执行控件（20+ 可配置参数） |
| `StatusBadge` | `status_badge.dart` | 状态徽章（脉冲呼吸动画） |
| `VehicleStage` | `vehicle_stage.dart` | 电动车 SVG 插图 CustomPainter |
| `ControlCard` | `control_card.dart` | v8 浮动控制卡（中央电源旋钮+长按进度环） |

---

## 五、交互与动画模式

### 5.1 统一动画规范

- **时长**: `Duration(milliseconds: 150/200/300)` 分三档
- **曲线**: 主要使用 `Curves.easeOutCubic`
- **按压反馈**: `AnimatedScale(0.96-0.98)` + 颜色变化 + `HapticFeedback`
- **转场**: `FadeTransition` + `SlideTransition`（淡入上滑）

### 5.2 关键交互

| 交互 | 实现细节 |
|------|---------|
| **滑动执行** | `SlideToAction` — 双向支持、loading spinner、成功 glow 效果、居中/普通双模式 |
| **长按旋钮** | `ControlCard._PowerKnob` — 1.2s 进度环 (`_RingPainter` sweep angle 0→全圆) + 核心缩放 |
| **雷达扫描** | `_RadarPainter` — 同心圆 + Canvas.rotate 扇形扫光 |
| **脉冲动画** | `_PulsingDot` — 缩放 0.75→1.1 循环呼吸 |
| **入场动画** | 设备卡片 `_DeviceEntrance`：淡入 + 上滑 offset |
| **骨架屏** | `AppSkeleton` — 呼吸动画 Opacity 循环 |
| **底部面板** | 圆角顶部 + 拖动指示条 |
| **Toast** | `OverlayEntry` — 顶部滑入 300ms + 1.8s 自动消失 |

---

## 六、设计演进历程

从 `design_v2/` 目录可见，项目经历了 6 个设计版本迭代：

```
v3 (Dark)    →  深色主题探索
v4 (Refined) →  精炼迭代
v5 (iOS)     →  iOS 卡片风格
v6 (Xiaomi)  →  小米风格参考
v7 (Aurora)  →  Aurora 设计语言
v8 (Ninebot) → ✅ 当前实现基准（Ninebot 风格 + 翡翠绿主色）
```

v8 最终选择了 "Aurora Cockpit" 设计方向，以 Ninebot App 为参考蓝本，融合 Material 3 设计规范。

---

## 七、优势与亮点

1. **完整的设计 Token 体系** — `AppColors`/`AppRadii`/`AppSpacing`/`AppShadows`/`AppTextStyles`/`AppIconSizes` 六维 Token，全局统一，易于维护和主题切换

2. **设计迭代有据可查** — `design_v2/` 保留了完整的 6 版 HTML 设计稿，设计决策可追溯

3. **页面拆分合理** — 控车页通过 `part` 拆分为 12 个子文件，每个文件职责单一，最大子文件约 30KB，可维护性强

4. **组件复用率高** — `AppCard`/`AppPressable`/`AppSkeleton`/`AppEmptyState`/`StatusBadge` 等通用组件在多个页面中复用，减少重复代码

5. **动画统一规范** — 时长/曲线/按压反馈统一，体验一致

6. **M3 现代化基底** — Material 3 的 `ColorScheme`、Card/Switch/SnackBar 主题统一应用

7. **CustomPainter 运用得当** — 雷达、车辆插图、电池图形、进度环、声波动画都使用 CustomPainter 实现，不依赖外部库

8. **空状态/加载态/错误态覆盖完整** — 骨架屏 + 空状态 + ConnectionStatusBanner 覆盖主要边界情况

9. **多数据源组合流** — `StreamController<List<dynamic>>.broadcast()` 组合 BLE/云端/本地多个数据源，响应式更新

10. **Toast 用 OverlayEntry 实现** — 无需 BuildContext，全局可用，设计优雅

---

## 八、潜在改进点

1. **深色适配仍需审计** — 已接入 `ThemeMode.system` 和 `darkTheme`，但部分页面仍可能存在硬编码色/Token 漏迁移，需要按页面做对比度与视觉回归审计

2. **无命名路由** — 全部使用匿名 `Navigator.push`，不利于深度链接、URL 导航和路由拦截（如登录守卫）

3. **part 机制双刃剑** — 控车页 12 个 part 文件共享同一个私有命名空间，耦合度高，重命名/重构时需要跨文件检查

4. **复刻页面以占位为主** — NFC 钥匙/电子围栏/分享用车等功能实际未接入硬件，可考虑标记或隐藏

5. **车辆设置页大量禁用态** — `VehicleSettingsPage` 中很多功能使用 `_DisabledInfoRow`，直观体验不佳

6. **卡片/列表缺少下拉刷新** — 大部分数据页面无 pull-to-refresh，状态变更依赖 Stream 推送

7. **无响应式布局适配** — 首页使用固定 20px 边距的 phone 布局，平板/横屏体验可能较差

8. **无障碍支持不完整** — `AppPressable`、手动模式开关和部分图标已接入 `Semantics`/`semanticLabel`，但尚未覆盖所有自绘控件、状态卡和屏幕阅读器流程

9. **无本地化框架** — 文字直接硬编码中文，国际化需要全面改造

10. **部分 SVG 转为 CustomPainter 硬编码** — `VehicleStagePainter` 将 SVG 逐笔画转为 Dart 代码，设计变更时需要手动更新

---

## 九、技术栈图谱

```
UI 框架:     Flutter 3.x + Material 3
状态管理:    StreamBuilder + ValueNotifier + ChangeNotifier（无 Provider/Bloc/Riverpod）
地图:        flutter_map + CachedTileProvider
动画:        AnimatedScale / AnimatedContainer / AnimatedCrossFade / CustomPainter
持久化:      SharedPreferences + 自定义 VehicleStore
BLE:         自定义 BLE 协议栈 (lib/ble/)
云端:        自定义 HTTP 客户端 (lib/services/official_cloud_service.dart)
路由:        Navigator 1.0 匿名路由
测试:        flutter_test
```

---

## 十、总结

这是一个**设计系统完善、组件化程度高、有明确设计演进记录**的 Flutter IoT 控制应用。v8 "Aurora Cockpit" 设计语言以翡翠绿 `#00C896` 为品牌主色，Ninebot App 为交互蓝本，融合 Material 3 现代化设计规范，形成了一套从 Token → 组件 → 页面 → 交互的完整 UI 体系。

**核心特点**: 
- 重型 CustomPainter 实现品牌化视觉（雷达、车辆插图、进度环）
- 长篇滚动页面 + 底部导航 Tab 的经典移动端架构
- Stream 驱动数据更新，非传统状态管理框架
- 丰富的边界态覆盖（空状态/骨架屏/BLE 断连/未绑定引导）

**在同类 BLE IoT 项目中属于较高的 UI 完成度**，设计决策有据可查，适合作为后续迭代和团队协作的基线。
