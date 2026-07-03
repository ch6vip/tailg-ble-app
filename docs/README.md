# 项目文档索引

本目录收纳项目规划、验证和构建说明。根目录的 `README.md` 与 `FEATURES.md` 仍保留在项目入口处，方便 GitHub 首页直接展示。

## 推荐阅读顺序

1. [项目 README](../README.md)：开发环境、快速开始、当前能力摘要和文档入口。
2. [功能清单](../FEATURES.md)：已实现能力、与官方 3.5.6 的差距、工程结构和技术栈。
3. [官方 3.5.6 复刻对比简报](official_3_5_6_deep_comparison.md)：当前 App 与官方反编译结果的复刻度、差距和后续建议。
4. [当前设计系统索引](design_system.md)：主题 token、交互规则和页面模式。
5. [第一批功能真机验证清单](first_batch_verification.md)：真机测试步骤、待测项和回归验证。
6. [官方云端复刻方案](cloud_architecture_plan.md)：官方账号、官方云控车、BLE 兜底和服务生态规划。
7. [工程审视报告](工程审视报告_2026-06-28.md)：阶段性工程风险、已完成项和后续高风险方向。
8. [Android 构建说明](android_build_notes.md)：Windows/Android 构建时的已知问题和处理建议。

## 文档分类

| 分类 | 文档 | 用途 |
| --- | --- | --- |
| 项目入口 | [README](../README.md) | 面向新读者，说明项目是什么、怎么跑、当前支持什么 |
| 功能状态 | [FEATURES](../FEATURES.md) | 记录当前 App 能力、协议覆盖、官方差距和代码结构 |
| 复刻对比 | [official_3_5_6_deep_comparison](official_3_5_6_deep_comparison.md) | 记录官方 3.5.6 与当前项目的复刻度、主要差距和下一步建议 |
| 设计系统 | [design_system](design_system.md) | 记录当前主题 token、交互规则和页面模式 |
| 真机验证 | [first_batch_verification](first_batch_verification.md) | 记录暂不执行但后续必须跑的真机测试清单 |
| 云端方案 | [cloud_architecture_plan](cloud_architecture_plan.md) | 记录官方 App 复刻优先、官方云桥接、BLE 兜底和服务生态路线 |
| 工程审视 | [工程审视报告_2026-06-28](工程审视报告_2026-06-28.md) | 记录阶段性工程风险、修复证据和剩余高风险方向 |
| 构建说明 | [android_build_notes](android_build_notes.md) | 记录 Android 构建 warning 和本地处理顺序 |
| CI/CD | [github_actions_guide](github_actions_guide.md) | 记录 GitHub Actions 工作流、Secrets 和发布流程 |
| 后续规划 | [i18n-extraction-plan](i18n-extraction-plan.md) | 仅规划，记录未来 i18n 抽取方案 |

## 维护规则

- 新功能状态优先更新 [FEATURES](../FEATURES.md)。
- 官方 App 对齐、反编译证据和下一步建议更新到 [official_3_5_6_deep_comparison](official_3_5_6_deep_comparison.md)。
- 主题 token、视觉规则和交互模式更新到 [design_system](design_system.md)。
- 官方账号、官方云桥接、BLE 兜底和服务生态规划更新到 [cloud_architecture_plan](cloud_architecture_plan.md)。
- 阶段性工程风险、已完成修复证据和剩余高风险方向更新到 [工程审视报告](工程审视报告_2026-06-28.md)。
- 需要真机验证但暂不测试的事项写入 [first_batch_verification](first_batch_verification.md)。
- 构建、CI、环境问题写入 [android_build_notes](android_build_notes.md)、[github_actions_guide](github_actions_guide.md) 或根 README 的开发环境部分。
- iOS 资源目录里的 `README.md` 属于 Flutter 模板资源说明，不计入主要项目文档。
