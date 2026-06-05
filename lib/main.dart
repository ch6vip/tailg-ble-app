import 'dart:async';
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
import 'services/vehicle_store.dart';
import 'services/service_locator.dart';
import 'services/app_preferences_service.dart';
import 'pages/scan_page.dart';
import 'pages/control_page.dart';
import 'pages/settings_page.dart';
import 'theme/app_colors.dart';

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
final homeTabIndex = ValueNotifier<int>(1);

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
  Navigator.of(context).popUntil((route) => route.isFirst);
  homeTabIndex.value = 0;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(const TailgBleApp());
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
  final _preferences = AppPreferencesService();
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // 以黑色主操作色作种子，并显式钉死 primary 为纯黑、onPrimary 为白，
        // 避免 Material3 从近黑种子推导出低饱和的灰青主色（FilledButton 等会跑色）。
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(primary: AppColors.primary, onPrimary: Colors.white),
        scaffoldBackgroundColor: AppColors.pageBg,
        useMaterial3: true,
        // 统一所有 Material 按钮形状：Material3 默认是全圆角胶囊（StadiumBorder），
        // 与全 App 的极简圆角矩形风格（卡片/控车按钮 R12-16）不一致。这里把
        // Filled/Elevated/Outlined/Text 按钮统一为 R14 圆角矩形。
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
        // 统一页面转场：所有平台用同一套淡入 + 轻微上滑的转场，呼应 App 内
        // 列表项/卡片的入场微交互，比各平台默认转场更顺滑一致。
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _FadeUpPageTransitionsBuilder(),
            TargetPlatform.iOS: _FadeUpPageTransitionsBuilder(),
            TargetPlatform.fuchsia: _FadeUpPageTransitionsBuilder(),
          },
        ),
      ),
      // The app is intentionally light-only: every page is built on the fixed
      // light palette in AppColors. Pin themeMode to light so framework
      // surfaces (dialogs, sheets, menus) don't render dark under system dark
      // mode while the custom pages stay light.
      themeMode: ThemeMode.light,
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
  int _currentIndex = 1;
  late AnimationController _pageAnimController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  StreamSubscription? _stateSub;
  StreamSubscription? _manualModeSub;

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

    homeTabIndex.addListener(_onExternalTabChanged);
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
    homeTabIndex.removeListener(_onExternalTabChanged);
    _pageAnimController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onExternalTabChanged() {
    final index = homeTabIndex.value;
    if (index == _currentIndex || index < 0 || index > 2) return;
    setState(() => _currentIndex = index);
    _pageAnimController.forward(from: 0);
  }

  void _switchTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageAnimController.forward(from: 0);
    homeTabIndex.value = index;
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
              TickerMode(enabled: _currentIndex == 0, child: const ScanPage()),
              TickerMode(
                enabled: _currentIndex == 1,
                child: const ControlPage(),
              ),
              TickerMode(
                enabled: _currentIndex == 2,
                child: const SettingsPage(),
              ),
            ],
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.pageBg,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                iconTheme: WidgetStateProperty.resolveWith(
                  (states) => IconThemeData(
                    size: 24,
                    color: states.contains(WidgetState.selected)
                        ? AppColors.dark
                        : AppColors.navInactive,
                  ),
                ),
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: states.contains(WidgetState.selected)
                        ? AppColors.dark
                        : AppColors.navInactive,
                  ),
                ),
              ),
              child: NavigationBar(
                height: AppNav.barBaseHeight,
                selectedIndex: _currentIndex,
                onDestinationSelected: _switchTab,
                backgroundColor: AppColors.pageBg,
                surfaceTintColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.search),
                    selectedIcon: _NavDotIcon(Icons.search),
                    label: '扫描',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.directions_car_outlined),
                    selectedIcon: _NavDotIcon(Icons.directions_car),
                    label: '爱车',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: _NavDotIcon(Icons.settings),
                    label: '设置',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 极简高端底部导航选中态：图标上方一个小黑点指示器。
class _NavDotIcon extends StatelessWidget {
  final IconData icon;
  const _NavDotIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: const BoxDecoration(
            color: AppColors.dark,
            shape: BoxShape.circle,
          ),
        ),
        Icon(icon, color: AppColors.dark),
      ],
    );
  }
}
