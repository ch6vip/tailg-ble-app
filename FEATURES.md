# Tailg BLE App - 功能清单

台铃电动车蓝牙控制 App（Flutter），支持 QGJ (Q_BASH) 和标准 (fee5/AES) 两种协议。

## BLE 连接与协议

- **双协议自动识别**：连接后自动检测 feb0 (QGJ) 或 fee5 (标准) 服务
- **QGJ 协议完整实现**：feb1 写入指令、feb2 indicate 接收响应、feb3 心跳保活
- **fcc0 服务订阅**：自动订阅 fcc1/fbb1/fcc2/fbb2（设备要求，否则超时断开）
- **心跳保活**：登录成功后 500ms 首次读取 feb3，之后每秒一次（匹配官方 app 时序）
- **自动重连**：断开后指数退避重连（3s→6s→8s，最多 8 次），重连后自动恢复订阅和心跳
- **UUID 模糊匹配**：兼容不同平台返回的 UUID 格式差异

## 车辆控制

- **基础控制**：解锁、设防、寻车、开座桶、通电、断电
- **滑动解锁**：右滑手势触发解锁，防误触
- **骑行模式切换**：节能 / 标准 / 强力 三档，写入 fcc1 后读回确认
- **感应解锁**：App 前台时 BLE 扫描已知设备，RSSI ≥ -75dBm 自动连接解锁（30s 冷却）

## 车辆状态

- **实时数据展示**：电量百分比（颜色图标）、电压、温度、锁/通电状态
- **数据来源**：feb3 心跳读取，1Hz 刷新
- **状态解析**：解析 feb3 原始字节（锁定、ACC、静音、震动、故障标志等）

## 车辆设置（fcc1 写入）

- **灯光控制**：前灯开关、转向灯模式
- **声音控制**：启动/上锁/解锁/通电提示音开关
- **蜂鸣器音量**：0-5 档滑块
- **防盗灵敏度**：1-5 档选择器，持久化保存
- **写入确认**：每次写入后 200ms 读回 fcc1 确认设备实际状态

## 故障诊断

- **一键诊断**：读取 feb3 故障字节，解析 6 种故障类型
- **故障类型**：电机故障、转把故障、控制器故障、电机缺相、刹车故障、欠压保护
- **显示格式**：原始错误码 (0xFF) + 每项正常/异常 + 可读描述
- **历史记录**：最近 20 条诊断记录，持久化存储

## 日志系统

- **双类型日志**：BLE 通信日志 + 操作日志
- **500 条环形缓冲**：自动淘汰旧记录
- **Tab 分类查看**：全部 / BLE / 操作
- **一键复制**：当前 tab 全部日志复制到剪贴板

## 工程与 CI

- **GitHub Actions CI**：每次 push 自动编译 APK
- **正式签名**：keystore 通过 GitHub Secrets 管理
- **版本发布**：打 `v*` tag 时自动创建 Release + 上传 APK
- **构建优化**：Flutter/Gradle 缓存、arm64-only、去 Jetifier
- **国内镜像兼容**：CI 环境跳过阿里云/腾讯云镜像，本地保留加速

## 项目结构

```
lib/
├── main.dart                    # 入口 + 导航 + 生命周期
├── ble/
│   ├── connection_manager.dart  # BLE 连接管理（双协议、重连、心跳）
│   ├── constants.dart           # UUID、命令码、车辆状态模型
│   ├── protocol.dart            # 标准协议帧构建
│   ├── qgj_protocol.dart        # QGJ 协议帧构建与解析
│   ├── parser.dart              # 标准协议响应解析
│   ├── aes.dart                 # AES-ECB 加密
│   └── hex.dart                 # Hex 工具
├── pages/
│   ├── scan_page.dart           # BLE 扫描页
│   ├── control_page.dart        # 控制页（状态+控制+模式）
│   ├── settings_page.dart       # 设置页
│   ├── vehicle_settings_page.dart # 灯光/声音/灵敏度设置
│   ├── diagnostic_page.dart     # 故障诊断
│   └── log_page.dart            # 日志查看
├── services/
│   ├── log_service.dart         # 日志服务
│   └── proximity_service.dart   # 感应解锁服务
└── widgets/
    └── slide_to_action.dart     # 滑动解锁组件
```

## 技术栈

- Flutter 3.32.1 + Dart 3.8
- flutter_blue_plus (BLE)
- permission_handler (权限)
- shared_preferences (持久化)
- encrypt (AES)
