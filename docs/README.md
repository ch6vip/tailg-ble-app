# 项目文档索引

本目录收纳项目规划、验证和构建说明。根目录的 `README.md` 与 `FEATURES.md` 仍保留在项目入口处，方便 GitHub 首页直接展示。

> **当前产品定位**：官方云端控车（cloud-only）。本地 BLE 直连栈已移除。带「历史」标记的文档保留作决策背景，不再代表当前实现。

## 推荐阅读顺序

1. [项目 README](../README.md)：开发环境、快速开始、当前能力摘要。
2. [功能清单](../FEATURES.md)：当前 cloud-only 能力与已移除项。
3. [Cloud-only 对齐进度](cloud_only_alignment_progress.md)：P0 已完成；总览与后续优先级。
4. [P0.5 高价值路径优化](p0_5_high_value_path_progress.md)：A1–A5 已完成。
5. [真机回归 Checklist v1.0.13](device_regression_checklist_v1_0_13.md)：**发版前必做**。
6. [当前设计系统索引](design_system.md)：主题 token、交互规则和页面模式。
7. [第一批功能真机验证清单](first_batch_verification.md)：历史 BLE 清单，勿作本轮依据。
8. [Android 构建说明](android_build_notes.md)：Windows/Android 构建问题。
9. [GitHub Actions 指南](github_actions_guide.md)：CI/CD 与 Secrets。

## 文档分类

| 分类 | 文档 | 状态 | 用途 |
| --- | --- | --- | --- |
| 项目入口 | [README](../README.md) | 当前 | 项目说明与启动 |
| 功能状态 | [FEATURES](../FEATURES.md) | 当前 | cloud-only 能力清单 |
| 对齐进度 | [cloud_only_alignment_progress](cloud_only_alignment_progress.md) | P0 完成 | P0 任务看板与验收 |
| 路径优化 | [p0_5_high_value_path_progress](p0_5_high_value_path_progress.md) | 已完成 | A1–A5 高价值路径 / 状态机 |
| 真机回归 | [device_regression_checklist_v1_0_13](device_regression_checklist_v1_0_13.md) | **发版前** | P0+P0.5 真机勾选清单 |
| 设计系统 | [design_system](design_system.md) | 当前 | 主题与交互 |
| 真机验证 | [first_batch_verification](first_batch_verification.md) | **历史** | BLE 时代清单，勿作本轮依据 |
| 构建说明 | [android_build_notes](android_build_notes.md) | 当前 | Android 构建 |
| CI/CD | [github_actions_guide](github_actions_guide.md) | 当前 | Actions / Secrets |
| 复刻对比 | [official_3_5_6_deep_comparison](official_3_5_6_deep_comparison.md) | **历史** | BLE 时代官方对比 |
| 云端方案 | [cloud_architecture_plan](cloud_architecture_plan.md) | **历史** | 含 BLE 兜底规划 |
| 工程审视 | [工程审视报告_2026-06-28](工程审视报告_2026-06-28.md) | **历史** | 阶段性风险记录 |
| 后续规划 | [i18n-extraction-plan](i18n-extraction-plan.md) | 规划 | i18n 抽取 |

## 历史文档说明

以下文档写于本地 BLE 仍存在的阶段，**不要当作当前架构依据**：

- `official_3_5_6_deep_comparison.md`
- `cloud_architecture_plan.md`
- `工程审视报告_2026-06-28.md`
- `first_batch_verification.md`

如需恢复 BLE，应新开设计文档，而不是直接沿用上述规划。
