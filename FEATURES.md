# Tailg BLE App - 功能清单

台铃电动车蓝牙控制 App（Flutter），支持 QGJ (Q_BASH) 和标准 (fee5/AES) 两种协议。

## BLE 连接与协议

- **双协议自动识别**：连接后自动检测 feb0 (QGJ) 或 fee5 (标准) 服务
- **QGJ 协议完整实现**：feb1 写入指令、feb2 indicate 接收响应、feb3 心跳保活
- **fcc0 服务订阅**：自动订阅 fcc1/fbb1/fcc2/fbb2（设备要求，否则超时断开）
- **QGJ 初始化对齐**：连接后按官方流程请求 515 MTU，并在存在 fe01 时订阅 fe03 GPS 通知
- **心跳保活**：登录成功后 500ms 首次读取 feb3，之后按官方 1 秒节奏轮询并串行化 GATT 操作，降低 Android 断连概率
- **自动重连**：断开后指数退避重连（3s→6s→8s，最多 8 次），重连后自动恢复订阅和心跳
- **UUID 模糊匹配**：兼容不同平台返回的 UUID 格式差异

## 车辆档案与车库

- **本地车辆档案**：保存车辆名称、蓝牙 ID、协议类型、创建/更新时间、最后连接时间
- **QGJ 登录参数**：每辆车可本地保存 ECU 登录密码和用户 UID，默认使用 0/0，便于对齐官方账号 UID 参与登录的车辆
- **扫描绑定车辆**：扫描页连接成功后自动加入车库，并设为默认车辆
- **我的车库**：支持查看车辆列表、编辑名称、切换默认车辆、删除车辆
- **默认车辆联动**：自动连接、感应解锁和控制页车辆名称优先使用默认车辆
- **旧数据兼容**：自动迁移原“上次连接设备”的自动连接配置

## 车辆控制

- **基础控制**：解锁、设防、寻车、开座桶、通电、断电
- **滑动解锁**：右滑手势触发解锁，防误触
- **骑行模式切换**：超能跑 / 全速跑 / 超速跑 三档，写入 fcc1 后读回确认
- **感应解锁**：App 前台时 BLE 扫描已知设备，RSSI ≥ -75dBm 自动连接解锁（30s 冷却）

## 车辆状态

- **实时数据展示**：电量百分比（颜色图标）、电压、温度、锁/通电状态
- **数据来源**：feb3 心跳读取，串行刷新
- **状态解析**：解析 feb3 原始字节（锁定、ACC、静音、震动、故障标志等）
- **电池/BMS 详情**：展示电量、电压、温度、信号、预估续航、故障状态，并预留 TLV/BMS 扩展字段

## 车辆位置

- **真实定位刷新**：位置页可请求系统定位权限并读取当前 GPS 位置
- **最后位置记录**：连接成功和控车成功后，会在已有定位权限时静默记录默认车辆位置
- **位置详情展示**：展示默认车辆、坐标、精度和记录时间
- **位置操作**：支持复制坐标、通过外部地图打开坐标

## 车辆设置

- **骑行参数**：设置页支持超能跑 / 全速跑 / 超速跑三档切换
- **官方对齐**：骑行模式使用 `fcc1` 当前状态字节，保留其他 ECU 位后写入并读回确认
- **光感开关**：使用官方 QGJ `ECU_LIGHT_SENSOR_ENABLED_GET/SET` (`0x2411/0x2410`) 读写
- **声音开关**：使用官方 QGJ `ECU_SOUND_ADJUST_GET/SET` (`0x2420/0x2421`) 读写启动、熄火、上锁、解锁、速度提示音
- **震动灵敏度**：使用官方 QGJ `ECU_VIBRATE_SENSITIVITY_GET/SET` (`0x2060/0x2061`) 四档值 `0/15/50/85`
- **高级设置只读**：支持读取自动锁车、上电自动锁车、感应状态/距离、HID、电子龙头锁、安全锁、边撑、坐垫、侧翻检测等官方 GET 状态，不执行高级 SET 写入；每条 GET 会记录命令、请求 payload、响应 payload 和解析值，并支持复制当前结果
- **风险禁写**：前灯、转向灯、蜂鸣器独立音量等未确认语义不写入设备
- **服务层封装**：QGJ 设置命令读写已抽离到 `VehicleSettingsService`

## 故障诊断

- **一键诊断**：读取 feb3 故障字节，按官方 active-high 故障位解析 6 种故障类型
- **故障类型**：电机故障、转把故障、控制器故障、电机缺相、刹车故障、欠压保护
- **显示格式**：原始错误码 (0xFF) + 每项正常/异常 + 可读描述
- **历史记录**：最近 20 条诊断记录，持久化存储

## OTA 前置检测

- **只读检测**：读取当前连接状态、协议类型和 BLE 服务能力，不执行任何固件写入
- **设备信息读取**：尝试读取 180A 设备信息服务中的型号、固件版本和制造商字段
- **兼容性提示**：识别 QGJ feb0、标准 fee5、扩展 fcc0 服务是否存在
- **风险提示**：明确真正 OTA 仍需确认固件来源、分包协议、断点恢复和失败回滚策略

## 日志系统

- **双类型日志**：BLE 通信日志 + 操作日志
- **500 条环形缓冲**：自动淘汰旧记录
- **Tab 分类查看**：全部 / BLE / 操作
- **诊断报告复制**：复制当前 tab 日志时附带车辆档案、协议、设备 ID、服务/特征 UUID 和环境摘要

## 与官方 3.5.6 功能差距

对比来源：`E:\test\tlcq\_____3.5.6` 的 apktool/JADX 静态反编译结果，主要参考
`AndroidManifest.xml` 中的 Activity 列表和
`jadx\sources\com\tailg\run\intelligence\model` 下的业务模块。

当前项目定位更接近“本地 BLE 控车工具”，尚不是官方“台铃智能”3.5.6 的完整复刻。

### 已覆盖的官方相关能力

- **本地蓝牙控车**：扫描、连接、重连、解锁、设防、寻车、开座桶、通电、断电
- **QGJ 基础协议**：登录、心跳、状态读取、基础响应解析
- **部分车辆设置**：骑行模式、光感开关、声音开关、防盗灵敏度已按官方 QGJ 命令适配
- **基础诊断与日志**：故障字节解析、诊断历史、BLE/操作日志
- **体验增强**：滑动解锁、感应解锁、基础位置入口、云 token 入口

### 官方有但当前未实现或未完整实现

- **账号与登录体系**：验证码登录、手机号登录、第三方登录、账号注销、换绑手机号、个人资料
- **车辆绑定与车库**：扫码绑定、手动绑定、IMEI 绑定、门店绑定、解绑限制、多车库管理、车辆切换
- **云端远程能力**：云端车辆状态、远程控车、智能服务续费、网络服务充值、车辆在线信息
- **真实地图定位**：车辆实时定位、地图搜索、导航、安全定位、定位纠错
- **历史轨迹与骑行统计**：轨迹列表、轨迹详情、轨迹回放、骑行统计
- **电子围栏**：围栏配置、围栏帮助、越界相关联动
- **电池/BMS**：BMS/TLV 电池详情、C39 电池信息、换电池、替换电池、电池 OTA
- **固件 OTA**：QGJ、报警器、控制器蓝牙、控制器 4G、GPS、C39、QGJ V3 等多类型升级流程
- **NFC 与数字钥匙**：NFC 方法页、NFC 列表、加钥匙、钥匙列表、钥匙扫描、车主转让
- **多车系设置**：QGJ、贝欧/BB、JLFBXW/C39 等车系的声音、音效、密码、功能、骑行、联网设置
- **胎压**：胎压主页、胎压设置、胎压蓝牙搜索、胎压绑定
- **充电桩与支付**：充电站列表、站点搜索、桩详情、扫码充电、支付、订单、异常上报
- **消息通知**：车辆消息、系统消息、消息详情、消息设置、推送集成
- **家庭共享**：家庭成员列表、分享添加、分享提示
- **售后与服务**：反馈、评价、门店网点、售后服务、流量查询、位置纠错
- **车机/手表扩展**：EasyConn 车机能力、USB/NFC 入口、手表扫码
- **高级灯光/雷达**：LED 效果列表、LED 效果设置、雷达相关设置

### QGJ 反编译对齐记录

- **骑行模式**：`QgjRideSettingFragment` 将 `EcuPodgStatus` 设置为 `001/010/011`，`TLinkBleManagerQgj.writeEcu(..., 10)` 写入 `fcc1State2` 低 3 位；当前已按此逻辑实现。
- **QGJ 档位文案**：官方三档为“超能跑 / 全速跑 / 超速跑”，四档扩展多一个“极速跑”；当前 UI 使用三档官方文案。
- **fcc1 状态字节**：官方把 `fcc1State1/2/3` 用作 TCS、定速、倒车、能量回收、低电循环、默认档位等 ECU 功能，不是前灯/转向灯状态；当前已禁用原灯光误写入口。
- **声音设置**：官方 `QgjSoundSetFragment` 使用 `ecuSoundAdjustGet/Set`，命令实体为 `ECU_SOUND_ADJUST_GET=9248`、`ECU_SOUND_ADJUST_SET=9249`，单项音量用 `OpSoundAdjust(index, volume)`，开关语义为 `0/100`；当前已支持 `1/3/14/15/17` 五个确认索引。
- **震动灵敏度**：官方 `EVBikeQgjSettingFragment` 使用 `ecuVibrateSensitivityGet/Set`，命令实体为 `8288/8289`，四档值为 `0/15/50/85`；当前已按“关闭/低/中/高”四档写入。
- **光感开关**：官方 `QgjFunctionSetFragment` 使用 `ecuLightSensorEnabledGet/Set`，命令实体为 `9233/9232`，`SwitchState.OFF/ON` 对应 `0/1`；当前已按此命令读写。
- **连接初始化**：官方 QGJ 管理器连接后 `requestMtu(515)`，订阅 `feb2` indications；若存在 `fe01` 则订阅 `fe03` notifications；登录后 `EcuStatus` 每 1000ms 读取 `feb3`。当前已按此节奏对齐。
- **ECU 登录参数**：官方 `QgjSearchBleFragment.sendDevicePwd(str)` 调用 `ecuLogin(str, PrefsUtil.getUid())`，BLE 层 `OpEcuLogin` 编码为 4 字节 password + 4 字节 userID；当前已支持在车库为单车配置这两个本地参数。
- **QGJ V3 高级设置命令表**：官方 `com/kuyi/h/y0.java` 注册了 `ECU_AUTO_LOCK_GET/SET` 与 `ECU_AUTO_LOCK_TIME_GET/SET` 复用 `0x2000/0x2001`、`ECU_POWER_ON_AUTO_LOCK_TIME_GET/SET=0x2010/0x2011`、`ECU_PROXIMITY_GET/SET_STATUS=0x2030/0x2031`、`ECU_PROXIMITY_GET/SET_DISTANCE=0x2032/0x2033`、`ECU_HANDLEBAR_LOCK_ENABLED_SET/GET=0x2050/0x2051`、`ECU_POSTURE_DETECTION_SET/GET=0x2070/0x2071`、`ECU_PASSWORD_UNLOCK_GET/SET=0x2080/0x2081`、`ECU_HID_SET/GET_STATUS=0x2140/0x2142`、`ECU_SAFE_LOCK_SET/GET=0x2360/0x2361`、`ECU_KICKSTAND_ENABLED_SET/GET=0x2370/0x2371`、`ECU_SEAT_SENSOR_ENABLED_SET/GET=0x2400/0x2401`、`ECU_ENTER_OTA_MODE=0x5004`；当前已记录常量和单元测试，但未开放写入 UI。
- **QGJ 通用 payload 编码**：官方 `CommonDataCodec` 使用大端 `UInt8/UInt16`，`SwitchState.OFF/ON` 对应 `0/1`，`CommonResult.OK` 对应 `0`；`CommandEntity` 第三个参数是 flag，`4` 表示 `FLAG_SUPPORT_ASYNC`，不是 payload 长度。
- **自动锁车开关与 HID 状态**：官方 `v0.java` 的自动锁车 SET 使用 `UInt16(45)` 表示开启、`UInt16(0)` 表示关闭；`i.java/j.java` 的 HID 状态使用 `OpHID.Close/Open/OpenWithAutolock` 枚举 ordinal `0/1/2`。
- **高级设置只读刷新**：当前页面只调用 `0x2000/0x2010/0x2030/0x2032/0x2051/0x2071/0x2142/0x2361/0x2371/0x2401` GET 命令；`0x2080` 密码解锁 GET 可能返回密码内容，默认不自动读取。
- **密码解锁命令**：官方 `SingleConnectionViewModel.ecuPasswordUnlockGet()` 发送 `ECU_PASSWORD_UNLOCK_GET` + `UInt8Value(0)`；`h0.java` 的 SET payload 顺序为 `state, (cate << 7) | type, [passwordLength, passwordBytes]`。因密码类型、长度限制和失败回滚尚未真机验证，当前只记录命令和测试帧。

### 建议实现优先级

1. **优先补 BLE 相关闭环**：车辆绑定/多车管理、QGJ 高级设置、NFC/加钥匙、OTA 前置检测。
2. **再补高频用车功能**：真实定位、轨迹、电子围栏、电池/BMS 详情、消息报警。
3. **最后考虑平台型功能**：登录体系、充电桩支付、售后服务、门店、续费等依赖官方服务端的模块。

## 工程与 CI

- **GitHub Actions CI**：每次 push 自动编译 APK
- **正式签名**：keystore 通过 GitHub Secrets 管理
- **版本发布**：打 `v*` tag 时自动创建 Release + 上传 APK
- **构建优化**：Flutter/Gradle 缓存、arm64-only、去 Jetifier
- **国内镜像兼容**：CI 环境跳过阿里云/腾讯云镜像，本地保留加速

## 项目结构

```
lib/
├── main.dart                    # 入口 + 导航 + 生命周期
├── models/
│   ├── vehicle_profile.dart     # 本地车辆档案模型
│   └── battery_snapshot.dart    # 电池/BMS 快照模型
├── ble/
│   ├── connection_manager.dart  # BLE 连接管理（双协议、重连、心跳）
│   ├── constants.dart           # UUID、命令码、车辆状态模型
│   ├── protocol.dart            # 标准协议帧构建
│   ├── qgj_protocol.dart        # QGJ 协议帧构建与解析
│   ├── parser.dart              # 标准协议响应解析
│   ├── aes.dart                 # AES-ECB 加密
│   └── hex.dart                 # Hex 工具
├── pages/
│   ├── scan_page.dart           # BLE 扫描页
│   ├── control_page.dart        # 控制页（状态+控制+模式）
│   ├── settings_page.dart       # 设置页
│   ├── garage_page.dart         # 本地车库/多车管理
│   ├── vehicle_settings_page.dart # 灯光/声音/灵敏度设置
│   ├── battery_details_page.dart # 电池/BMS 详情
│   ├── ota_precheck_page.dart   # OTA 前置检测
│   ├── diagnostic_page.dart     # 故障诊断
│   ├── location_page.dart       # 车辆位置页
│   ├── cloud_token_page.dart    # 云 Token 页
│   └── log_page.dart            # 日志查看
├── services/
│   ├── log_service.dart         # 日志服务
│   ├── vehicle_store.dart       # 本地车辆档案存储
│   ├── location_service.dart    # 定位权限和最后位置记录
│   ├── permission_service.dart  # 蓝牙/定位权限统一处理
│   ├── vehicle_settings_service.dart # QGJ 设置命令读写服务
│   ├── diagnostic_export_service.dart # 诊断报告导出
│   ├── auto_connect_service.dart # 默认车辆自动连接
│   └── proximity_service.dart   # 感应解锁服务
└── widgets/
    └── slide_to_action.dart     # 滑动解锁组件
```

## 技术栈

- Flutter 3.32.1 + Dart 3.8
- flutter_blue_plus (BLE)
- permission_handler (权限)
- geolocator (定位)
- url_launcher (外部地图)
- shared_preferences (持久化)
- encrypt (AES)
