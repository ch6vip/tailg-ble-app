# 项目文档索引

本目录收纳项目规划、验证和构建说明。根目录的 `README.md` 与 `FEATURES.md` 仍保留在项目入口处，方便 GitHub 首页直接展示。

## 推荐阅读顺序

1. [项目 README](../README.md)：开发环境、快速开始、当前能力摘要和文档入口。
2. [功能清单](../FEATURES.md)：已实现能力、与官方 3.5.6 的差距、工程结构和技术栈。
3. [官方 3.5.6 可安全复刻任务计划](official_replicable_tasks.md)：复刻范围、安全边界、已确认 QGJ 命令和后续任务。
4. [第一批功能真机验证清单](first_batch_verification.md)：真机测试步骤、待测项和回归验证。
5. [Android 构建说明](android_build_notes.md)：Windows/Android 构建时的已知问题和处理建议。

## 文档分类

| 分类 | 文档 | 用途 |
| --- | --- | --- |
| 项目入口 | [README](../README.md) | 面向新读者，说明项目是什么、怎么跑、当前支持什么 |
| 功能状态 | [FEATURES](../FEATURES.md) | 记录当前 App 能力、协议覆盖、官方差距和代码结构 |
| 复刻计划 | [official_replicable_tasks](official_replicable_tasks.md) | 记录官方 App 对齐任务、禁写边界和 QGJ 命令证据 |
| 真机验证 | [first_batch_verification](first_batch_verification.md) | 记录暂不执行但后续必须跑的真机测试清单 |
| 构建说明 | [android_build_notes](android_build_notes.md) | 记录 Android 构建 warning 和本地处理顺序 |

## 维护规则

- 新功能状态优先更新 [FEATURES](../FEATURES.md)。
- 官方 App 对齐、反编译证据和安全边界更新到 [official_replicable_tasks](official_replicable_tasks.md)。
- 需要真机验证但暂不测试的事项写入 [first_batch_verification](first_batch_verification.md)。
- 构建、CI、环境问题写入 [android_build_notes](android_build_notes.md) 或根 README 的开发环境部分。
- iOS 资源目录里的 `README.md` 属于 Flutter 模板资源说明，不计入主要项目文档。
