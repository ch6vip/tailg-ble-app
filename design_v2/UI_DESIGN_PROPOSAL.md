# Tailg BLE App — UI 设计方案 v2

> 版本：v2.0  日期：2026-06-22  设计：UI Designer  
> 适用：Tailg 电动车 BLE 控制 App（Flutter）  
> 基线：现有 v1（`lib/theme/app_colors.dart` + `design.html`）

---

## 0. 升级思路：迭代而非推翻

v1 已经做对了几件事，**这次升级保留**：

| 维度 | v1 现状 | v2 沿用 |
|---|---|---|
| 主操作色 | 极简黑 `#1A1A1A` | ✅ 保留 |
| 信息提示色 | Teal `#00A896` | ✅ 保留 |
| 圆角体系 | 6 / 10 / 14 / 20 四档 | ✅ 保留 |
| 阴影体系 | M3 elevation 1 / 2 / 3 三层 | ✅ 保留 |
| 字号体系 | 11 → 24 多档 w700 | ✅ 保留 |
| 卡片节奏 | 8 点网格、cardPadding=16 | ✅ 保留 |

v2 要解决的是 v1 留下的 **5 个痛点**：

1. **品牌温度缺失**：通屏冷黑白，缺安全/警示语义色，用户看不到"电动车该有的安全感"
2. **信息层级偏平**：电量、里程、状态同权重，新用户找不到"现在车是什么状态"
3. **核心动作埋得深**：滑动启动只有 1 个，但实际最高频是"解锁 + 通电"组合，需要双触达
4. **状态反馈不可见**：设防/解锁后只有图标变化，缺少视觉确认与微动效
5. **暗色模式空白**：夜间骑行场景高频，但目前只有 light 主题

---

## 1. 设计原则（Design Principles）

### P1 · 一眼看清状态
> 用户解锁 App 的 0.8 秒内必须知道：车在不在连接？电够不够骑？现在能不能上路？

- 顶部 Hero 区**单色编码**状态：Teal 在线 / Amber 重连中 / Red 离线
- 电量数字字号从 32 → 56，颜色随档位变化（绿/橙/红）
- 状态文案用一句完整人话，不是技术词（"已设防，未通电"而非"ARMED · ACC_OFF"）

### P2 · 核心动作触手可及
> 用户单手拇指自然弧度内，必须能完成 80% 的操作。

- 主操作区（屏幕底部 1/3）：**双滑动按钮并列**（左解锁 / 右通电），符合右手持机习惯
- 次操作区（中段）：6 宫格快捷键（设防 / 寻车 / 开座桶 / 模式 / 位置 / 设置）
- 三级操作（顶部 / 抽屉）：车库切换、消息、日志、诊断

### P3 · 反馈即时且明确
> 每一次点击都要让用户知道"我按了，车收到了"。

- 按钮按下：缩放 0.96 + 触觉震动（轻档）+ 颜色加深
- 指令执行中：thumb 内部扫光动画 + 进度环
- 指令成功：状态徽章脉冲一次 + Teal 对勾
- 指令失败：徽章变 Red + Toast 提示原因

### P4 · 安全语义优先
> 电动车涉及行驶安全，所有"风险/警示"信息用品牌红，且不可被忽略。

- 设防状态、低电量、故障、断连 → 红色徽章 + 顶部条幅
- 滑动操作必须**完整滑到底**，不可半途激活（防误触）
- 危险操作（断电、解除设防）二次确认 Sheet

### P5 · 暗色模式一等公民
> 骑行场景多在户外强光或夜间，暗色模式不是附属，是必需。

- 所有 token 双套定义（light / dark）
- 暗色背景不用纯黑，用 `#0E0F12`（带一丝冷蓝，更柔和）
- 卡片在暗色下用 `#1A1C20` + 1px 内描边 `rgba(255,255,255,0.06)` 替代阴影
- 状态色在暗色下提升 10% 亮度保证对比度

### P6 · 无障碍不妥协
> WCAG 2.1 AA 全量达标，触控目标 ≥ 44px，对比度 ≥ 4.5:1。

- 所有可点击元素 ≥ 44×44px
- 文本对比度：正文 ≥ 4.5:1，大字 ≥ 3:1
- 焦点态：2px Teal 描边 + 2px 间距
- 动效尊重 `prefers-reduced-motion`

---

## 2. 设计 Token 体系 v2

### 2.1 颜色（Light）

```dart
abstract final class AppColors {
  // ── 主操作色（沿用 v1）──────────────────────────────
  static const primary        = Color(0xFF1A1A1A);
  static const primaryDark    = Color(0xFF000000);
  static const onPrimary      = Color(0xFFFFFFFF);

  // ── 品牌语义色（v2 新增分层）────────────────────────
  static const brandRed       = Color(0xFFF11C2C); // 安全/警示
  static const brandRedSoft   = Color(0xFFFFE5E7); // 警示底色
  static const brandTeal      = Color(0xFF00A896); // 信息/在线
  static const brandTealSoft  = Color(0xFFE5F6F4); // 信息底色
  static const brandAmber     = Color(0xFFFFB300); // 重连/警告
  static const brandAmberSoft = Color(0xFFFFF4D6); // 警告底色

  // ── 状态色（语义化）─────────────────────────────────
  static const success = brandTeal;
  static const warning = Color(0xFFFF9800);
  static const danger  = brandRed;
  static const info    = brandTeal;

  // ── 文本层级（v2 强化对比度）────────────────────────
  static const textPrimary    = Color(0xFF0F0F10); // 主文本 ≥ 12:1
  static const textSecondary  = Color(0xFF4A4A4D); // 次文本 ≥ 7:1
  static const textTertiary   = Color(0xFF8A8A8E); // 辅助文本 ≥ 4.5:1
  static const textDisabled   = Color(0xFFB8B8BC); // 禁用 ≥ 3:1

  // ── 背景与表面（M3 surface tokens）──────────────────
  static const pageBg                  = Color(0xFFF5F5F7);
  static const surface                 = Color(0xFFFFFFFF);
  static const surfaceContainerLow     = Color(0xFFF8F8FA);
  static const surfaceContainerHigh    = Color(0xFFF0F0F4);
  static const surfaceBrandTint        = Color(0xFFF0FAF8); // Teal 浅底
  static const surfaceBrandRedTint     = Color(0xFFFFF1F2); // Red 浅底

  // ── 边线 ────────────────────────────────────────────
  static const border          = Color(0xFFEBEBEB);
  static const outlineVariant  = Color(0xFFE8E8EC);

  // ── 强调色（快捷功能图标）────────────────────────────
  static const accentViolet = Color(0xFF7B61FF);
  static const accentTeal   = Color(0xFF00A896);
  static const accentOrange = Color(0xFFFF8A00);
  static const accentBlue   = Color(0xFF3B82F6); // 限非主操作场景

  // ── 电量档位色（语义化梯度）─────────────────────────
  static const batteryHigh   = Color(0xFF00B894); // ≥ 60%
  static const batteryMid    = Color(0xFFFFB300); // 20-59%
  static const batteryLow    = Color(0xFFFF5252); // < 20%

  // ── 暗色表面 ────────────────────────────────────────
  static const darkSurface = Color(0xFF1A1A1A);
}
```

### 2.2 颜色（Dark · v2 新增）

```dart
abstract final class AppColorsDark {
  static const primary        = Color(0xFFF5F5F7); // 暗色下主操作反相
  static const onPrimary      = Color(0xFF0E0F12);
  static const pageBg         = Color(0xFF0E0F12); // 带冷蓝调的暗底
  static const surface        = Color(0xFF1A1C20);
  static const surfaceContainerLow  = Color(0xFF22252B);
  static const surfaceContainerHigh = Color(0xFF2A2D33);
  static const border         = Color(0xFF2A2D33);
  static const outlineVariant = Color(0xFF1F2227);

  // 暗色下品牌色提亮 10% 保证对比度
  static const brandRed       = Color(0xFFFF5566);
  static const brandTeal      = Color(0xFF33C9B8);
  static const brandAmber     = Color(0xFFFFCB4A);

  static const textPrimary    = Color(0xFFF5F5F7);
  static const textSecondary  = Color(0xFFB8B8BC);
  static const textTertiary   = Color(0xFF8A8A8E);

  static const batteryHigh    = Color(0xFF33D1AE);
  static const batteryMid     = Color(0xFFFFCB4A);
  static const batteryLow     = Color(0xFFFF7575);
}
```

### 2.3 字体层级（沿用 v1，强化用法）

| Token | 字号 | 字重 | 用途 | 对比度 |
|---|---|---|---|---|
| `displayHero` | 56 | w300 | 电量/里程大数字 | ≥ 3:1 |
| `pageTitle` | 24 | w700 | 顶部页面标题 | ≥ 4.5:1 |
| `cardTitle` | 17 | w800 | 卡片标题 | ≥ 4.5:1 |
| `itemTitle` | 15 | w700 | 列表项主文本 | ≥ 4.5:1 |
| `bodyMedium` | 13 | w400 | 正文 | ≥ 4.5:1 |
| `valueText` | 13 | w600 | 数值 | ≥ 4.5:1 |
| `sectionLabel` | 11 | w700 | 段落小标题，字距 1.5 | ≥ 4.5:1 |
| `caption` | 12 | w400 | 注释/时间戳 | ≥ 4.5:1 |

### 2.4 间距（8 点网格 · 沿用 v1，新增 section 层级）

```dart
abstract final class AppSpacing {
  static const xs    = 4.0;   // 紧凑间距
  static const sm    = 8.0;   // 元素内间距
  static const md    = 12.0;  // 卡片内间距
  static const lg    = 16.0;  // 卡片 padding
  static const xl    = 20.0;  // 屏幕边距
  static const xxl   = 24.0;  // 段落间距
  static const xxxl  = 32.0;  // 大段落间距 / hero 内间距

  // 语义化别名
  static const screenX        = xl;    // 屏幕左右边距
  static const sectionGap     = xxl;   // 段落之间
  static const sectionGapLg   = xxxl;  // Hero 区与下方
  static const cardPadding    = lg;
  static const cardGap        = md;
}
```

### 2.5 圆角 / 阴影 / 触控

```dart
abstract final class AppRadii {
  static const xs    = 6.0;   // 小标签
  static const sm    = 10.0;  // 输入框
  static const md    = 14.0;  // 普通卡片
  static const card  = 12.0;  // 标准卡片
  static const lg    = 20.0;  // 大卡片 / Hero
  static const sheet = 18.0;  // 底部 Sheet
  static const pill  = 999.0; // 胶囊
}

abstract final class AppShadows {
  // 沿用 v1 三层 elevation
  static const List<BoxShadow> elevation1 = [...]; // 卡片
  static const List<BoxShadow> elevation2 = [...]; // 浮层
  static const List<BoxShadow> elevation3 = [...]; // Dialog/FAB
}

abstract final class AppTouch {
  static const minTarget = 44.0;  // 最小触控目标
  static const comfort   = 48.0;  // 舒适触控（主操作 56+）
  static const primary   = 56.0;  // 主操作按钮高度
}
```

### 2.6 动效规范（v2 新增）

```dart
abstract final class AppMotion {
  // 时长
  static const fast     = Duration(milliseconds: 150); // 按压反馈
  static const normal   = Duration(milliseconds: 300); // 状态切换
  static const slow     = Duration(milliseconds: 500); // 页面过渡
  static const hero     = Duration(milliseconds: 800); // 数据加载

  // 曲线
  static const standard    = Curves.easeInOut;
  static const emphasized  = Curves.easeOutBack;  // 强调入场
  static const spring      = Curves.elasticOut;   // 弹性反馈
  static const settle      = Curves.fastOutSlowIn;
}
```

---

## 3. 组件库规范

### 3.1 按钮（Button）

| 类型 | 用途 | 样式 | 尺寸 |
|---|---|---|---|
| `PrimaryButton` | 主操作（确认、保存） | 黑底白字 + 圆角 14 | H=56, W=full |
| `SecondaryButton` | 次操作（取消） | 白底黑字 + 1px 边框 | H=48 |
| `GhostButton` | 文字按钮 | 透明底 + Teal 文字 | H=44 |
| `DangerButton` | 危险操作（断电） | Red 底白字 | H=56 |
| `IconButton` | 顶栏图标 | 圆形 44 + 半透明底 | 44×44 |
| `PillButton` | 标签/筛选 | 胶囊 + 选中态加深 | H=32 |

**状态**：default / pressed（scale 0.96 + 加深）/ loading（spinner）/ disabled（opacity 0.4）/ focus（2px Teal 描边）

### 3.2 卡片（Card）

| 类型 | 用途 | 关键样式 |
|---|---|---|
| `ElevatedCard` | 标准卡片 | 白底 + elevation1 + radius12 + padding16 |
| `HeroCard` | 顶部状态展示 | 渐变底 + radius20 + 内嵌大数字 |
| `TintedCard` | 信息提示 | `surfaceBrandTint` 底 + Teal 左边框 4px |
| `DangerCard` | 故障/警示 | `surfaceBrandRedTint` 底 + Red 图标 |
| `ActionCard` | 服务入口 | 白底 + 图标 + 标题 + 副标题 + 右箭头 |

### 3.3 滑动操作（SlideToAction · v2 升级）

```
┌─────────────────────────────────────────────┐
│  ┌──────┐                                    │
│  │ 电源 │  ←←←  右滑通电                     │
│  │ 图标 │                                    │
│  └──────┘                                    │
└─────────────────────────────────────────────┘
```

**v2 改动**：
- 高度从 88 → 96，更易滑
- thumb 从方形 76×76 → 圆形 84×84，更顺滑
- 加入**磁吸反馈**：滑到 80% 自动吸附到底
- 加入**扫光动画**：执行中 thumb 内有横扫高光
- 加入**进度环**：thumb 周围一圈 Teal 进度，到 100% 激活
- 完成 0.5s 后自动复位（如未触发其他状态切换）

### 3.4 状态徽章（StatusBadge）

| 状态 | 颜色 | 文案 | 用法 |
|---|---|---|---|
| 在线 | Teal | "在线" | 顶部 pill |
| 重连 | Amber | "重连中" | 顶部 pill + spinner |
| 离线 | Red | "未连接" | 顶部 pill |
| 已设防 | Red | "已设防" | 车辆状态 chip |
| 已通电 | Teal | "已通电" | 车辆状态 chip |
| 充电中 | Amber | "充电中" | 电池状态 chip |
| 故障 | Red | "故障" | 故障 chip + 闪烁 |

### 3.5 电池展示（BatteryDisplay）

```
┌─────────────────────────────┐
│        ┌─────────┐          │
│        │ ▮▮▮▮▮   │          │
│        │ ▮▮▮▮▮   │   80%    │
│        │ ▮▮▮▮░   │          │
│        └─────────┘          │
│                              │
│         健康 · 良好           │
└─────────────────────────────┘
```

- 电池图形随电量变色：≥60% Teal / 20-59% Amber / <20% Red
- 数字字号 56，w300，与 "%" 字号 24 对比
- 健康分用环形进度（120×120），分数居中

### 3.6 底部 Tab（BottomNav）

```
┌────────────┬────────────┬────────────┐
│     🏠     │     📍     │     ⚙     │
│   首页     │   位置     │   设置     │
└────────────┴────────────┴────────────┘
```

- 高度 64 + 安全区
- 半透明白底 + blur 12px
- 选中态：Teal 文字 + 顶部 2px Teal 短线（24px）
- 触控目标 ≥ 44px

### 3.7 Toast / Sheet / Dialog

| 类型 | 用途 | 样式 |
|---|---|---|
| `Toast` | 操作反馈 | 顶部下滑，Teal/Red 背景，2s 自动消失 |
| `ActionSheet` | 二次确认 | 底部上滑，圆角 18，毛玻璃背景 |
| `Dialog` | 重要信息 | 居中，圆角 20，elevation3 |
| `SnackBar` | 持久提示 | 底部，带"关闭"按钮 |

---

## 4. 关键页面信息架构调整

### 4.1 首页控车（核心改动）

**v1 结构**（8 段平铺）：头 / BLE / 统计 / 车身 / 提示 / 控制 / 服务卡片 / 骑行模式

**v2 结构**（双区聚焦）：

```
┌─────────────────────────────────────────────┐
│  Hero 区（前 40% 屏幕）                       │
│  ┌────────────────────────────────────────┐ │
│  │ 车辆名 ▾  在线 ●  消息  设置           │ │
│  │                                         │ │
│  │       80%      52 km                    │ │
│  │      剩余电量   预估里程                 │ │
│  │                                         │ │
│  │  [车辆 SVG · 带光影]                    │ │
│  │                                         │ │
│  │  已设防 · 未通电 · BLE                  │ │
│  └────────────────────────────────────────┘ │
├─────────────────────────────────────────────┤
│  控制区（后 60% 屏幕）                       │
│  ┌──────────────┬──────────────┐           │
│  │  ← 滑动解锁  │  滑动通电 →  │           │
│  └──────────────┴──────────────┘           │
│  ┌──┬──┬──┬──┬──┬──┐                       │
│  │设防│寻车│座桶│模式│位置│日志│            │
│  └──┴──┴──┴──┴──┴──┘                       │
│  ┌────────────────────────────────────────┐ │
│  │  快捷服务（横向滑动卡片）                │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**关键改动**：
- 取消"提示条 + 单滑动"区，改为**双滑动并列**，符合"解锁+通电"组合操作习惯
- 6 宫格替代原 4 宫格，更高密度但不拥挤
- 服务卡片从首页 9 张收敛为 5 张（高频），其余进二级页

### 4.2 电池信息页

**v2 改动**：
- 顶部 Hero 改用**环形进度**替代横向电池条，数字居中更突出
- BMS 字段分两栏（v1 单栏太长）：左栏"实时"（电压/电流/温度/循环），右栏"档案"（类型/容量/SN/版本）
- 故障卡单独成块，用 DangerCard 样式
- 底部新增"电池历史曲线"占位（即使暂不实现也保留位置，避免未来改版）

### 4.3 车辆定位页

**v2 改动**：
- 地图占满，顶部 floating 搜索框 + 切换 Tab（位置 / 轨迹 / 围栏）
- 底部 Sheet 抽屉化，半隐藏，上拉展开详情
- 浮动按钮收敛为 2 个（定位 / 复制坐标），减少视觉噪音

### 4.4 设置页

**v2 改动**：
- 分组卡片化：[骑行参数] [声音] [灯光] [防盗] [高级] [关于]
- 每项加入**当前值预览**（如"震动灵敏度 · 中"而非只显示项名）
- 高级设置加 🔒 锁标识，点击进二次确认

---

## 5. 暗色模式映射

| Light | Dark | 用途 |
|---|---|---|
| `#F5F5F7` | `#0E0F12` | 页面底 |
| `#FFFFFF` | `#1A1C20` | 卡片 |
| `#1A1A1A` | `#F5F5F7` | 主操作 / 主文本 |
| `#00A896` | `#33C9B8` | 信息色 |
| `#F11C2C` | `#FF5566` | 警示色 |
| `#FFB300` | `#FFCB4A` | 警告色 |
| `#0F0F10` | `#F5F5F7` | 主文本 |
| `#4A4A4D` | `#B8B8BC` | 次文本 |
| `#EBEBEB` | `#2A2D33` | 边线 |

**切换策略**：
- 跟随系统（默认）+ 手动切换
- 切换动效：500ms 颜色渐变，无 layout 变化
- 暗色下卡片用 1px 内描边替代阴影（`rgba(255,255,255,0.06)`）

---

## 6. 可访问性清单（WCAG 2.1 AA）

- [x] 所有文本对比度 ≥ 4.5:1（大字 ≥ 3:1）
- [x] 所有可点击元素 ≥ 44×44px
- [x] 焦点态 2px Teal 描边 + 2px 间距
- [x] 颜色不作为唯一信息载体（红/绿同时配图标）
- [x] 支持 `prefers-reduced-motion`，关键动效降级为渐变
- [x] 语义化 Widget（Semantics label 已覆盖）
- [x] 文本支持 200% 缩放不破版（基于 sp 字号）
- [x] 触控目标间距 ≥ 8px，防误触

---

## 7. 落地建议

### 7.1 实施优先级

| 优先级 | 改动 | 工作量 | 影响 |
|---|---|---|---|
| P0 | 首页双滑动 + 6 宫格重构 | 2 天 | 核心 UX |
| P0 | 状态徽章统一（StatusBadge 组件） | 0.5 天 | 全 App 一致性 |
| P1 | 暗色模式 token + 主题切换 | 1 天 | 夜间场景 |
| P1 | 电量档位色 + Hero 区字号放大 | 0.5 天 | 信息层级 |
| P2 | 电池页环形进度 + 双栏 BMS | 1 天 | 信息密度 |
| P2 | 滑动操作磁吸 + 扫光 + 进度环 | 1 天 | 微交互 |
| P3 | 设置页分组卡片化 + 值预览 | 0.5 天 | 易用性 |
| P3 | 动效规范落地（标准曲线） | 0.5 天 | 一致性 |

### 7.2 兼容性

- 所有新 token 与 v1 共存，分阶段迁移
- `AppColors` 保持向后兼容，新 token 加入但不删除旧 token
- 组件改造以增量方式进行，不破坏现有页面

### 7.3 设计交付

- 本文档：`design_v2/UI_DESIGN_PROPOSAL.md`
- 高保真原型：`design_v2/preview.html`（浏览器打开可交互预览）
- 设计 token 可视化：见对话内联展示
- 后续：Figma / Sketch 同步（如需）

---

## 8. 设计 QA 清单

实施完成后逐项验证：

- [ ] 首页双滑动可单手操作（右手拇指自然弧度）
- [ ] 所有按钮按下有 scale 0.96 反馈
- [ ] 状态徽章在 4 种状态下视觉清晰
- [ ] 电量数字在阳光下可读
- [ ] 暗色模式切换无 layout 抖动
- [ ] 滑动操作完整滑到底才触发，不可半途激活
- [ ] 故障状态有红色顶部条幅 + 触觉反馈
- [ ] 所有 Toast 2s 自动消失，不打断操作
- [ ] 焦点态在键盘导航下清晰可见
- [ ] `flutter analyze` 无新增 warning

---

**设计：UI Designer**  
**日期：2026-06-22**  
**版本：v2.0**  
**状态：待评审**
