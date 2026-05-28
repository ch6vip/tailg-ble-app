# 官方 3.5.6 可安全复刻任务计划

目标：只复刻当前项目可以独立实现、或不会误写车辆 ECU 的功能。所有涉及车端写入的能力必须先完成反编译命令确认和真机验证，再从“待确认”升级为“可实现”。

对比来源：`E:\test\tlcq\_____3.5.6\apktool\res\layout` 和当前 Flutter 页面。

## 实施记录

- 2026-05-28：启动第一批复刻。首页已补 `车辆定位 / 功能设置 / QGJ音效设置 / NFC钥匙 / 今日骑行记录` 入口；`NFC钥匙 / 电子围栏 / 分享用车` 已接入本地数据页面；`今日骑行记录` 已基于本地车辆、位置和操作日志展示。所有新增页面均不调用 BLE 写入。
- 2026-05-28：控车按键区已复刻为官方两列结构：左侧两个快捷槽位，右侧上方滑动启停，下方 `寻车 / 设防` 并排；已新增“添加快捷键”页面并本地保存快捷槽位。断电状态下滑动组件已支持官方方向 `左滑关闭`。
- 2026-05-28：控车按钮效果已增强为单按钮反馈：按下缩放、高亮边框、当前按钮独立加载态，命令执行期间其他按钮置灰禁用，避免全局一起转圈。
- 2026-05-28：已补 `车辆信息` 与 `消息中心` 设置入口。车辆信息页复刻官方车辆/设备信息页的只读结构，展示本地车辆档案、BLE 连接状态、协议、QGJ 参数状态、180A 设备信息和 GATT 服务/特征；消息中心按官方 `系统消息 / 设备消息` 分组，把本地 BLE/操作日志映射为车辆消息，支持详情、已读和本地清空，不接入官方云端推送。
- 2026-05-29：已补官方设置基础项 `语言设置 / 单位设置 / 关于`。语言页按官方 `跟随系统 / 简体中文 / English` 结构保存本地偏好；单位页保存 `公制 / 英制`；关于页展示版本、Git 提交占位、开源依赖、GitHub 入口和诊断报告复制入口。
- 2026-05-29：继续对齐官方 QGJ V3 命令表。已从 `jadx\sources\com\kuyi\h\y0.java`、`CommonDataCodec.java`、`g0.java`、`h0.java` 确认 T10/T11 相关命令 ID 与基础 payload 编码，并补入 `QgjCommandIds` 与单元测试；未真机验证的高级写入仍不接入界面。
- 2026-05-29：新增 QGJ 高级设置只读页。页面只读取自动锁车、上电自动锁车、感应状态/距离、HID、电子龙头锁、安全锁、边撑、坐垫、侧翻检测等 GET 状态；密码解锁 GET 和 OTA 模式入口不自动触发。高级只读每条 GET 已记录命令名、请求 payload、响应 payload 和解析值，页面支持复制当前结果。

## 安全边界

- 可以直接做：页面结构、入口卡片、本地配置、本地记录、只读信息、外部地图跳转、占位说明。
- 可以预留入口：NFC、电子围栏、分享用车、骑行记录、消息、设备信息、音效包。
- 暂不写入车辆：自动下电、自动锁车、密码解锁、电子龙头锁、边撑感应、坐垫感应、侧翻检测、ECU 骑行高级功能、NFC 加钥匙、真正 OTA。
- 暂不复刻服务端闭环：登录验证码、支付、续费、门店售后、官方云端远程控车、官方推送。

## 第一批：纯 UI 和本地数据复刻

### T1 首页官方卡片补齐

来源布局：
- `fragment_control.xml`
- `activity_control_quick_edit.xml`
- `activity_nfc.xml`
- `activity_ride_record.xml`

任务：
- 在控制页补齐官方首页卡片顺序：控车区、车辆定位、功能设置、QGJ 音效 banner、NFC 钥匙、今日骑行记录。
- 保留当前已可用控车按钮，不改 BLE 指令。
- 对暂无实现的卡片点击进入说明页或占位页，而不是直接隐藏。

验收：
- 首页能看到 `功能设置 / NFC钥匙 / 今日骑行记录 / 车辆定位` 等官方主要入口。
- 页面在小屏幕不溢出，文字不重叠。
- `flutter analyze`、`flutter test` 通过。

### T2 控车快捷按钮编辑

来源布局：
- `activity_control_quick_edit.xml`
- `fragment_control.xml`

任务：
- 新增“快捷按钮编辑”页面。
- 支持把首页左侧快捷槽位配置为已实现命令：`开座桶 / 寻车 / 设防解锁 / 通电断电`。
- 配置只保存到本地，不新增车辆写入命令。

验收：
- 用户可调整首页快捷按钮显示项。
- 重新打开 App 后快捷按钮配置仍保留。
- 未连接车辆时按钮禁用逻辑保持一致。

### T3 NFC 钥匙页面壳

来源布局：
- `activity_nfc.xml`
- `activity_qgj_nfc_list.xml`
- `fragment_nfc_init.xml`
- `fragment_add_nfc.xml`
- `dialog_qgj_nfc_add.xml`
- `dialog_qgj_nfc_add_rename.xml`
- `dialog_qgj_nfc_add_delete.xml`

任务：
- 新增 NFC 钥匙入口页和本地钥匙列表页。
- 支持本地新增“手机/手表/卡片”钥匙占位记录、重命名、删除。
- 明确标记“未写入车辆”，真正加钥匙命令待确认。

验收：
- NFC 卡片从首页可进入。
- 本地钥匙列表支持增删改。
- 页面不调用 BLE 写入接口。

### T4 电子围栏本地页

来源布局：
- `activity_electric_fence.xml`
- `activity_electronic_fence_set.xml`
- `activity_fence_set_map.xml`
- `activity_electric_fence_help.xml`
- `pup_electric_fence.xml`
- `edit_fence_set_ring.xml`

任务：
- 新增电子围栏页面壳：开关、中心点、半径、通知说明。
- 先使用本地最后位置作为围栏中心，支持手动输入坐标和半径。
- 使用外部地图打开坐标；不引入官方云端围栏服务。

验收：
- 用户可创建、编辑、删除一个本地围栏配置。
- 围栏信息可持久化。
- 页面清楚区分“本地提醒配置”和“官方云端围栏”。

### T5 分享用车页面壳

来源布局：
- `activity_family_share_add.xml`
- `activity_family_share_tip.xml`
- `activity_share_detail.xml`
- `activity_share_succ.xml`
- `dialog_share.xml`
- `layout_share_qrcode.xml`

任务：
- 新增分享用车页面：车主信息、成员列表、邀请入口、分享说明。
- 本地维护“待邀请/已邀请”成员占位数据。
- 不生成真实官方分享授权，不调用服务端。

验收：
- 首页“分享用车”入口进入可用页面。
- 成员列表本地可新增、备注、移除。
- 页面文案不误导为已完成官方授权。

## 第二批：只读和本地记录增强

### T6 骑行记录和骑行统计

来源布局：
- `activity_ride_record.xml`
- `activity_ride_count.xml`
- `layout_merge_ride_record_params.xml`
- `pup_ride_count_tip_c.xml`

任务：
- 基于本地位置记录和控车事件生成简化骑行记录。
- 统计今日次数、最近控车时间、最后位置、估算里程。
- 不伪造官方云端轨迹回放。

验收：
- 首页“今日骑行记录”可进入统计页。
- 有真实本地数据时展示，没有数据时展示空状态。

### T7 设备信息页

来源布局：
- `activity_device_settings.xml`
- `activity_evbike_info.xml`
- `activity_evbike_info_detail.xml`

任务：
- 新增设备信息页。
- 读取当前 BLE 服务、特征、协议、180A 设备信息。
- 展示本地车辆档案、QGJ 登录参数状态、最后连接时间。

验收：
- 未连接车辆时展示本地档案。
- 已连接车辆时展示 BLE 服务和 180A 只读信息。

### T8 消息和安全提醒本地页

来源布局：
- `activity_message_setting.xml`
- `fragment_message_notification_evbike.xml`
- `activity_evbike_msg_deatil.xml`
- `activity_security_warning_setting.xml`

任务：
- 把本地 BLE/操作日志中的关键事件映射为“车辆消息”。
- 支持消息列表、详情、已读状态、清空。
- 不接入官方推送服务。

验收：
- 断连、重连、故障诊断、控车失败等事件可在消息页查看。
- 日志页原能力不退化。

### T9 设置页官方基础项

来源布局：
- `activity_language_settings.xml`
- `activity_unit_setting.xml`
- `fragment_settings_about.xml`
- `fragment_settings_about_officalsite.xml`

任务：
- 补齐语言、单位、关于页面入口。
- 单位设置先影响本地显示，例如距离单位。
- 关于页面展示版本、Git 提交、开源依赖和诊断导出入口。

验收：
- 设置页结构更接近官方。
- 本地设置可持久化并影响相关 UI。

## 第三批：命令确认后再实现

这些任务需要先从 JADX/抓包/真机验证中确认命令实体、payload、响应语义和失败回滚策略。

### 已确认的 QGJ V3 命令证据

来源：
- `jadx\sources\com\kuyi\h\y0.java`
- `jadx\sources\com\kuyi\blesdk\profile\data\CommonDataCodec.java`
- `jadx\sources\com\kuyi\h\g0.java`
- `jadx\sources\com\kuyi\h\h0.java`
- `jadx\sources\com\kuyi\blesdk\model\SingleConnectionViewModel.java`

| 能力 | 官方 Tag | 命令 ID | payload 状态 | 当前处理 |
| --- | --- | --- | --- | --- |
| 自动锁车开关/时间 | `ECU_AUTO_LOCK_GET/SET` 与 `ECU_AUTO_LOCK_TIME_GET/SET` | `0x2000/0x2001` | 时间为 `UInt16Value` 大端；开关 SET 为 `UInt16(45/0)` | 已记录常量和帧测试，未开放 UI |
| 上电自动锁车时间 | `ECU_POWER_ON_AUTO_LOCK_TIME_GET/SET` | `0x2010/0x2011` | `UInt16Value` 大端 | 已记录常量，未开放 UI |
| 感应/HID 状态 | `ECU_PROXIMITY_GET/SET_STATUS` | `0x2030/0x2031` | `SwitchState` 或 `OpCode`，需真机区分 | 已记录常量，未开放 UI |
| 感应/HID 距离 | `ECU_PROXIMITY_GET/SET_DISTANCE` | `0x2032/0x2033` | `UInt8Value` | 已记录常量和帧测试，未开放 UI |
| 电子龙头锁 | `ECU_HANDLEBAR_LOCK_ENABLED_SET/GET` | `0x2050/0x2051` | `SwitchState`，SET 支持 async flag | 已记录常量和帧测试，未开放 UI |
| 侧翻/姿态检测 | `ECU_POSTURE_DETECTION_SET/GET` | `0x2070/0x2071` | `SwitchState`，SET 支持 async flag | 已记录常量，未开放 UI |
| 密码解锁 | `ECU_PASSWORD_UNLOCK_GET/SET` | `0x2080/0x2081` | GET 为 `UInt8Value(0)`；SET 为专用结构 | 已记录常量和基础帧测试，未开放 UI |
| HID 配对状态 | `ECU_HID_SET/GET_STATUS` | `0x2140/0x2142` | `OpHID.Close/Open/OpenWithAutolock` 为 `0/1/2` | 已记录常量和帧测试，未开放 UI |
| 安全锁 | `ECU_SAFE_LOCK_SET/GET` | `0x2360/0x2361` | `SwitchState` | 已记录常量，未开放 UI |
| 边撑感应 | `ECU_KICKSTAND_ENABLED_SET/GET` | `0x2370/0x2371` | `SwitchState` | 已记录常量，未开放 UI |
| 坐垫感应 | `ECU_SEAT_SENSOR_ENABLED_SET/GET` | `0x2400/0x2401` | `SwitchState` | 已记录常量，未开放 UI |
| OTA 模式入口 | `ECU_ENTER_OTA_MODE` | `0x5004` | `CommonResult` | 只记录命令，禁止误触发 |

注意：官方 `CommandEntity` 构造参数中的 `4` 是 `FLAG_SUPPORT_ASYNC`，不是 payload 字节数。所有高级写入开放前必须先做只读刷新、写入确认、读回确认和失败回滚验证。

只读页当前覆盖：
- `0x2000` 自动锁车/自动锁车时间
- `0x2010` 上电自动锁车时间
- `0x2030/0x2032` 感应状态/距离
- `0x2051` 电子龙头锁
- `0x2071` 侧翻/姿态检测
- `0x2142` HID 配对状态
- `0x2361` 安全锁
- `0x2371` 边撑感应
- `0x2401` 坐垫感应

### 真机待测清单（暂不执行）

当前阶段不做真机测试，后续测试时按以下清单记录诊断报告和原始响应。

只读刷新待测：
- **连接稳定性**：进入 `车辆设置 -> 高级设置只读` 后连续刷新 3 次，记录是否断连、是否触发 Android 133、是否进入重连。
- **自动锁车/自动锁车时间 `0x2000`**：记录返回 payload。重点确认同一命令返回值到底是“开关阈值 45/0”、秒数，还是两者复用。
- **上电自动锁车时间 `0x2010`**：记录返回 payload，并确认单位是否为秒；官方 SET 使用 `PowerOnAutoLockTime.ordinal() * 60`。
- **感应状态 `0x2030`**：确认返回值是否严格为 `SwitchState 0/1`。
- **感应距离 `0x2032`**：确认返回值范围、档位含义和 UI 文案。
- **HID 配对状态 `0x2142`**：确认返回值 `0/1/2` 是否对应 `Close/Open/OpenWithAutolock`。
- **电子龙头锁 `0x2051`、安全锁 `0x2361`、边撑 `0x2371`、坐垫 `0x2401`、侧翻 `0x2071`**：确认返回值是否均为 `SwitchState 0/1`，并记录车辆实际配置与 UI 显示是否一致。
- **密码解锁 `0x2080`**：默认不测。若后续测试，需先明确是否会返回明文密码，只能在用户明确同意后单独读取。
- **OTA 入口 `0x5004`**：禁止测试，除非已准备固件、升级流程和失败恢复方案。

写入开放前待测：
- **所有 SET 命令统一流程**：先 GET 记录原值，再 SET 目标值，再 GET 读回确认，最后 SET 回原值并再次 GET 确认。
- **自动锁车 SET `0x2001`**：分别验证 `UInt16(45)` 和 `UInt16(0)`，确认是否只影响开关，是否影响时间值。
- **上电自动锁车 SET `0x2011`**：验证 0、60、120 等值；确认是否存在官方枚举限制。
- **感应状态 SET `0x2031`**：确认官方 `OpCode.OPEN/CLOSE` 最终编码是否等价于 `1/0`，不得直接按猜测开放。
- **感应距离 SET `0x2033`**：确认允许档位范围、越界响应和失败码。
- **电子龙头锁 SET `0x2050`、侧翻 SET `0x2070`**：官方命令带 async flag，需确认是否会延迟返回、多包返回或只通过读回体现结果。
- **HID SET `0x2140`**：验证 `0/1/2` 三档是否可逆，尤其 `OpenWithAutolock` 是否会联动自动锁车。
- **安全锁 SET `0x2360`、边撑 SET `0x2370`、坐垫 SET `0x2400`**：必须确认车辆状态限制，例如通电/断电/设防状态下是否允许修改。
- **密码解锁 SET `0x2081`**：暂不开放。测试前需确认密码长度、类型、错误次数限制、关闭密码的 payload、失败恢复方式。

测试报告必须包含：
- App 版本和 Git commit。
- 车辆蓝牙名称、MAC、协议识别结果。
- 每条命令的 cmdId、payload、响应 payload、是否 success。
- 操作前后车辆实际状态。
- 断连、重连、超时、Android 133 等 BLE 日志。

### T10 QGJ 车辆设置高级项

候选能力：
- 自动下电
- 自动锁车
- 密码解锁
- APP 遥控优先
- HID 配对距离

准入条件：
- 找到官方命令 ID、参数取值和响应解析。
- 增加单元测试覆盖 payload 构造和响应解析。
- 真机验证不会导致车辆不可控。

### T11 QGJ 车辆功能管理写入

候选能力：
- 电子龙头锁
- 电子边撑感应
- 坐垫感应
- 侧翻检测

准入条件：
- 明确是否写 `fcc1State1/2/3` 或独立 QGJ command。
- 写入时必须保留未修改位。
- 必须有读回确认。

### T12 QGJ 骑行高级功能写入

候选能力：
- 低电量骑行模式
- ESP+TCS
- 起步降流
- 定速巡航
- 软硬启动
- 上电默认档位
- 防溜坡/坡道驻车
- 氮气加速

准入条件：
- 明确每项 bit 位或命令实体。
- 有只读刷新页作为第一步，写入开关第二步再开放。

### T13 NFC 真加钥匙

候选能力：
- NFC 列表读取
- 添加钥匙
- 重命名钥匙
- 删除钥匙
- 强制删除/恢复

准入条件：
- 明确官方加钥匙流程中的 BLE 连接、车辆状态、超时、确认步骤。
- 真机验证失败时不会影响已有钥匙。

## 建议执行顺序

1. T1 首页官方卡片补齐
2. T2 控车快捷按钮编辑
3. T3 NFC 钥匙页面壳
4. T4 电子围栏本地页
5. T5 分享用车页面壳
6. T7 设备信息页
7. T8 消息和安全提醒本地页
8. T6 骑行记录和骑行统计
9. T9 设置页官方基础项
10. T10-T13 进入反编译命令确认和真机验证

## 每批完成标准

- 代码通过 `flutter analyze`。
- 单元/组件测试通过 `flutter test`。
- 新页面至少有空状态、未连接状态、已连接状态处理。
- 未确认命令不得调用 BLE 写入。
- 验证通过后提交并推送到 GitHub。
