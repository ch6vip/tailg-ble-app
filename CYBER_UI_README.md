# Cyber UI 设计实现文档

## 概述

基于设计图实现的 Cyber 风格车辆控制页面，采用浅色主题配色方案，提供现代化的用户界面。

## 已实现功能

### ✅ 1. 顶部状态栏 (`_CyberTopBar`)
- 车辆名称显示
- 续航里程显示（69km）
- 状态指示器：
  - 蓝牙连接状态
  - 信号状态
  - 锁定状态
- 右上角功能按钮：
  - 蓝牙连接按钮（圆形，蓝色高亮）
  - 通知按钮（圆形，灰色）

### ✅ 2. 车辆图片展示区域 (`_VehicleImageSection`)
- 支持点击展开/收起动画
- 收起状态：显示车辆小图
- 展开状态：
  - 显示车辆大图
  - 电池详情（电量百分比 + 预计里程）
  - 胎压温度显示（前后轮）

### ✅ 3. 8个圆形控制按钮 (`_ControlButtonsGrid`)
采用 4x2 网格布局：
- **第一行**：
  - 寻车（搜索图标）
  - 滑动开锁（锁图标，高亮显示）
  - 车辆设置（设置图标）
  - 打开坐垫（座椅图标）
- **第二行**：
  - 车辆分享（分享图标）
  - 密码解锁（数字键盘图标）
  - NFC钥匙（NFC图标）
  - 更多（省略号图标）

### ✅ 4. 仪表投屏导航区域 (`_NavigationProjectionCard`)
- 标题：仪表投屏导航
- 镜像投屏按钮（蓝色按钮）
- 搜索目的地输入框
- 快捷导航按钮：
  - 回家
  - 公司

### ✅ 5. 车辆位置地图卡片 (`_VehicleLocationCard`)
- 地图占位区域（180px高度）
- 左上角位置标签
- 准备集成 flutter_map

### ✅ 6. 骑行记录数据可视化 (`_RideStatsCard`)
- 最近骑行：7.8 km（粉色色块）
- 耗时：25 min（蓝色色块）
- 今日里程：14 km
- 总里程：686 km

### ✅ 7. 配色方案
- 背景色：浅灰色 `#F5F5F5`
- 卡片背景：白色 `#FFFFFF`
- 主色调：蓝色 `#2196F3`
- 文字颜色：深灰 `#1A1A1A`
- 次要文字：中灰 `#757575`

## 文件结构

```
lib/pages/
├── cyber_vehicle_control_page.dart  # 主页面实现
└── cyber_demo_page.dart             # 演示入口页面
```

## 使用方法

### 方式 1：通过演示页面
```dart
import 'package:tailg_ble_app/pages/cyber_demo_page.dart';

Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const CyberDemoPage()),
);
```

### 方式 2：直接使用主页面
```dart
import 'package:tailg_ble_app/pages/cyber_vehicle_control_page.dart';

Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const CyberVehicleControlPage()),
);
```

## 数据集成

页面已经集成以下服务：
- `officialCloudService` - 云端车辆数据
- `connectionManager` - 蓝牙连接管理
- `BatterySnapshot` - 电池信息

## 待完成功能（TODO）

### 🔲 1. 滑动开锁交互 (Task #4)
需要实现滑动手势识别，完成解锁动画效果。

### 🔲 2. 实际控车命令集成
8个按钮的 `onTap` 回调需要连接到实际的控车服务：
- 寻车 → `CommandCode.find`
- 开锁 → `CommandCode.unlock`
- 设置 → 导航到 `VehicleSettingsPage`
- 坐垫 → `CommandCode.openSeat`

### 🔲 3. 地图集成
`_VehicleLocationCard` 需要集成 `flutter_map` 显示实际位置。

### 🔲 4. 骑行数据曲线图
使用 `fl_chart` 包绘制距离和时间的曲线图。

### 🔲 5. 车辆分享功能 (Task #10)
生成分享二维码或链接。

### 🔲 6. NFC钥匙验证 (Task #11)
验证现有 `nfc_ble_frames.dart` 的支持情况。

### 🔲 7. 真实胎压温度数据
从 BMS 获取实际胎压和温度数据（当前使用占位数据）。

## 技术细节

### 动画效果
- 车辆图片展开/收起：300ms `easeInOut`
- 按钮点击反馈：触觉反馈 `HapticFeedback.selectionClick()`
- 卡片阴影：柔和阴影 `alpha: 0.05`

### 响应式布局
- 使用 `Expanded` 和 `Flexible` 确保适配不同屏幕
- 按钮网格采用 `spaceAround` 均匀分布
- 滚动视图支持小屏幕设备

### 性能优化
- 使用 `AutomaticKeepAliveClientMixin` 保持页面状态
- Stream 订阅在 `dispose` 时正确取消
- 避免不必要的 `setState` 调用

## 与现有系统集成

该页面可以作为独立模块运行，也可以集成到现有的 `HomePage` 中：

```dart
// 在 main.dart 中添加
import 'pages/cyber_vehicle_control_page.dart';

// 替换现有的 VehicleControlHomePage
const CyberVehicleControlPage(),
```

## 测试建议

1. **UI 测试**
   - 检查各种屏幕尺寸下的布局
   - 验证深色模式兼容性（如果需要）
   - 测试动画流畅度

2. **功能测试**
   - 蓝牙连接状态切换
   - 车辆数据更新
   - 按钮响应

3. **集成测试**
   - 与现有控车服务的对接
   - 数据同步测试
   - 错误处理

## 兼容性

- Flutter SDK: >=3.8.1 <4.0.0
- 已兼容现有项目依赖
- 使用标准 Material Design 组件
- 无需额外安装新包（除了可选的图表库）

## 下一步计划

1. 连接实际控车命令
2. 实现滑动开锁动画
3. 集成地图显示
4. 添加骑行数据曲线图
5. 完善错误处理和加载状态
6. 进行完整的用户测试

---

**创建时间**: 2026-07-24  
**版本**: v1.0.0  
**状态**: 🟢 UI实现完成，待功能集成
