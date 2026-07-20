import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'ble/connection_manager.dart' as ble;
import 'models/vehicle_profile.dart';
import 'services/auto_connect_service.dart';
import 'services/location_service.dart';
import 'services/log_service.dart';
import 'services/manual_mode_service.dart';
import 'services/official_cloud_service.dart';
import 'services/official_mqtt_service.dart';
import 'services/permission_service.dart';
import 'services/message_read_store.dart';
import 'services/vehicle_store.dart';
import 'services/service_locator.dart';
import 'services/app_preferences_service.dart';
import 'pages/profile_mine_page.dart';
import 'pages/scan_page.dart';
import 'pages/service_hub_page.dart';
import 'pages/vehicle_control_home_page.dart';
import 'theme/app_colors.dart';
import 'theme/app_motion.dart';
import 'widgets/app_pressable.dart';
import 'widgets/app_toast.dart';

ble.ConnectionManager get connectionManager =>
    AppServices.instance.connectionManager;
AutoConnectService get autoConnectService =>
    AppServices.instance.autoConnectService;
ManualModeService get manualModeService =>
    AppServices.instance.manualModeService;
LocationService get locationService => AppServices.instance.locationService;
LogService get logService => AppServices.instance.logService;
VehicleStore get vehicleStore => AppServices.instance.vehicleStore;
MessageReadStore get messageReadStore => AppServices.instance.messageReadStore;
OfficialCloudService get officialCloudService =>
    AppServices.instance.officialCloudService;
OfficialMqttService get officialMqttService =>
    AppServices.instance.officialMqttService;
AppPreferencesService get appPreferencesService =>
    AppServices.instance.appPreferencesService;
AppPermissionService get permissionService =>
    AppServices.instance.permissionService;

ValueNotifier<int> get homeTabIndex => AppServices.instance.homeTabIndex;

/// Shared RouteObserver so tab pages can silent-refresh on didPopNext.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();

VehicleProtocol vehicleProtocolFromBle(ble.ProtocolType protocol) {
  return switch (protocol) {
    ble.ProtocolType.kks || ble.ProtocolType.tlink => VehicleProtocol.standard,
    ble.ProtocolType.qgj => VehicleProtocol.qgj,
    ble.ProtocolType.unknown => VehicleProtocol.auto,
  };
}

/// Apply any local BLE auth material for [vehicle].
///
/// QGJ password/userId fields were scrubbed from [VehicleProfile] during the
/// cloud-only cleanup; ConnectionManager still accepts credentials for the
/// QGJ login frame, so we intentionally reset them to zero defaults here.
void applyVehicleBleCredentials(VehicleProfile? vehicle) {
  connectionManager.setOfficialConnectionContext(null);
  connectionManager.setQgjCredentials(password: 0, userId: 0);
}

void openScanTab(BuildContext context) {
  unawaited(
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ScanPage())),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await appPreferencesService.init();
    await vehicleStore.init();
    await officialCloudService.init();
    await manualModeService.init();
    await autoConnectService.init(connectionManager);
    // Keep official MQTT session aligned with selected vehicle (pre-connect).
    officialMqttService.attachToCloud(officialCloudService);
    // P1-4: logout tears down MQTT + BLE so no stale control path remains.
    officialCloudService.afterLogoutSideEffects
      ..clear()
      ..add(() async {
        await officialMqttService.disconnect();
      })
      ..add(() async {
        await connectionManager.disconnect();
      });
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
      title: '台铃智能',
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
    final textScaleSub = _textScaleSub;
    if (textScaleSub != null) unawaited(textScaleSub.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '台铃智能',
      navigatorKey: AppToast.navigatorKey,
      navigatorObservers: [appRouteObserver],
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
  static const _serviceTabIndex = 0;
  static const _vehicleTabIndex = 1;
  static const _mineTabIndex = 2;

  int _currentIndex = _vehicleTabIndex;
  late AnimationController _pageAnimController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late final ValueNotifier<int> _homeTabIndex;

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
    final initialTab =
        _homeTabIndex.value >= _serviceTabIndex &&
            _homeTabIndex.value <= _mineTabIndex
        ? _homeTabIndex.value
        : _vehicleTabIndex;
    _currentIndex = initialTab;
    if (_homeTabIndex.value != initialTab) {
      _homeTabIndex.value = initialTab;
    }
    _homeTabIndex.addListener(_onExternalTabChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _homeTabIndex.removeListener(_onExternalTabChanged);
    _pageAnimController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onExternalTabChanged() {
    final index = _homeTabIndex.value;
    if (index == _currentIndex || index < 0 || index > _mineTabIndex) return;
    setState(() => _currentIndex = index);
    unawaited(_pageAnimController.forward(from: 0));
    if (index == _vehicleTabIndex && officialCloudService.state.signedIn) {
      unawaited(_silentRefreshVehicles(reason: '切换到控车页后官方车辆刷新失败'));
    }
  }

  void _switchTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    unawaited(_pageAnimController.forward(from: 0));
    _homeTabIndex.value = index;
    if (index == _vehicleTabIndex && officialCloudService.state.signedIn) {
      unawaited(_silentRefreshVehicles(reason: '切换到控车页后官方车辆刷新失败'));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _refreshVehicleStatusOnResume();
  }

  void _refreshVehicleStatusOnResume() {
    if (!officialCloudService.state.signedIn) return;
    // Align with official app: returning to foreground refreshes car status.
    unawaited(_silentRefreshVehicles(reason: '前台恢复后官方车辆刷新失败'));
  }

  Future<void> _silentRefreshVehicles({required String reason}) async {
    try {
      await officialCloudService.refreshVehicles(silent: true, force: true);
    } catch (e) {
      logService.operation(
        reason,
        detail: e.toString(),
        level: LogLevel.warning,
      );
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
                enabled: _currentIndex == _serviceTabIndex,
                child: const ServiceHubPage(),
              ),
              TickerMode(
                enabled: _currentIndex == _vehicleTabIndex,
                child: const VehicleControlHomePage(),
              ),
              TickerMode(
                enabled: _currentIndex == _mineTabIndex,
                child: const ProfileMinePage(),
              ),
            ],
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: _AuroraBottomNav(
        currentIndex: _currentIndex,
        onService: () => _switchTab(_serviceTabIndex),
        onVehicle: () => _switchTab(_vehicleTabIndex),
        onMine: () => _switchTab(_mineTabIndex),
      ),
    );
  }
}

/// Aurora shell bottom nav — Open Design 控车 / 服务 / 我的.
///
/// Tab **indices** stay 服务=0 / 控车=1 / 我的=2 so [AppNavigation] and
/// existing home-tab call sites keep working. Visual language uses
/// emerald accent + outline icons instead of official red assets.
class _AuroraBottomNav extends StatelessWidget {
  const _AuroraBottomNav({
    required this.currentIndex,
    required this.onService,
    required this.onVehicle,
    required this.onMine,
  });

  final int currentIndex;
  final VoidCallback onService;
  final VoidCallback onVehicle;
  final VoidCallback onMine;

  /// Visual height of the bar (keeps shell geometry tests stable).
  static const double _barHeight = 65;
  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: colors.surface.withValues(alpha: 0.96),
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.96),
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: SizedBox(
          key: const ValueKey('official-bottom-nav-bar'),
          height: _barHeight + bottomInset,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Row(
              children: [
                Expanded(
                  child: _AuroraNavItem(
                    itemKey: const ValueKey('official-bottom-nav-item-service'),
                    label: '服务',
                    icon: Icons.work_outline_rounded,
                    selected: currentIndex == 0,
                    onTap: onService,
                  ),
                ),
                Expanded(
                  child: _AuroraNavItem(
                    itemKey: const ValueKey('official-bottom-nav-item-vehicle'),
                    label: '控车',
                    icon: Icons.control_camera_outlined,
                    selected: currentIndex == 1,
                    onTap: onVehicle,
                  ),
                ),
                Expanded(
                  child: _AuroraNavItem(
                    itemKey: const ValueKey('official-bottom-nav-item-mine'),
                    label: '我的',
                    icon: Icons.person_outline_rounded,
                    selected: currentIndex == 2,
                    onTap: onMine,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuroraNavItem extends StatelessWidget {
  const _AuroraNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.itemKey,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Key? itemKey;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = selected ? colors.primary : colors.textTertiary;

    return AppPressable(
      onTap: onTap,
      pressedScale: AppMotion.pressScale,
      semanticsLabel: label,
      semanticsButton: true,
      semanticsSelected: selected,
      child: SizedBox(
        key: itemKey,
        height: _AuroraBottomNav._barHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: _AuroraBottomNav._iconSize, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
