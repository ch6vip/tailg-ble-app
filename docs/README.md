# 项目文档

> **master**：cloud-only（官方云账号控车）。  
> **feature/ble-adaptation**：实验分支，BLE 近场 + MQTT 远程；见下「实验分支」。

根目录入口：[README.md](../README.md) · [FEATURES.md](../FEATURES.md)

---

## 现行文档（少而精）

| 文档 | 用途 |
| --- | --- |
| [cloud_architecture_plan.md](cloud_architecture_plan.md) | 云端架构与产品边界 |
| [design_system.md](design_system.md) | 设计 token / 交互规则 |
| [github_actions_guide.md](github_actions_guide.md) | CI：format / analyze / test / coverage / APK |
| [android_build_notes.md](android_build_notes.md) | Android / Windows 构建注意 |
| [qgj_ble_residual_inventory.md](qgj_ble_residual_inventory.md) | QGJ/BLE 残留字段与删除边界（master 视角） |

## 实验分支（feature/ble-adaptation）

| 文档 | 用途 |
| --- | --- |
| [ble_adaptation_progress.md](ble_adaptation_progress.md) | 分支执行进度、架构、用法、真机清单 |
| [official_logic_parity_plan.md](official_logic_parity_plan.md) | 官方**功能/逻辑**完全·完美复刻蓝图（**不含 UI**） |

## 归档

历史完成/取消文档统一在 [archive/](archive/README.md)，不进当前 backlog。

---

## 推荐阅读

**只做云端（master）**

1. [../README.md](../README.md)  
2. [../FEATURES.md](../FEATURES.md)  
3. [cloud_architecture_plan.md](cloud_architecture_plan.md)  
4. [github_actions_guide.md](github_actions_guide.md)  

**做 BLE/MQTT 实验**

1. [ble_adaptation_progress.md](ble_adaptation_progress.md)  
2. [official_logic_parity_plan.md](official_logic_parity_plan.md)  
3. [qgj_ble_residual_inventory.md](qgj_ble_residual_inventory.md)（字段保留边界）  
