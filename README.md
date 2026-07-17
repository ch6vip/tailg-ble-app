# Tailg BLE App · 官方 App 完全复刻

台铃电动车 **官方 App（台铃智能）的非官方 Flutter 完全复刻**。

目标不是「只做云端遥控器」，而是在功能、业务逻辑、数据通道与状态机上 **对齐官方**：近场 BLE、远程 MQTT、云 API、绑车与车况全链路可用。UI 采用自有 Aurora 设计语言，**不要求像素级抄皮肤**。

> ⚠️ 仅供学习研究与个人车辆管理。请勿用于未授权车辆或任何违法用途。

| | |
|--|--|
| 仓库 | [`ch6vip/tailg-ble-app`](https://github.com/ch6vip/tailg-ble-app) · Public |
| 角色 | 工作区内 **测试 / 复刻实验线**（正式 cloud 产品线见 [`tailg-next`](https://github.com/ch6vip/tailg-next)） |
| 对照源 | 官方包 `台铃智能` · 反编译 `E:\ctf-aaa\tlddc\decompiled`（`com.tailg.run.intelligence`） |
| 技术栈 | Flutter 3.44.6 · Dart 3.12.2 · Android API 23+ |
| 包名 | Dart `tailg_ble_app` · Android `de.tttq.tailg_ble_app` · 显示名「台铃智能」 |
| 版本 | 以 `pubspec.yaml` 为准（当前 `1.1.0+14`） |

---

## 产品目标

### 完全复刻（Complete）= 默认交付线

在**不依赖官方 UI** 的前提下，做到与官方一致的：

| 维度 | 标准 |
|------|------|
| 功能覆盖 | 账号、车辆、六键控车、近场 BLE、远程 MQTT、电池、定位/轨迹/围栏、消息等主路径可用 |
| 通道逻辑 | 分流与官方 `ControlFragment` + `ControlTypeUtil` 一致（`modelType` / `isGps` / BLE LOGIN） |
| 近场 | 登录 → 选车 → 进爱车 → 自动/点连 BLE → LOGIN 后本地控车 |
| 远程 | 允许远程时 **MQTT 主路径**，HTTP `device/cmd` 兜底；状态回包更新 ACC/设防 |
| 数据语义 | 列表、状态、电池、定位、消息等与官方 API 语义一致 |
| 失败语义 | 未登录 / 无车 / 蓝牙未开 / 未 LOGIN / 无网 / MQTT 未连 / 指令未确认 → 明确结果，禁止静默假成功 |

### 完美复刻（Perfect）= 后续加深

车型矩阵、QGJ 设置全集、感应解锁、OTA、NFC 钥匙、绑定闭环（扫码/IMEI/门店/解绑/转让）等。详见 [FEATURES.md](FEATURES.md)。

### 明确不做（L3，非控车主业）

商城、支付、保险、积分、社区/直播、充电运营交易、广告位等。需要时单独立项，不挡控车复刻主线。

---

## 当前能力快照

| 通道 | 状态 | 说明 |
|------|------|------|
| 官方云 API | ✅ 主路径 | 登录、车辆同步、状态、消息、定位、轨迹、围栏、电池、部分写回 |
| MQTT 远程控车 | ✅ 实验线已接 | 预连接 + 发令 + 状态回包（`OfficialMqttService`） |
| 本地 BLE | ✅ 实验线已接 | 协议 / 连接 / 扫描 / 爱车近场自动连（`lib/ble/`） |
| 通道路由 | ✅ 按官方表 | `OfficialControlRoute`：BLE / MQTT / 不可用 |
| 感应解锁 / OTA / NFC / 完整绑车 | ⏳ 未完成 | 完美复刻阶段 |
| 商城等运营 | ❌ 不做 | L3 |

能力与缺口明细见 **[FEATURES.md](FEATURES.md)**。

### 推荐使用路径（对齐官方）

```text
1. 短信登录官方账号
2. 同步并选中已绑定车辆
3. 打开「爱车」
4. 近场：有 btmac → 自动扫连；失败则顶栏「连接蓝牙」
5. 远程：不在身边时直接点设防/通电等 → MQTT（必要时 HTTP 兜底）
```

顶栏通道文案：`BLE 直连` · `MQTT 远程` · `MQTT 连接中` · `云端待命`。

---

## 工程结构

```text
lib/
  ble/          近场协议、AES、ConnectionManager、QGJ 帧
  services/     云 API、MQTT、通道路由、自动连、持久化、日志脱敏
  models/       车辆 / 电池 / 命令 / 坐标等
  pages/        爱车、定位、车库、消息、登录、扫描、设置…
  widgets/      AppPressable、StatusBadge、VehicleStage…
  theme/        Aurora 设计 token（禁止硬编码 Material 色）
test/           单元 / 组件测试
android|ios…    平台工程（含 BLE / 定位权限）
```

对照与逆向材料在工作区上级目录：

- `E:\ctf-aaa\tlddc\decompiled` — 官方反编译
- `E:\ctf-aaa\tlddc\台铃智能_*.apk` — 官方安装包样本
- `E:\ctf-aaa\tlddc\版本说明.md` — 与 `tailg-next` 的正式/测试分工

本仓 **不再维护 `docs/`**；说明以本 README、`FEATURES.md`、`AGENTS.md` 为准。

---

## 快速开始

```bash
flutter pub get
flutter doctor
flutter run                 # 调试；近场控车需真机蓝牙
flutter build apk --release # 发布包（需本地或 CI 签名）
```

### 质量门禁（与 CI 一致）

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-warnings --fatal-infos
flutter test --coverage
```

| 工作流 | 触发 | 行为 |
|--------|------|------|
| `build.yml` | PR / push `master`·`develop`，手动 | format → analyze → test →（push 时）签名 APK artifact |
| `release.yml` | `v*` tag，手动 | 门禁 → Release APK（可 Telegram 通知） |

密钥、`key.properties`、token、手机号、IMEI、抓包隐私数据 **禁止入库**。

### 地图（可选）

默认高德瓦片兜底。天地图：

```bash
flutter run --dart-define=TIANDITU_TOKEN=<token>
```

---

## 与 `tailg-next` 的关系

| | `tailg-ble-app`（本仓） | `tailg-next` |
|--|------------------------|--------------|
| 角色 | **测试 / 官方完全复刻实验** | **正式版**（工作区约定） |
| 侧重 | BLE + MQTT + 云，冲齐官方逻辑 | 当前以 cloud 产品线为主（以 next 仓文档为准） |
| App ID | `de.tttq.tailg_ble_app` | `com.ch6vip.tailg.next` |
| 安装 | 可与 next **并排安装**对照 | 同上 |

验证通过的复刻能力，再考虑合入或移植到正式线。

---

## 设计

**v8 Aurora Cockpit**：主色翡翠绿 `#00C896`，token 在 `lib/theme/`。触控目标 ≥ 44×44；颜色不作唯一信息载体。

---

## 许可证与免责

非官方、与台铃品牌方无关联。逆向所得协议与接口仅用于个人学习与自有车辆管理。使用风险自负。
