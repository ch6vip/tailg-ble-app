# 项目文档索引

本目录收纳项目规划、验证和构建说明。根目录的 `README.md` 与 `FEATURES.md` 仍保留在项目入口处，方便 GitHub 首页直接展示。

> **当前产品定位（master）**：官方云端控车（cloud-only）。本地硬件直连栈和实体车辆回归要求在主线文档中仍按已移除处理。  
> **实验例外**：分支 `feature/ble-adaptation` 在试做 **BLE 近场 + MQTT 远程** 官方路径，详见 [ble_adaptation_progress.md](ble_adaptation_progress.md)；未合入前不改变 master 产品边界。

## 推荐阅读顺序

1. [项目 README](../README.md)：开发环境、快速开始、当前能力摘要。
2. [功能清单](../FEATURES.md)：当前 cloud-only 能力与已移除项。
3. [Cloud-only 对齐进度](cloud_only_alignment_progress.md)：P0 已完成；总览与后续优先级。
4. [P0.5 高价值路径优化](p0_5_high_value_path_progress.md)：A1–A5 已完成。
5. [GitHub Actions 指南](github_actions_guide.md)：当前自动化验收、APK 构建与发布门禁。
6. [当前设计系统索引](design_system.md)：主题 token、交互规则和页面模式。
7. [QGJ/BLE 残留清单](qgj_ble_residual_inventory.md)：凭据/死页面/云字段保留边界与删除切片。
8. [BLE / MQTT 适配实验](ble_adaptation_progress.md)：**仅 `feature/ble-adaptation`**；官方路径近场自动连 + MQTT 远程；未合入前不改变 master 产品边界。
9. [Android 构建说明](android_build_notes.md)：Windows/Android 构建问题。
10. [已废弃的真机回归清单](device_regression_checklist_v1_0_13.md)：历史归档，不执行。

## 文档分类

| 分类 | 文档 | 状态 | 用途 |
| --- | --- | --- | --- |
| 项目入口 | [README](../README.md) | 当前 | 项目说明与启动 |
| 功能状态 | [FEATURES](../FEATURES.md) | 当前 | cloud-only 能力清单 |
| 对齐进度 | [cloud_only_alignment_progress](cloud_only_alignment_progress.md) | P0 完成 | P0 任务看板与验收 |
| 路径优化 | [p0_5_high_value_path_progress](p0_5_high_value_path_progress.md) | 已完成 | A1–A5 高价值路径 / 状态机 |
| 自动化验收 | [github_actions_guide](github_actions_guide.md) | 当前 | format / analyze / test / coverage / APK build |
| 设计系统 | [design_system](design_system.md) | 当前 | 主题与交互 |
| 已废弃验收 | [device_regression_checklist_v1_0_13](device_regression_checklist_v1_0_13.md) | **已取消** | 不要求真机、实体车辆或蓝牙回归 |
| 真机验证 | [first_batch_verification](first_batch_verification.md) | **历史** | BLE 时代清单，全部任务已取消 |
| 构建说明 | [android_build_notes](android_build_notes.md) | 当前 | Android 构建 |
| CI/CD | [github_actions_guide](github_actions_guide.md) | 当前 | Actions / Secrets |
| 复刻对比 | [official_3_5_6_deep_comparison](official_3_5_6_deep_comparison.md) | 当前 | cloud-only 范围与差距 |
| 云端方案 | [cloud_architecture_plan](cloud_architecture_plan.md) | 当前 | cloud-only 架构与发布边界 |
| 残留审计 | [qgj_ble_residual_inventory](qgj_ble_residual_inventory.md) | 当前 | QGJ/BLE 残留清单与可删除评估 |
| BLE / MQTT 实验 | [ble_adaptation_progress](ble_adaptation_progress.md) | **实验分支** | 官方分流 + 近场自动连 + MQTT；真机验收前不改 master 边界 |
| 工程审视 | [工程审视报告_2026-06-28](工程审视报告_2026-06-28.md) | **历史** | 阶段性风险记录 |
| 后续规划 | [i18n-extraction-plan](i18n-extraction-plan.md) | 规划 | i18n 抽取 |

## 历史文档说明

以下文档包含本地硬件时代的历史内容，**不产生当前任务**：

- `工程审视报告_2026-06-28.md`
- `first_batch_verification.md`
- `device_regression_checklist_v1_0_13.md`

上述文档中的真机、实体车辆、BLE、GATT、扫描、近场控车和硬件写入事项均不进入当前 backlog。未来如重新评估，必须新立项，不得直接恢复旧任务。
