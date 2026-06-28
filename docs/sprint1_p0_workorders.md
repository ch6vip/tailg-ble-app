# Sprint 1 工单 — P0 热修（8 项）

> 每项工单可独立认领、独立 PR。优先级 P0-1 > P0-7/8 > P0-2 > P0-3/4 > P0-5/6。
> 建议分支命名：`fix/p0-{N}-{slug}`，例如 `fix/p0-1-disconnect-flag-reset`。
> 验收 Gate：`dart format --set-exit-if-changed .` + `flutter analyze` 0 warning + `flutter test` 全绿 + 真机回归 5 次无崩溃。

---

## P0-1 ｜ 断连标志 `_disconnectHandled` 重连后永不复位

| 字段 | 值 |
|------|-----|
| 严重度 | P0（生产致命） |
| 类型 | 状态机标志位复位缺陷 |
| 影响面 | BLE 连接链路；用户拔蓝牙后 App 假死 |
| 工作量 | 0.5 人日 |
| 依赖 | 无 |
| 风险 | 低 |
| 建议认领 | 熟悉 `connection_manager.dart` 的同学 |

### 根因

`_disconnectHandled`（声明于 `lib/ble/connection_manager.dart:69`）是 `_onDisconnected()` 的重入守卫：
- `_onDisconnected()` 行 740-741：`if (_disconnectHandled) return; _disconnectHandled = true;`
- 该标志只在 `connect()` 行 187 复位

但 `_attemptReconnect()` 成功路径（行 806-809）在回到 ready 后**没有复位** `_disconnectHandled`。结果：重连成功 → 用户再次拔蓝牙 → `_onDisconnected()` 行 740 直接 return → 不清理资源、不触发新一轮重连、UI 永远停留在 `reconnecting` 或 `ready` 假态。

### 修复 diff 草案

**文件**：`lib/ble/connection_manager.dart`

```diff
@@ _attemptReconnect() 成功路径（行 806 附近）@@
-        _reconnecting = false;
-        _reconnectAttempt = 0;
-        _log.ble('重连成功', level: LogLevel.info);
-        return;
+        _reconnecting = false;
+        _reconnectAttempt = 0;
+        _disconnectHandled = false; // P0-1: 复位守卫，确保二次断连能再次进入 _onDisconnected
+        _log.ble('重连成功', level: LogLevel.info);
+        return;
```

**附加收敛**（可选，推荐一起做，便于后续 S4 状态机形式化）：

```diff
@@ _onDisconnected()（行 738-741）@@
   Future<void> _onDisconnected() async {
     if (_disposed) return;
-    if (_disconnectHandled) return;
-    _disconnectHandled = true;
+    if (!_markDisconnectHandled()) return;
     _log.ble('设备断开连接', level: LogLevel.warning);
     ...

+  /// P0-1: 守卫逻辑收敛到单一入口，便于 S4 状态机改造时统一复位点。
+  bool _markDisconnectHandled() {
+    if (_disconnectHandled) return false;
+    _disconnectHandled = true;
+    return true;
+  }
```

### 验收测试

**新增文件**：`test/connection_manager_reconnect_test.dart`

```dart
test('重连成功后再次断连应触发 _onDisconnected', () async {
  // 1. mock 设备 → connect → ready
  // 2. 模拟断连 → 断言 stateStream 发出 reconnecting
  // 3. 模拟重连成功 → 断言 stateStream 发出 ready
  // 4. 再次模拟断连 → 断言 stateStream 再次发出 reconnecting（关键）
  // 5. 失败现状：第二次断连后 stateStream 不再变化（_onDisconnected 被 _disconnectHandled 拦截）
});
```

### 回滚

删除新增的 `_disconnectHandled = false;` 一行即可。`_markDisconnectHandled()` 收敛可单独保留或回滚。

---

## P0-2 ｜ 暗色主题被 `main.dart:228` 硬编码旁路

| 字段 | 值 |
|------|-----|
| 严重度 | P0（功能未启用） |
| 类型 | 配置缺陷 |
| 影响面 | 全 App 视觉；系统暗色模式下完全不响应 |
| 工作量 | 1 人日（含对比度回归） |
| 依赖 | 无 |
| 风险 | 中（散落硬编码色在暗色下对比度可能不足） |
| 建议认领 | 熟悉 `lib/theme/` 的同学 |

### 根因

`lib/theme/app_colors.dart` 已完整定义 `AppColorsDark`（行 223-283，28 个 token 全部实现）与 `AppColors.of(context)` 适配器（行 113-118），但 `lib/main.dart:228` 硬编码 `themeMode: ThemeMode.light`，导致：

1. `MaterialApp` 完全忽略系统暗色模式
2. `AppColorsDark.instance` 永远不会被 `AppColors.of()` 返回
3. 大量 widget 直接引用 `AppColors.xxx` 静态常量（如 `control_page.dart:39` `const _pageBg = AppColors.pageBg`），不经过 `AppColors.of(context)`，即便接线也不会切换

### 修复 diff 草案

**文件 1**：`lib/main.dart`

```diff
@@ MaterialApp 构造（行 227-228 附近）@@
       ),
-      themeMode: ThemeMode.light,
+      themeMode: ThemeMode.system,
+      darkTheme: ThemeData(
+        brightness: Brightness.dark,
+        colorScheme: ColorScheme.fromSeed(
+          seedColor: AppColors.primary,
+          brightness: Brightness.dark,
+        ),
+        useMaterial3: true,
+        scaffoldBackgroundColor: AppColorsDark.instance.pageBg,
+        cardColor: AppColorsDark.instance.surface,
+        // 其余 dark token 在 Sprint 3 通过 ThemeExtension<AppTokens> 注入
+      ),
       localizationsDelegates: const [
```

**文件 2**（最小改动，让最常被引用的几个 token 立即响应）：`lib/pages/control_page.dart:39`

```diff
-const _pageBg = AppColors.pageBg;
+// P0-2: 改为运行时读取，让暗色模式生效。Sprint 3 Token 体系重建后改用 ThemeExtension。
+Color _pageBg(BuildContext context) => AppColors.of(context).pageBg;
```

调用处 `backgroundColor: _pageBg` → `backgroundColor: _pageBg(context)`。

> ⚠️ Sprint 1 只做最小接线（main.dart + control_page 的 pageBg）。全量替换 50+ 硬编码色留到 Sprint 3 Token 重建。本工单的验收以"系统切暗色 → 页面背景、卡片、文字颜色明显变化"为准，不要求所有 token 完美适配。

### 验收测试

**新增文件**：`test/theme_test.dart`

```dart
testWidgets('系统暗色模式下 App 使用 AppColorsDark', (tester) async {
  await tester.pumpWidget(MaterialApp(
    themeMode: ThemeMode.dark,
    darkTheme: ThemeData(brightness: Brightness.dark),
    home: Builder(builder: (ctx) {
      final brightness = Theme.of(ctx).brightness;
      return Text(brightness == Brightness.dark ? 'DARK' : 'LIGHT');
    }),
  ));
  expect(find.text('DARK'), findsOneWidget);
});
```

### 回滚

`themeMode` 改回 `ThemeMode.light`，删除 `darkTheme:` 参数。

---

## P0-3 ｜ `_HomeBody` dispose 竞态

| 字段 | 值 |
|------|-----|
| 严重度 | P0（间歇性崩溃） |
| 类型 | 异步生命周期竞态 |
| 影响面 | 首页 tab 切换；偶发 `StateError` |
| 工作量 | 0.5 人日 |
| 依赖 | 无 |
| 风险 | 低 |
| 建议认领 | 任意同学 |

### 根因

`lib/pages/control_page.dart:171-176`：

```dart
@override
void dispose() {
  _cancelSubscriptions();   // 返回 Future<void>，但未 await
  _controller?.close();     // 立即执行，触发 controller.onCancel
  super.dispose();
}
```

`_cancelSubscriptions()` 是 `async`（行 162），返回 Future 但 `dispose` 是 `void` 无法 await。`_controller?.close()` 可能在订阅取消完成前执行，触发 `controller.onCancel = _cancelSubscriptions`（行 157）再次进入竞态；同时 `_subConn?.cancel()` 触发的 `onCancel` 回调可能向已关闭的 controller 发射数据。

### 修复 diff 草案

**文件**：`lib/pages/control_page.dart`

```diff
@@ _HomeBodyState（行 115 附近）@@
 class _HomeBodyState extends State<_HomeBody> {
   late final Stream<List<dynamic>> _combinedStream;
   StreamSubscription<dynamic>? _subConn;
   StreamSubscription<dynamic>? _subVehicles;
   StreamSubscription<dynamic>? _subCloud;
   StreamController<List<dynamic>>? _controller;
+  bool _disposed = false; // P0-3: dispose 竞态保护

@@ _createCombinedStream emit()（行 134-138）@@
     void emit() {
-      if (!controller.isClosed) {
+      if (_disposed || controller.isClosed) {
         controller.add([latestConn, latestVehicles, latestCloud]);
       }
     }

@@ 监听回调（行 143-154）@@
     _subConn = connectionManager.stateStream.listen((s) {
+      if (_disposed) return;
       latestConn = s;
       emit();
     });
     _subVehicles = vehicleStore.vehiclesStream.listen((v) {
+      if (_disposed) return;
       latestVehicles = v;
       emit();
     });
     _subCloud = officialCloudService.stateStream.listen((c) {
+      if (_disposed) return;
       latestCloud = c;
       emit();
     });

@@ dispose（行 162-176）@@
-  Future<void> _cancelSubscriptions() async {
-    await _subConn?.cancel();
-    await _subVehicles?.cancel();
-    await _subCloud?.cancel();
-    _subConn = null;
-    _subVehicles = null;
-    _subCloud = null;
-  }
-
   @override
   void dispose() {
-    _cancelSubscriptions();
+    _disposed = true; // P0-3: 先置标志，再同步取消，防止 onCancel 回调向已关闭的 controller 发射
+    _subConn?.cancel();
+    _subVehicles?.cancel();
+    _subCloud?.cancel();
+    _subConn = null;
+    _subVehicles = null;
+    _subCloud = null;
     _controller?.close();
     super.dispose();
   }
```

> 说明：`StreamSubscription.cancel()` 在 Dart 中是同步的（即使返回 Future，订阅立即停止接收事件），所以同步取消足够。返回的 Future 仅用于等待底层资源释放，`dispose` 内可安全忽略。

### 验收测试

```dart
testWidgets('快速切 tab 不抛 StateError', (tester) async {
  for (int i = 0; i < 20; i++) {
    await tester.pumpWidget(const MaterialApp(home: _HomeBody()));
    await tester.pump();
    await tester.pumpWidget(const SizedBox()); // 触发 dispose
    await tester.pump();
  }
  // 失败现状：偶发 "Stream has been listened to" 或 controller 向已关闭流发射
});
```

### 回滚

恢复原 `_cancelSubscriptions()` async 方法与原 `dispose`。

---

## P0-4 ｜ 单 `StreamBuilder` 触发整页重建

| 字段 | 值 |
|------|-----|
| 严重度 | P0（性能） |
| 类型 | 重建范围失控 |
| 影响面 | 首页帧率；低端设备卡顿 |
| 工作量 | 1.5 人日 |
| 依赖 | 建议在 P0-3 之后做 |
| 风险 | 中（需保证三流初值同步） |
| 建议认领 | 熟悉 StreamBuilder 重建机制的同学 |

### 根因

`lib/pages/control_page.dart:180-241`：单个 `StreamBuilder<List<dynamic>>` 同时订阅三流（connectionManager.state / vehicleStore.vehicles / officialCloudService.state），任一流变化都重建整个 `Column`（含 `_HomeTopSection`、`_HomeQuickSection`、`_RidingModeSelector` 全部子树）。

`_RidingModeSelector` 只依赖 `connState`，但车辆流或云态流变化时也会被重建。`_HomeQuickSection` 是 `const`，问题相对小；但 `_HomeTopSection` 含复杂卡片，重建成本高。

### 修复 diff 草案

**文件**：`lib/pages/control_page.dart`

**思路**：移除手写 `_createCombinedStream` 与 `_combinedStream` 字段，改为三个独立 `StreamBuilder`，各订阅各的流。外层 `AnimatedSwitcher` 只依赖 `showUnboundHome` 派生的 `ValueNotifier<bool>`。

```diff
@@ _HomeBodyState 字段（行 115-120）@@
 class _HomeBodyState extends State<_HomeBody> {
-  late final Stream<List<dynamic>> _combinedStream;
-  StreamSubscription<dynamic>? _subConn;
-  StreamSubscription<dynamic>? _subVehicles;
-  StreamSubscription<dynamic>? _subCloud;
-  StreamController<List<dynamic>>? _controller;
+  // P0-4: 改为 ValueNotifier 驱动 showUnboundHome，三个子区域各自 StreamBuilder
+  late final ValueNotifier<bool> _showUnboundHome;

@@ initState（行 122-126）@@
   @override
   void initState() {
     super.initState();
-    _combinedStream = _createCombinedStream();
+    _showUnboundHome = ValueNotifier<bool>(_computeShowUnboundHome());
+    _showUnboundHome.addListener(() { if (mounted) setState(() {}); });
+    // 订阅三流，仅用于刷新 _showUnboundHome 派生值
+    connectionManager.stateStream.listen((_) => _updateShowUnboundHome());
+    vehicleStore.vehiclesStream.listen((_) => _updateShowUnboundHome());
+    officialCloudService.stateStream.listen((_) => _updateShowUnboundHome());
   }

+  bool _computeShowUnboundHome() {
+    final hasLocalVehicle =
+        vehicleStore.vehicles.isNotEmpty || vehicleStore.defaultVehicle != null;
+    final cloudState = officialCloudService.state;
+    final hasCloudVehicle =
+        cloudState.signedIn && cloudState.selectedVehicle != null;
+    final hasTransientDevice =
+        connectionManager.device != null ||
+        connectionManager.state != ble.ConnectionState.disconnected;
+    return !hasLocalVehicle && !hasCloudVehicle && !hasTransientDevice;
+  }
+
+  void _updateShowUnboundHome() {
+    if (_disposed) return; // P0-3 保护
+    final next = _computeShowUnboundHome();
+    if (_showUnboundHome.value != next) _showUnboundHome.value = next;
+  }

@@ build（行 178-241）@@
   @override
   Widget build(BuildContext context) {
-    return StreamBuilder<List<dynamic>>(
-      stream: _combinedStream,
-      builder: (context, snapshot) {
-        if (!snapshot.hasData) return const SizedBox.shrink();
-        final connState = snapshot.data![0] as ble.ConnectionState;
-        ...
-        return AnimatedSwitcher(
-          ...
-          child: showUnboundHome
-              ? _UnboundVehicleHome(connectionLost: connectionLostHint)
-              : Column(
-                  children: [
-                    _HomeTopSection(connState: connState),
-                    const _HomeQuickSection(),
-                    _RidingModeSelector(connState: connState),
-                  ],
-                ),
-        );
-      },
-    );
+    return AnimatedSwitcher(
+      duration: const Duration(milliseconds: 260),
+      switchInCurve: Curves.easeOutCubic,
+      switchOutCurve: Curves.easeInCubic,
+      transitionBuilder: (child, animation) {
+        final curved = CurvedAnimation(
+          parent: animation,
+          curve: Curves.easeOutCubic,
+          reverseCurve: Curves.easeInCubic,
+        );
+        return FadeTransition(
+          opacity: curved,
+          child: SlideTransition(
+            position: Tween<Offset>(
+              begin: const Offset(0, 0.018),
+              end: Offset.zero,
+            ).animate(curved),
+            child: child,
+          ),
+        );
+      },
+      child: _showUnboundHome.value
+          ? _UnboundVehicleHome(
+              connectionLost: connectionManager.device != null &&
+                  vehicleStore.vehicles.isEmpty &&
+                  !officialCloudService.state.signedIn,
+            )
+          : Column(
+              key: const ValueKey('bound-home'),
+              crossAxisAlignment: CrossAxisAlignment.start,
+              children: [
+                // P0-4: 三流各自独立 StreamBuilder，互不干扰
+                StreamBuilder<ble.ConnectionState>(
+                  stream: connectionManager.stateStream,
+                  initialData: connectionManager.state,
+                  builder: (context, snap) =>
+                      _HomeTopSection(connState: snap.data!),
+                ),
+                const SizedBox(height: 14),
+                const _HomeQuickSection(),
+                const SizedBox(height: 14),
+                StreamBuilder<ble.ConnectionState>(
+                  stream: connectionManager.stateStream,
+                  initialData: connectionManager.state,
+                  builder: (context, snap) =>
+                      _RidingModeSelector(connState: snap.data!),
+                ),
+                const SizedBox(height: 20),
+              ],
+            ),
+    );
   }
```

### 验收测试

```dart
testWidgets('仅 connState 变化时 _RidingModeSelector 重建', (tester) async {
  debugRepaintRainbowEnabled = true;
  await tester.pumpWidget(const MaterialApp(home: _HomeBody()));
  // 触发 vehicleStore.vehiclesStream 发射
  // 断言 _RidingModeSelector 子树未被重绘（通过 RepaintBoundary 计数或 Key 验证）
  debugRepaintRainbowEnabled = false;
});
```

### 回滚

恢复单 `StreamBuilder` + `_combinedStream`。

---

## P0-5 ｜ `location_page` 空 `setState` 重建含 `flutter_map` 整页

| 字段 | 值 |
|------|-----|
| 严重度 | P0（性能） |
| 类型 | 重建范围失控 |
| 影响面 | 定位页帧率；地图拖动卡顿 |
| 工作量 | 1 人日 |
| 依赖 | 无 |
| 风险 | 低 |
| 建议认领 | 任意同学 |

### 根因

`lib/pages/location_page.dart` 多处：

1. **行 63-66**：`VehicleStore()` 直接构造（绕过 service_locator，见 P0-6），订阅 `vehiclesStream` 后 `setState(() {})` 空调用 → 整页 rebuild，含 `FlutterMap`（行 513）。
2. **行 68-71**：同理，`OfficialCloudService()` 订阅后空 `setState`。
3. **行 286-379** `build()` 方法内直接调用 `OfficialCloudService().state`、`VehicleStore().defaultVehicle`，每次 rebuild 都重新解析。

`FlutterMap` 重建成本极高（重算 `MapOptions`、重渲 `TileLayer`/`MarkerLayer`），空 `setState` 导致地图拖动时帧率骤降。

### 修复 diff 草案

**文件**：`lib/pages/location_page.dart`

```diff
@@ _LocationPageState 字段（行 48-56）@@
 class _LocationPageState extends State<LocationPage> {
   late int _tabIndex;
   bool _localLoading = false;
   String? _localError;
   FenceConfig? _localFence;
+  // P0-5: 用 ValueNotifier 驱动需要刷新的最小子树，避免重建 FlutterMap
+  late final ValueNotifier<OfficialCloudState> _cloudState;
+  late final ValueNotifier<List<VehicleProfile>> _vehicles;

@@ initState（行 57-76）@@
   @override
   void initState() {
     super.initState();
     _tabIndex = widget.initialTab.index;
     _loadLocalFence();
 
-    final vehicleStore = VehicleStore();
-    _vehiclesSub = vehicleStore.vehiclesStream.listen((_) {
-      if (mounted) setState(() {});
-    });
-
-    final cloudService = OfficialCloudService();
-    _cloudStateSub = cloudService.stateStream.listen((_) {
-      if (mounted) setState(() {});
-    });
+    _cloudState = ValueNotifier(officialCloudService.state);
+    _vehicles = ValueNotifier(vehicleStore.vehicles);
+    _vehiclesSub = vehicleStore.vehiclesStream.listen((v) {
+      if (mounted) _vehicles.value = v; // 仅刷新 ValueNotifier，不 setState
+    });
+    _cloudStateSub = officialCloudService.stateStream.listen((c) {
+      if (mounted) _cloudState.value = c;
+    });

     WidgetsBinding.instance.addPostFrameCallback((_) {
       _refreshOfficial(silent: true);
     });
   }

@@ build（行 286-379）@@
   @override
   Widget build(BuildContext context) {
     final title = switch (_tabIndex) { ... };
     return Scaffold(
       backgroundColor: AppColors.pageBg,
       body: SafeArea(
-        child: Builder(
-          builder: (context) {
-            final cloudState = OfficialCloudService().state;
-            final localVehicle = VehicleStore().defaultVehicle;
-            ...
-            return Column(
-              children: [
-                if (_tabIndex != LocationInitialTab.fence.index)
-                  AppPageHeader(...),
-                ...
-                Expanded(
-                  child: IndexedStack(
-                    index: _tabIndex,
-                    children: [
-                      _MapTab(...), // 内含 FlutterMap
-                      ...
-                    ],
-                  ),
-                ),
-              ],
-            );
-          },
-        ),
+        child: ValueListenableBuilder<List<VehicleProfile>>(
+          valueListenable: _vehicles,
+          builder: (_, vehicles, __) =>
+            ValueListenableBuilder<OfficialCloudState>(
+              valueListenable: _cloudState,
+              builder: (_, cloudState, __) {
+                final localVehicle = vehicleStore.defaultVehicle;
+                // ... 原有逻辑
+                return Column(...);
+              },
+            ),
+        ),
       ),
     );
   }
```

> 补充：将 `_MapTab` 外包 `RepaintBoundary`，使地图层在父级 rebuild 时不被重绘：
> ```dart
> RepaintBoundary(child: _MapTab(...))
> ```

### 验收测试

```dart
testWidgets('车辆流变化时不重建 FlutterMap', (tester) async {
  debugRepaintRainbowEnabled = true;
  await tester.pumpWidget(const MaterialApp(home: LocationPage()));
  final mapKey = const Key('flutter-map');
  // 触发 vehicleStore.vehiclesStream 发射
  await tester.pump();
  // 断言 FlutterMap 子树未被重绘
  debugRepaintRainbowEnabled = false;
});
```

### 回滚

恢复原 `setState(() {})` 与 `Builder`。

---

## P0-6 ｜ 绕过 `service_locator` 单例（17 处直接构造）

| 字段 | 值 |
|------|-----|
| 严重度 | P0（架构一致性） |
| 类型 | 依赖注入绕过 |
| 影响面 | 测试无法 mock；多实例风险 |
| 工作量 | 1 人日 |
| 依赖 | 无 |
| 风险 | 低 |
| 建议认领 | 任意同学（机械替换） |

### 根因

`lib/main.dart:28-39` 已定义顶层 getter 委托 `AppServices.instance`，但 `lib/pages/` 下 17 处直接 `XxxService()` 构造，绕过了 `service_locator`。后果：

1. 测试时 `AppServices.override` 无法替换这些调用点的依赖
2. 若 service 内部有副作用（如 `OfficialCloudService()` 的构造可能触发 init），多次构造产生多实例风险
3. `LocationService()`、`LogService()`、`AppPreferencesService()`、`AutoConnectService()`、`ProximityService()` 均存在此问题

### 调用点清单（已 Grep 验证）

| 文件 | 行号 | 调用 |
|------|------|------|
| `lib/pages/diagnostic_page.dart` | 79 | `final _log = LogService();` |
| `lib/pages/vehicle_message_page.dart` | 21 | `final _log = LogService();` |
| `lib/pages/official_replica_pages.dart` | 595 | `final logs = LogService()` |
| `lib/pages/official_replica_pages.dart` | 609 | `final cloudState = OfficialCloudService().state;` |
| `lib/pages/location_page.dart` | 63 | `final vehicleStore = VehicleStore();` |
| `lib/pages/location_page.dart` | 68 | `final cloudService = OfficialCloudService();` |
| `lib/pages/location_page.dart` | 117 | `final service = OfficialCloudService();` |
| `lib/pages/location_page.dart` | 142 | `await OfficialCloudService().refreshTravelHistory(...)` |
| `lib/pages/location_page.dart` | 154 | `final state = OfficialCloudService().state;` |
| `lib/pages/location_page.dart` | 201-202 | `OfficialCloudService().state...refreshTravelDetail(...)` |
| `lib/pages/location_page.dart` | 298 | `final cloudState = OfficialCloudService().state;` |
| `lib/pages/location_page.dart` | 299 | `final localVehicle = VehicleStore().defaultVehicle;` |
| `lib/pages/app_preferences_pages.dart` | 27, 120, 191 | `AppPreferencesService()` / `LogService()` |
| `lib/pages/log_page.dart` | 20 | `final _log = LogService();` |
| `lib/pages/settings_page.dart` | 295, 318, 341, 366, 392 | `AutoConnectService()` / `ProximityService()` / `AppPreferencesService()` |

### 修复 diff 草案

**模式**：所有 `XxxService()` → `xxxService`（顶层 getter）。`main.dart` 已 import 这些 getter，但 pages 需补 import。

**示例**：`lib/pages/location_page.dart`

```diff
@@ 顶部 import（行 1-22）@@
 import '../services/official_cloud_service.dart';
 import '../services/replica_feature_store.dart';
 import '../services/vehicle_store.dart';
+import '../main.dart' show vehicleStore, officialCloudService, logService; // P0-6

@@ 行 63 @@
-    final vehicleStore = VehicleStore();
-    _vehiclesSub = vehicleStore.vehiclesStream.listen((_) {
+    // P0-6: 改用 service_locator getter
+    _vehiclesSub = vehicleStore.vehiclesStream.listen((_) {
       if (mounted) setState(() {});
     });

@@ 行 68 @@
-    final cloudService = OfficialCloudService();
-    _cloudStateSub = cloudService.stateStream.listen((_) {
+    _cloudStateSub = officialCloudService.stateStream.listen((_) {

@@ 行 117 @@
-    final service = OfficialCloudService();
-    if (!service.state.signedIn) return;
+    if (!officialCloudService.state.signedIn) return;
     try {
-      await service.refreshVehicles(...);
-      await Future.wait([service.refreshVehicleLocation(...), ...]);
+      await officialCloudService.refreshVehicles(...);
+      await Future.wait([officialCloudService.refreshVehicleLocation(...), ...]);
```

> ⚠️ 注意 `lib/main.dart:71` `await AppPreferencesService().init()` 也是直接构造，应改为 `await appPreferencesService.init()`（但 `appPreferencesService` getter 未在 main.dart 定义，需新增）。

### 验收测试

```bash
# 验收脚本：搜索 lib/pages 内剩余的直接构造应为 0
grep -rnE '\b(LogService|OfficialCloudService|VehicleStore|LocationService|AutoConnectService|ProximityService|AppPreferencesService)\(\)' lib/pages lib/widgets
```

### 回滚

逐文件恢复直接构造。

---

## P0-7 ｜ `AGENTS.md` 虚构 `ci.yml`

| 字段 | 值 |
|------|-----|
| 严重度 | P0（文档可信度） |
| 类型 | 文档与代码背离 |
| 影响面 | AI 助手与新人 onboarding 误导 |
| 工作量 | 0.5 人日 |
| 依赖 | 无 |
| 风险 | 无（纯文档） |
| 建议认领 | 任意同学 |

### 根因

`AGENTS.md:32-46` 描述三工作流：

| File | Purpose | Trigger |
|------|---------|---------|
| `ci.yml` | Full CI/CD (format → analyze → test+coverage → build → deploy → notify) | push/PR to master/develop, v* tags, manual |
| `release.yml` | Standalone GitHub Release creation | v* tags, manual |
| `build.yml` | Legacy build workflow (kept for compatibility) | push/PR to master, tags |

**实际验证**（`ls .github/workflows/`）：只有 `build.yml` 和 `release.yml`，**`ci.yml` 不存在**。

`build.yml` 实际包含 `ci` → `build` → `release` 三个 job（行 24-127），并非"legacy"。`release.yml` 是独立的 build+release 流程，并非"standalone release creation"。

### 修复 diff 草案

**文件**：`AGENTS.md`

```diff
 ## CI/CD Pipeline
 
 Workflows live in `.github/workflows/`:
 
 | File | Purpose | Trigger |
 |------|---------|---------|
-| `ci.yml` | Full CI/CD (format → analyze → test+coverage → build → deploy → notify) | push/PR to `master`/`develop`, `v*` tags, manual |
-| `release.yml` | Standalone GitHub Release creation | `v*` tags, manual |
-| `build.yml` | Legacy build workflow (kept for compatibility) | push/PR to `master`, tags |
+| `build.yml` | Main CI/CD: `ci` (format → analyze → test) → `build` (signed APK) → `release` (GitHub Release) | push to `master`, `v*` tags, PR to `master`, manual |
+| `release.yml` | Standalone build & release with rich release notes and Telegram notification | `v*` tags, manual |
+
+> ⚠️ **P0-8 已知问题**：`build.yml` 和 `release.yml` 都在 `v*` tag 触发并创建 GitHub Release，会产生重复 Release。修复方案见 Sprint 1 P0-8。
 
-**Quality gates** enforced on every PR: `dart format`, `flutter analyze`, `flutter test --coverage`. Coverage reports are uploaded to Codecov.
+**Quality gates** enforced on every PR via `build.yml` ci job: `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`. Coverage reports are **not** currently uploaded (planned in Sprint 2 P1-17).
 
-**Build strategy**: `develop` → debug APK; `master` → signed release APK (arm64); `v*` tags → GitHub Release with APK artifact. Release signing keys are injected via GitHub Secrets at build time — never committed to the repo.
+**Build strategy**: `master` push → signed release APK (arm64); `v*` tags → GitHub Release with APK artifact. `develop` branch currently has no special build strategy. Release signing keys are injected via GitHub Secrets at build time — never committed to the repo.
```

### 验收

```bash
grep -c 'ci.yml' AGENTS.md  # 应为 0
ls .github/workflows/       # 应只有 build.yml 和 release.yml
```

### 回滚

`git checkout AGENTS.md`。

---

## P0-8 ｜ `build.yml` 与 `release.yml` 双 Release 并发

| 字段 | 值 |
|------|-----|
| 严重度 | P0（发版可靠性） |
| 类型 | CI 触发条件冲突 |
| 影响面 | 推 `v*` tag 产生重复/竞争 GitHub Release |
| 工作量 | 1 人日（含测试 tag 推送） |
| 依赖 | 无 |
| 风险 | 中（需测试 tag 推送验证） |
| 建议认领 | 熟悉 GitHub Actions 的同学 |

### 根因

- `build.yml:4-6`：`on: push: branches: [master], tags: ['v*']`，`release` job（行 111-127）在 `startsWith(github.ref, 'refs/tags/v')` 时用 `softprops/action-gh-release@v2` 创建 Release。
- `release.yml:9-12`：`on: push: tags: ['v*']`，同样用 `softprops/action-gh-release@v2` 创建 Release。

推 `v*` tag → 两个工作流并发触发 → 两个 `softprops/action-gh-release` 竞争创建同一 tag 的 Release → 产生重复 Release 或其中一方失败。

### 修复方案（推荐 A：build.yml 移除 tag 触发，release.yml 作为唯一 tag 发布流）

**文件 1**：`.github/workflows/build.yml`

```diff
@@ on 触发（行 3-9）@@
 on:
   push:
-    branches: [master]
-    tags: ['v*']
+    branches: [master, develop]  # P0-8: 移除 tags 触发，避免与 release.yml 双 Release
   pull_request:
-    branches: [master]
+    branches: [master, develop]
   workflow_dispatch:
```

同时**删除 build.yml 的 release job**（行 111-127），让 release.yml 独占 Release 创建：

```diff
@@ 删除 release job（行 111-127）@@
-  release:
-    runs-on: ubuntu-latest
-    needs: build
-    if: startsWith(github.ref, 'refs/tags/v')
-    permissions:
-      contents: write
-    steps:
-      - uses: actions/download-artifact@v4
-        with:
-          name: tailg-ble-${{ github.ref_name }}-${{ github.sha }}
-          path: release-artifacts
-
-      - name: Create Release
-        uses: softprops/action-gh-release@v2
-        with:
-          files: release-artifacts/*
-          generate_release_notes: true
```

**文件 2**：`.github/workflows/release.yml`

补全 CI 门禁（当前 release.yml 跳过 `flutter analyze` / `flutter test`，对应 P1-16，但 P0-8 修复时应一并补上以保证发版质量）：

```diff
@@ release job（行 36 附近，在 build 步骤前插入 ci 步骤）@@
   release:
     name: 'Build & Publish Release'
     runs-on: ubuntu-latest
     timeout-minutes: 45
     steps:
       - uses: actions/checkout@v4
         with:
           ref: ${{ github.event.inputs.tag || github.ref }}

       - name: Setup Flutter ${{ env.FLUTTER_VERSION }}
         uses: subosito/flutter-action@v2
         with:
           flutter-version: ${{ env.FLUTTER_VERSION }}
           channel: stable
           cache: true

+      # P0-8/P1-16: 发版前必须通过 CI 门禁
+      - name: Check formatting
+        run: dart format --output=none --set-exit-if-changed .
+
+      - name: Analyze
+        run: flutter analyze
+
+      - name: Test
+        run: flutter test
+
       - name: Cache Gradle
```

### 验收

1. 在 `develop` 分支推 `v0.0.0-test` tag
2. 检查 GitHub Actions：应只触发 `release.yml`，不触发 `build.yml`
3. 检查 Releases 页面：应只有 1 个 `v0.0.0-test` Release
4. 删除测试 tag 与 Release

### 回滚

`build.yml` 恢复 `tags: ['v*']` 触发与 release job；`release.yml` 移除新增的 ci 步骤。

---

## 依赖关系图

```
P0-7 (文档)  ──┐
P0-8 (CI)    ──┤  无依赖，可并行
P0-1 (BLE)   ──┤
P0-2 (暗色)  ──┤
P0-6 (DI)    ──┘

P0-3 (dispose) ──→ P0-4 (StreamBuilder 拆分)  // P0-4 的 ValueNotifier 需要 _disposed 保护
P0-5 (location)  ──→ P0-6 (location_page 内 5 处直接构造，建议一起改)
```

**建议执行顺序**：
1. **第 1 天**：P0-7（文档）+ P0-8（CI）+ P0-1（BLE）—— 三个独立分支并行
2. **第 2 天**：P0-2（暗色）+ P0-6（DI 全局替换）
3. **第 3 天**：P0-3（dispose）→ P0-4（StreamBuilder）
4. **第 4 天**：P0-5（location_page，含 P0-6 的 location_page 部分）
5. **第 5 天**：回归测试 + PR 合并

---

## Sprint 1 验收 Gate

- [ ] `dart format --output=none --set-exit-if-changed .` 通过
- [ ] `flutter analyze` 0 warning
- [ ] `flutter test` 全绿，新增 4 个测试文件（P0-1/P0-2/P0-3/P0-4 各一）
- [ ] 真机 BLE 回归：连接 → 断连 → 重连成功 → 再次断连 → 重连，5 次无崩溃
- [ ] 系统切暗色模式，App 视觉明显变化（不要求所有 token 完美）
- [ ] 推 `v0.0.0-test` tag，只产生 1 个 GitHub Release
- [ ] `grep -rnE '\b\w*Service\(\)' lib/pages lib/widgets` 输出为空
