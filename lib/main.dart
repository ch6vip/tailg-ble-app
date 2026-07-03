import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'ble/connection_manager.dart' as ble;
import 'models/vehicle_profile.dart';
import 'services/proximity_service.dart';
import 'services/auto_connect_service.dart';
import 'services/manual_mode_service.dart';
import 'services/location_service.dart';
import 'services/log_service.dart';
import 'services/official_cloud_service.dart';
import 'services/permission_service.dart';
import 'services/vehicle_store.dart';
import 'services/service_locator.dart';
import 'services/app_preferences_service.dart';
import 'pages/scan_page.dart';
import 'pages/control_page.dart';
import 'pages/location_page.dart';
import 'pages/garage_page.dart';
import 'pages/profile_page.dart';
import 'theme/app_colors.dart';
import 'widgets/app_toast.dart';

// App-wide services now live in the [AppServices] container (see
// service_locator.dart). These top-level getters preserve the existing call
// sites while routing every lookup through the single injectable graph, so
// tests can override the whole set via [AppServices.override].
ble.ConnectionManager get connectionManager =>
    AppServices.instance.connectionManager;
ProximityService get proximityService => AppServices.instance.proximityService;
AutoConnectService get autoConnectService =>
    AppServices.instance.autoConnectService;
ManualModeService get manualModeService =>
    AppServices.instance.manualModeService;
LocationService get locationService => AppServices.instance.locationService;
LogService get logService => AppServices.instance.logService;
VehicleStore get vehicleStore => AppServices.instance.vehicleStore;
OfficialCloudService get officialCloudService =>
    AppServices.instance.officialCloudService;
AppPreferencesService get appPreferencesService =>
    AppServices.instance.appPreferencesService; // P0-6
AppPermissionService get permissionService =>
    AppServices.instance.permissionService;

/// App-wide home tab index, owned by [AppServices] so tests can swap the whole
/// service graph without leaving a separate mutable singleton behind.
ValueNotifier<int> get homeTabIndex => AppServices.instance.homeTabIndex;

void applyVehicleBleCredentials(VehicleProfile? vehicle) {
  connectionManager.setQgjCredentials(
    password: vehicle?.qgjLoginPassword,
    userId: vehicle?.qgjUserId,
  );
}

VehicleProtocol vehicleProtocolFromBle(ble.ProtocolType protocol) {
  return switch (protocol) {
    ble.ProtocolType.standard => VehicleProtocol.standard,
    ble.ProtocolType.qgj => VehicleProtocol.qgj,
    ble.ProtocolType.unknown => VehicleProtocol.auto,
  };
}

void openScanTab(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const ScanPage()));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await appPreferencesService.init(); // P0-6
    await vehicleStore.init();
    await officialCloudService.init();
    final defaultVehicle = vehicleStore.defaultVehicle;
    if (defaultVehicle != null) {
      applyVehicleBleCredentials(defaultVehicle);
      proximityService.setTargetDevice(defaultVehicle.id);
    }
    await proximityService.init(connectionManager);
    await autoConnectService.init(connectionManager);
    await manualModeService.init();
  } catch (e, st) {
    debugPrint('Startup initialization failed: $e\n$st');
    runApp(StartupErrorApp(error: e, stackTrace: st));
    return;
  }

  runApp(const TailgBleApp());
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({
    super.key,
    required this.error,
    required this.stackTrace,
  });

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tailg BLE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.danger),
        scaffoldBackgroundColor: AppColors.pageBg,
        useMaterial3: true,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(shape: _buttonShape),
        ),
      ),
      home: _StartupErrorView(error: error, stackTrace: stackTrace),
    );
  }
}

class _StartupErrorView extends StatelessWidget {
  const _StartupErrorView({required this.error, required this.stackTrace});

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    final details = '$error\n\n$stackTrace';
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            color: AppColors.danger,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          '启动失败',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '应用初始化失败，请重启应用或查看日志。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: SelectableText(
                              details,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 全 App 统一的按钮圆角矩形形状（替代 Material3 默认胶囊形）。
const _buttonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
);

/// 统一的页面转场：新页面淡入并轻微上滑，呼应 App 内列表/卡片的入场动画。
class _FadeUpPageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeUpPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class TailgBleApp extends StatefulWidget {
  const TailgBleApp({super.key});

  @override
  State<TailgBleApp> createState() => _TailgBleAppState();
}

class _TailgBleAppState extends State<TailgBleApp> {
  final _preferences = appPreferencesService; // P0-6
  bool _respectTextScale = true;
  StreamSubscription<bool>? _textScaleSub;

  @override
  void initState() {
    super.initState();
    _respectTextScale = _preferences.respectSystemTextScale;
    _textScaleSub = _preferences.respectTextScaleStream.listen((value) {
      if (mounted) setState(() => _respectTextScale = value);
    });
  }

  @override
  void dispose() {
    _textScaleSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tailg BLE',
      navigatorKey: AppToast.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.light,
            ).copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              secondary: AppColors.accentTeal,
              onSecondary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
              surfaceContainerLow: AppColors.surfaceContainerLow,
              surfaceContainerHigh: AppColors.surfaceContainerHigh,
              outline: AppColors.border,
              outlineVariant: AppColors.outlineVariant,
            ),
        scaffoldBackgroundColor: AppColors.pageBg,
        useMaterial3: true,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(shape: _buttonShape),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(shape: _buttonShape),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(shape: _buttonShape),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(shape: _buttonShape),
        ),
        // M3 Card theme: elevated surface, no border
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        // M3 Switch with teal accent
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return Colors.white;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.accentTeal;
            }
            return AppColors.border;
          }),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
        // M3 SnackBar
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _FadeUpPageTransitionsBuilder(),
            TargetPlatform.iOS: _FadeUpPageTransitionsBuilder(),
            TargetPlatform.fuchsia: _FadeUpPageTransitionsBuilder(),
          },
        ),
      ),
      // P0-2: 接线暗色主题。AppColorsDark 已完整定义（app_colors.dart:223-283）
      // 但此前被 ThemeMode.light 硬编码旁路。现改为跟随系统。
      // Sprint 3 Token 重建后通过 ThemeExtension<AppTokens> 统一注入。
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.dark,
            ).copyWith(
              primary: AppColorsDark.instance.primary,
              onPrimary: Colors.black,
              secondary: AppColorsDark.instance.accentSky,
              onSecondary: Colors.black,
              surface: AppColorsDark.instance.surface,
              onSurface: AppColorsDark.instance.textPrimary,
              surfaceContainerLow: AppColorsDark.instance.surfaceContainerLow,
              surfaceContainerHigh: AppColorsDark.instance.surfaceContainerHigh,
              outline: AppColorsDark.instance.border,
              outlineVariant: AppColorsDark.instance.outlineVariant,
            ),
        scaffoldBackgroundColor: AppColorsDark.instance.pageBg,
        useMaterial3: true,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(shape: _buttonShape),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(shape: _buttonShape),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(shape: _buttonShape),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(shape: _buttonShape),
        ),
        cardTheme: CardThemeData(
          color: AppColorsDark.instance.surface,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.all(Colors.white),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColorsDark.instance.primary;
            }
            return AppColorsDark.instance.border;
          }),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _FadeUpPageTransitionsBuilder(),
            TargetPlatform.iOS: _FadeUpPageTransitionsBuilder(),
            TargetPlatform.fuchsia: _FadeUpPageTransitionsBuilder(),
          },
        ),
      ),
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      home: const HomePage(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            boldText: false,
            textScaler: _respectTextScale
                ? TextScaler.linear(
                    MediaQuery.textScalerOf(context).scale(1.0).clamp(0.9, 1.3),
                  )
                : TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _pageAnimController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late final ValueNotifier<int> _homeTabIndex;
  StreamSubscription<ble.ConnectionState>? _stateSub;
  StreamSubscription<bool>? _manualModeSub;

  @override
  void initState() {
    super.initState();
    _pageAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(
      parent: _pageAnimController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(_fadeAnim);
    _pageAnimController.value = 1.0;

    _homeTabIndex = homeTabIndex;
    _homeTabIndex.addListener(_onExternalTabChanged);
    WidgetsBinding.instance.addObserver(this);
    // Manual mode promises to disable automatic control: stop any in-flight
    // proximity scan the moment it is switched on.
    _manualModeSub = manualModeService.enabledStream.listen((enabled) {
      if (enabled) proximityService.stop();
    });
    _stateSub = connectionManager.stateStream.listen((state) {
      if (state == ble.ConnectionState.ready) {
        proximityService.onConnected();
        final device = connectionManager.device;
        if (device != null) {
          proximityService.setTargetDevice(device.remoteId.toString());
          unawaited(
            () async {
              await autoConnectService.saveDevice(device);
              final profile = await vehicleStore.upsert(
                id: device.remoteId.toString(),
                name: device.platformName,
                protocol: vehicleProtocolFromBle(connectionManager.protocol),
                makeDefault: true,
                lastConnectedAt: DateTime.now(),
              );
              await locationService.recordVehicleLocation(profile.id);
            }().catchError((Object e) {
              logService.operation(
                '连接后同步车辆信息失败',
                detail: e.toString(),
                level: LogLevel.warning,
              );
            }),
          );
        }
      }
    });

    unawaited(
      autoConnectService.tryAutoConnect().catchError((Object e) {
        logService.operation(
          '自动连接启动失败',
          detail: e.toString(),
          level: LogLevel.warning,
        );
      }),
    );
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _manualModeSub?.cancel();
    _homeTabIndex.removeListener(_onExternalTabChanged);
    _pageAnimController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onExternalTabChanged() {
    final index = _homeTabIndex.value;
    if (index == _currentIndex || index < 0 || index > 3) return;
    setState(() => _currentIndex = index);
    _pageAnimController.forward(from: 0);
  }

  void _switchTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageAnimController.forward(from: 0);
    _homeTabIndex.value = index;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      proximityService.onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      proximityService.onAppPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: IndexedStack(
            index: _currentIndex,
            children: [
              TickerMode(
                enabled: _currentIndex == 0,
                child: const ControlPage(),
              ),
              TickerMode(
                enabled: _currentIndex == 1,
                child: const LocationPage(embedded: true),
              ),
              TickerMode(
                enabled: _currentIndex == 2,
                child: const GaragePage(embedded: true),
              ),
              TickerMode(
                enabled: _currentIndex == 3,
                child: const ProfilePage(),
              ),
            ],
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.96),
              border: const Border(
                top: BorderSide(color: Color(0x12000000), width: 0.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavItem(
                      icon: Icons.directions_car_outlined,
                      selectedIcon: Icons.directions_car,
                      asset: 'assets/official_tailg/ic_tab_home_unselected.png',
                      selectedAsset:
                          'assets/official_tailg/ic_tab_home_selected.png',
                      label: '控车',
                      selected: _currentIndex == 0,
                      onTap: () => _switchTab(0),
                    ),
                    _NavItem(
                      icon: Icons.location_on_outlined,
                      selectedIcon: Icons.location_on,
                      asset:
                          'assets/official_tailg/ic_tab_service_unselected.png',
                      selectedAsset:
                          'assets/official_tailg/ic_tab_service_selected.png',
                      label: '定位',
                      selected: _currentIndex == 1,
                      onTap: () => _switchTab(1),
                    ),
                    _NavItem(
                      icon: Icons.garage_outlined,
                      selectedIcon: Icons.garage,
                      asset: 'assets/official_tailg/ic_tab_mall_unselected.png',
                      selectedAsset:
                          'assets/official_tailg/ic_tab_mall_selected.png',
                      label: '车库',
                      selected: _currentIndex == 2,
                      onTap: () => _switchTab(2),
                    ),
                    _NavItem(
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person,
                      asset: 'assets/official_tailg/ic_tab_mine_unselected.png',
                      selectedAsset:
                          'assets/official_tailg/ic_tab_mine_selected.png',
                      label: '我的',
                      selected: _currentIndex == 3,
                      onTap: () => _switchTab(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Material 3 风格底部导航项：选中态使用 pill 背景高亮。
class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData? selectedIcon;
  final String? asset;
  final String? selectedAsset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    this.selectedIcon,
    this.asset,
    this.selectedAsset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  static const _duration = Duration(milliseconds: 200);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final icon = widget.selected
        ? (widget.selectedIcon ?? widget.icon)
        : widget.icon;
    final color = widget.selected ? AppColors.brandRed : AppColors.navInactive;
    final asset = widget.selected
        ? (widget.selectedAsset ?? widget.asset)
        : widget.asset;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: _duration,
        curve: _curve,
        padding: EdgeInsets.symmetric(
          horizontal: widget.selected ? 20 : 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: widget.selected
              ? AppColors.brandRed.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: _duration,
              switchInCurve: _curve,
              switchOutCurve: Curves.easeInCubic,
              child: asset == null
                  ? Icon(
                      icon,
                      key: ValueKey(icon),
                      size: widget.selected ? AppIconSizes.lg : 22.0,
                      color: color,
                    )
                  : Image.asset(
                      asset,
                      key: ValueKey(asset),
                      width: widget.selected ? 24 : 22,
                      height: widget.selected ? 24 : 22,
                      errorBuilder: (_, __, ___) => Icon(
                        icon,
                        size: widget.selected ? AppIconSizes.lg : 22.0,
                        color: color,
                      ),
                    ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: 0),
              secondChild: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  widget.label,
                  style: AppTextStyles.sectionLabelStrong.copyWith(
                    color: color,
                  ),
                ),
              ),
              crossFadeState: widget.selected
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: _duration,
            ),
          ],
        ),
      ),
    );
  }
}
