import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'ble/connection_manager.dart' as ble;
import 'services/proximity_service.dart';
import 'services/auto_connect_service.dart';
import 'pages/scan_page.dart';
import 'pages/control_page.dart';
import 'pages/settings_page.dart';
import 'theme/app_colors.dart';

final connectionManager = ble.ConnectionManager();
final proximityService = ProximityService();
final autoConnectService = AutoConnectService();
final homeTabIndex = ValueNotifier<int>(1);

void openScanTab(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  homeTabIndex.value = 0;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await proximityService.init(connectionManager);
  await autoConnectService.init(connectionManager);
  runApp(const TailgBleApp());
}

class TailgBleApp extends StatelessWidget {
  const TailgBleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tailg BLE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(boldText: false, textScaler: TextScaler.noScaling),
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
          autoConnectService.saveDevice(device);
        }
      }
    });

    autoConnectService.tryAutoConnect();
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: IndexedStack(
            index: _currentIndex,
            children: const [ScanPage(), ControlPage(), SettingsPage()],
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: AppNav.barBaseHeight + bottomInset,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              border: Border(
                top: BorderSide(
                  color: Colors.black.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
            padding: EdgeInsets.only(top: 8, bottom: bottomInset),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.search,
                  label: '扫描',
                  active: _currentIndex == 0,
                  onTap: () => _switchTab(0),
                ),
                _NavItem(
                  icon: Icons.directions_car_outlined,
                  label: '爱车',
                  active: _currentIndex == 1,
                  onTap: () => _switchTab(1),
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  label: '设置',
                  active: _currentIndex == 2,
                  onTap: () => _switchTab(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF1E88E5) : const Color(0xFFBDBDBD);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
