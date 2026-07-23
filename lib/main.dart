import 'dart:async';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'ble/connection_manager.dart' as ble;
import 'models/vehicle_profile.dart';
import 'services/auto_connect_service.dart';
import 'services/induction_mode_service.dart';
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
import 'theme/app_void.dart';
import 'widgets/app_toast.dart';
import 'widgets/lucide_icon.dart';
import 'widgets/void_nav.dart';

// ── Immersive Theme Extension ─────────────────────────────────────────────

/// Custom design tokens injected via ThemeExtension for immersive VOID UX.
///
/// Provides glassy surface tokens, glow parameters, gradient energies, and
/// full Material surface/onSurface/card mappings so pages can access the
/// canonical VOID palette without depending on [VoidColors] directly.
class ImmersiveTokens extends ThemeExtension<ImmersiveTokens> {
  const ImmersiveTokens({
    required this.glassBg,
    required this.glassBorder,
    required this.glowPrimary,
    required this.glowAccent,
    required this.glowIntensity,
    required this.energyGradientStart,
    required this.energyGradientEnd,
    required this.surface,
    required this.onSurface,
    required this.cardColor,
    required this.dividerColor,
    required this.scaffoldBackgroundColor,
  });

  // ── Glass / Frost ─────────────────────────────────────────────────────────
  final Color glassBg;
  final Color glassBorder;

  // ── Glow ──────────────────────────────────────────────────────────────────
  final Color glowPrimary;
  final Color glowAccent;
  final double glowIntensity;

  // ── Energy gradient ───────────────────────────────────────────────────────
  final Color energyGradientStart;
  final Color energyGradientEnd;

  // ── Material surfaces ─────────────────────────────────────────────────────
  final Color surface;
  final Color onSurface;
  final Color cardColor;
  final Color dividerColor;
  final Color scaffoldBackgroundColor;

  static const dark = ImmersiveTokens(
    glassBg: Color(0x1A151B26),
    glassBorder: Color(0x2AFFFFFF),
    glowPrimary: Color(0x3300FFB2),
    glowAccent: Color(0x227B61FF),
    glowIntensity: 1.0,
    energyGradientStart: Color(0xFF00FFB2),
    energyGradientEnd: Color(0xFF00C896),
    surface: Color(0xFF151B26),
    onSurface: Color(0xFFF4F6FA),
    cardColor: Color(0xFF151B26),
    dividerColor: Color(0x22FFFFFF),
    scaffoldBackgroundColor: Color(0xFF05070B),
  );

  static const light = ImmersiveTokens(
    glassBg: Color(0xCCFFFFFF),
    glassBorder: Color(0x1A0B1220),
    glowPrimary: Color(0x1A00A57C),
    glowAccent: Color(0x127B61FF),
    glowIntensity: 0.7,
    energyGradientStart: Color(0xFF00A57C),
    energyGradientEnd: Color(0xFF008F6A),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0B1220),
    cardColor: Color(0xFFFFFFFF),
    dividerColor: Color(0x140B1220),
    scaffoldBackgroundColor: Color(0xFFF3F5F8),
  );

  @override
  ImmersiveTokens copyWith({
    Color? glassBg,
    Color? glassBorder,
    Color? glowPrimary,
    Color? glowAccent,
    double? glowIntensity,
    Color? energyGradientStart,
    Color? energyGradientEnd,
    Color? surface,
    Color? onSurface,
    Color? cardColor,
    Color? dividerColor,
    Color? scaffoldBackgroundColor,
  }) {
    return ImmersiveTokens(
      glassBg: glassBg ?? this.glassBg,
      glassBorder: glassBorder ?? this.glassBorder,
      glowPrimary: glowPrimary ?? this.glowPrimary,
      glowAccent: glowAccent ?? this.glowAccent,
      glowIntensity: glowIntensity ?? this.glowIntensity,
      energyGradientStart: energyGradientStart ?? this.energyGradientStart,
      energyGradientEnd: energyGradientEnd ?? this.energyGradientEnd,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      cardColor: cardColor ?? this.cardColor,
      dividerColor: dividerColor ?? this.dividerColor,
      scaffoldBackgroundColor: scaffoldBackgroundColor ?? this.scaffoldBackgroundColor,
    );
  }

  @override
  ImmersiveTokens lerp(ThemeExtension<ImmersiveTokens>? other, double t) {
    if (other is! ImmersiveTokens) return this;
    return ImmersiveTokens(
      glassBg: Color.lerp(glassBg, other.glassBg, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glowPrimary: Color.lerp(glowPrimary, other.glowPrimary, t)!,
      glowAccent: Color.lerp(glowAccent, other.glowAccent, t)!,
      glowIntensity: lerpDouble(glowIntensity, other.glowIntensity, t)!,
      energyGradientStart: Color.lerp(energyGradientStart, other.energyGradientStart, t)!,
      energyGradientEnd: Color.lerp(energyGradientEnd, other.energyGradientEnd, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t)!,
      scaffoldBackgroundColor: Color.lerp(scaffoldBackgroundColor, other.scaffoldBackgroundColor, t)!,
    );
  }
}

ble.ConnectionManager get connectionManager =>
    AppServices.instance.connectionManager;
AutoConnectService get autoConnectService =>
    AppServices.instance.autoConnectService;
ManualModeService get manualModeService =>
    AppServices.instance.manualModeService;
InductionModeService get inductionModeService =>
    AppServices.instance.inductionModeService;
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
                          child: const LucideIcon(
                            Lucide.alert,
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

/// 沉浸式 VOID 页面转场：缩放 + 淡入 + 轻微旋转，对标 Awwwards 级感官体验。
class _VoidPageTransitionsBuilder extends PageTransitionsBuilder {
  const _VoidPageTransitionsBuilder();

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
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
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
    final ColorScheme lightColorScheme = ColorScheme.fromSeed(
      seedColor: VoidColors.energyDim,
      brightness: Brightness.light,
    ).copyWith(
      primary: VoidColors.energyDim,
      onPrimary: Colors.white,
      secondary: VoidColors.energyDim,
      onSecondary: Colors.white,
      surface: VoidColors.lightPanel,
      onSurface: VoidColors.lightInk,
      surfaceContainerLow: VoidColors.lightVoid,
      surfaceContainerHigh: const Color(0xFFE8ECF2),
      outline: VoidColors.lightHairline,
      outlineVariant: VoidColors.lightHairline,
    );
    final ColorScheme darkColorScheme = ColorScheme.fromSeed(
      seedColor: VoidColors.energy,
      brightness: Brightness.dark,
    ).copyWith(
      primary: VoidColors.energy,
      onPrimary: Colors.black,
      secondary: VoidColors.energyDim,
      onSecondary: Colors.black,
      surface: VoidColors.voidPanel,
      onSurface: VoidColors.ink,
      surfaceContainerLow: VoidColors.voidLift,
      surfaceContainerHigh: VoidColors.voidPanelHi,
      outline: VoidColors.hairline,
      outlineVariant: VoidColors.hairlineStrong,
    );
    return MaterialApp(
      title: '台铃智能',
      navigatorKey: AppToast.navigatorKey,
      navigatorObservers: [appRouteObserver],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: lightColorScheme,
        scaffoldBackgroundColor: VoidColors.lightVoid,
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
          color: lightColorScheme.surface,
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
              return lightColorScheme.primary;
            }
            return lightColorScheme.outline;
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
            TargetPlatform.android: _VoidPageTransitionsBuilder(),
            TargetPlatform.iOS: _VoidPageTransitionsBuilder(),
            TargetPlatform.fuchsia: _VoidPageTransitionsBuilder(),
          },
        ),
        extensions: const [ImmersiveTokens.light],
      ),
      // P0-2: 接线暗色主题。AppColorsDark 已完整定义（app_colors.dart:223-283）
      // 但此前被 ThemeMode.light 硬编码旁路。现改为跟随系统。
      // Sprint 3 Token 重建后通过 ThemeExtension<AppTokens> 统一注入。
      darkTheme: ThemeData(
        colorScheme: darkColorScheme,
        scaffoldBackgroundColor: VoidColors.voidDeep,
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
          color: darkColorScheme.surface,
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
              return darkColorScheme.secondary;
            }
            return darkColorScheme.outline;
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
            TargetPlatform.android: _VoidPageTransitionsBuilder(),
            TargetPlatform.iOS: _VoidPageTransitionsBuilder(),
            TargetPlatform.fuchsia: _VoidPageTransitionsBuilder(),
          },
        ),
        extensions: const [ImmersiveTokens.dark],
      ),
      // VOID COCKPIT is dark-first; system light still works via light tokens.
      themeMode: ThemeMode.dark,
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
      backgroundColor: VoidColors.voidDeep,
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
      bottomNavigationBar: VoidOrbitalNav(
        currentIndex: _currentIndex,
        onService: () => _switchTab(_serviceTabIndex),
        onVehicle: () => _switchTab(_vehicleTabIndex),
        onMine: () => _switchTab(_mineTabIndex),
      ),
    );
  }
}
