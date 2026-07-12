# 真机回归 Checklist（已废弃）

> 状态：**不执行**
> 原建立日期：2026-07-11
> 废弃日期：2026-07-12
> 当前产品边界：官方云端控车（cloud-only）

本文件原用于 `v1.0.13` 的实体 Android、实体车辆和弱网回归。当前项目已取消这类发布前置条件，原清单中的所有未勾选项均不再是待办，也不阻塞版本发布。

## 当前验收标准

发布前只要求以下自动化门禁通过：

1. `dart format --output=none --set-exit-if-changed .`
2. `flutter analyze --fatal-warnings --fatal-infos`
3. `flutter test --coverage`
4. `dart tool/check_coverage.dart coverage/lcov.info 40`
5. GitHub Actions CI 成功
6. 签名 APK artifact 构建成功

测试使用 mock、fixture、单元测试和 widget 测试覆盖登录状态、车辆选择、控车反馈、消息、定位、电池和页面导航。无需提供真实账号、真实车辆、实体手机或现场操作记录。

## 已取消范围

以下内容不再测试，也不进入项目 backlog：

- 实体车辆控车回归
- 实体 Android 设备兼容性回归
- BLE 扫描、连接、重连和近场控车
- GATT、设备协议、感应解锁和本地硬件诊断
- 蓝牙权限、蓝牙绑定和蓝牙设备发现
- 依赖真实车辆的弱网、车型或硬件差异验证

## 相关文档

- 当前进度与发布 Gate：[cloud_only_alignment_progress.md](cloud_only_alignment_progress.md)
- P0.5 自动化验收：[p0_5_high_value_path_progress.md](p0_5_high_value_path_progress.md)
- CI/CD 说明：[github_actions_guide.md](github_actions_guide.md)
- 更早的 BLE 真机清单：[first_batch_verification.md](first_batch_verification.md)（历史归档，同样不执行）

历史清单内容仍可通过 Git 历史查看，不应重新复制到当前规划中。
