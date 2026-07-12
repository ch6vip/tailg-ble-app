# 官方云端架构方案

> 状态：**当前**
> 更新：2026-07-12
> 产品定位：官方账号 + 官方云 API 的 cloud-only Flutter 客户端

## 产品边界

- 控车、车辆状态、消息、定位、轨迹、围栏和电池数据只走官方云 API。
- 不提供本地硬件直连、扫描、GATT、感应解锁或离线控车兜底。
- 不实现扫码、IMEI、门店绑定、解绑或转让闭环，只同步官方账号下已有车辆。
- 不以实体手机、实体车辆或现场操作记录作为开发和发版前置条件。
- 支付、保险、商城、远程 OTA、NFC 写入和高级 ECU 写入不在当前范围。

## 当前架构

```text
Flutter UI
  |
  +-- pages / widgets
  |
  +-- OfficialCloudService
        |
        +-- OfficialCloudApiClient
        +-- parsers / models
        +-- secure credentials storage
        +-- local preferences and cache
```

页面只依赖统一的云服务状态，不选择或回退其他控车通道。官方云不可用时返回明确的失败或未确认状态。

## 已接通路径

- 短信验证码登录、Token 会话和退出
- 账号车辆列表、车辆详情和当前车辆选择
- 设防、解防、上电、断电、寻车、开坐垫
- 车辆状态刷新和控车后确认
- 车辆消息、系统消息和通知偏好
- 停车位置、历史轨迹、电子围栏读取与设置
- 电池信息、诊断日志和报告导出
- 多车切换、骑行统计和碳排估算

当前功能状态以 [../FEATURES.md](../FEATURES.md) 和 [cloud_only_alignment_progress.md](cloud_only_alignment_progress.md) 为准。

## 安全与错误处理

- 凭据仅存安全存储，不写入仓库、日志或诊断导出。
- 登录、短信和控车命令默认不做业务级自动重试。
- 只读请求可按既有重试策略处理瞬时网络或 5xx 错误。
- 控车结果区分发送中、成功、失败、超时和未确认。
- 高风险或未支持功能保持禁用，不通过其他本地通道绕过。

## 验收与发布

发布依据统一为自动化门禁：

1. Dart 格式检查
2. Flutter 静态分析
3. 单元测试和 widget 测试
4. 覆盖率阈值
5. GitHub Actions CI
6. 签名 APK artifact 构建

不要求真机回归、实体车辆回归或 Bluetooth 相关测试。具体命令见 [github_actions_guide.md](github_actions_guide.md)。

## 历史说明

本文件曾包含官方云与本地 BLE 双通道、实体车辆验证和本地兜底规划。该方案已于 2026-07-12 取消，旧正文仅可从 Git 历史查看，不应恢复为当前任务。
