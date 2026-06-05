import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'ble/connection_manager.dart' as ble;
import 'models/vehicle_profile.dart';
import 'services/proximity_service.dart';
import 'services/auto_connect_service.dart';
import 'services/location_service.dart';
import 'services/log_service.dart';
import 'services/official_cloud_service.dart';
import 'services/vehicle_store.dart';
import 'services/app_preferences_service.dart';
import 'pages/scan_page.dart';
import 'pages/control_page.dart';
import 'pages/settings_page.dart';
import 'theme/app_colors.dart';

final connectionManager = ble.ConnectionManager();
final proximityService = ProximityService();
final autoConnectService = AutoConnectService();
final locationService = LocationService();
final logService = LogService();
final vehicleStore = VehicleStore();
final officialCloudService = OfficialCloudService();
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
  runApp(const TailgBleApp());
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
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
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              border: Border(
                top: BorderSide(
                  color: Colors.black.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: NavigationBar(
                height: AppNav.barBaseHeight,
                selectedIndex: _currentIndex,
                onDestinationSelected: _switchTab,
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                surfaceTintColor: Colors.transparent,
                indicatorColor: AppColors.primary.withValues(alpha: 0.12),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.search),
                    selectedIcon: Icon(Icons.search),
                    label: '扫描',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.directions_car_outlined),
                    selectedIcon: Icon(Icons.directions_car),
                    label: '爱车',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
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
