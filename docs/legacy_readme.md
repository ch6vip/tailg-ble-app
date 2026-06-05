# 旧版 README（归档）

> 本文件归档了旧版根目录 `README.md` 的原始内容（含特定开发机的 Windows 路径），仅作历史参考。
> 当前面向新读者的入口请见根目录 [`README.md`](../README.md)。

---

# tailg-ble-app

Flutter BLE 控制客户端，用于台铃电动车蓝牙解锁/上锁/开座桶等操作。对应 Web 端项目：[tailg-ble-web](../tailg-ble-web/)。

## 开发环境

| 组件 | 版本 | 路径 |
|------|------|------|
| Flutter | 3.32.1 (stable) | `E:\flutter\` |
| Dart | 3.8.1 | Flutter 自带 |
| Android SDK | 34 | `E:\Android\` |
| Build Tools | 34.0.0 | `E:\Android\build-tools\34.0.0\` |
| JDK | Temurin 17.0.19 | 系统 PATH |
| ADB | 37.0.0 | `C:\platform-tools\adb.exe` |

环境变量：
- `ANDROID_HOME` = `E:\Android`
- PATH 需包含 `E:\flutter\bin`

## 快速开始

```powershell
# 检查环境
flutter doctor

# 真机调试（手机开启 USB 调试后连接）
flutter run

# 构建 release APK
flutter build apk --release
```

## 支持的 BLE 协议

- 标准 fee5/AES 协议（KKS/BB/AX/JD/HJ/JW/XL/YY 车型）
- QGJ (Q_BASH) 3通道 kuyi 协议（feb0/fcc0 服务）

## 当前能力摘要

- 本地 BLE 控车：解锁、设防、寻车、开座桶、通电、断电
- QGJ 控车与设置：登录、心跳、重连、骑行模式、光感、声音、震动灵敏度
- QGJ 高级只读：自动锁车、上电自动锁车、感应状态/距离、HID、电子龙头锁、安全锁、边撑、坐垫、侧翻检测
- 车辆管理：本地车库、默认车辆、QGJ 登录参数、自动连接、感应解锁
- 官方云端：短信验证码登录、官方车辆列表/详情、BLE/官方云端/自动控车通道、官方云端基础控车
- 信息与诊断：电池/BMS 详情、设备信息、OTA 前置检测、故障诊断、日志和诊断报告

官方云端登录、车辆列表/详情/状态和基础云端控车已通过真实官方账号和车辆真机验证（2026-06-05）；高级 QGJ 写入、密码解锁、NFC 真加钥匙和 OTA 仍需真机验证后再开放。

## 项目信息

- 包名：`de.tttq.tailg_ble_app`
- 最低 Android 版本：待定（建议 API 23+，BLE 需要）
- 部署：GitHub Actions 编译 release APK
