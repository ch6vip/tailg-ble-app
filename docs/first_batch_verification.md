# 第一批功能真机验证清单（已废弃）

> 状态：**不执行**
> 废弃日期：2026-07-12

本文件原用于验证本地车辆扫描、连接、QGJ 设置、电池协议、OTA 前置检查和实体车辆行为。上述本地硬件能力已从项目移除，相关验证项全部取消，不进入当前 backlog。

当前 cloud-only 项目不要求：

- 实体 Android 设备
- 实体车辆或真实车型覆盖
- 蓝牙扫描、连接、重连或权限验证
- GATT、设备协议或感应解锁验证
- 现场弱网、车辆动作或硬件写入记录

当前发布验收以自动化测试、覆盖率、GitHub Actions CI 和签名 APK 构建为准，见：

- [cloud_only_alignment_progress.md](cloud_only_alignment_progress.md)
- [github_actions_guide.md](github_actions_guide.md)
- [device_regression_checklist_v1_0_13.md](device_regression_checklist_v1_0_13.md)

旧清单内容仍可通过 Git 历史查看，不应复制回当前规划。
