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

## 项目信息

- 包名：`de.tttq.tailg_ble_app`
- 最低 Android 版本：待定（建议 API 23+，BLE 需要）
- 部署：GitHub Actions 编译 release APK

## 文档

- [功能清单](FEATURES.md)
- [第一批功能真机验证清单](docs/first_batch_verification.md)
- [Android 构建说明](docs/android_build_notes.md)
