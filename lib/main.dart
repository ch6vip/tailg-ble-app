import 'package:flutter/material.dart';
import 'ble/connection_manager.dart' as ble;
import 'services/proximity_service.dart';
import 'pages/scan_page.dart';
import 'pages/control_page.dart';
import 'pages/settings_page.dart';

final connectionManager = ble.ConnectionManager();
final proximityService = ProximityService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await proximityService.init(connectionManager);
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
          data: MediaQuery.of(context)
              .copyWith(boldText: false, textScaler: TextScaler.noScaling),
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

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    connectionManager.stateStream.listen((state) {
      if (state == ble.ConnectionState.ready) {
        proximityService.onConnected();
        final device = connectionManager.device;
        if (device != null) {
          proximityService.setTargetDevice(device.remoteId.toString());
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          ScanPage(),
          ControlPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        animationDuration: const Duration(milliseconds: 400),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching),
            selectedIcon: Icon(Icons.bluetooth_connected),
            label: '扫描',
          ),
          NavigationDestination(
            icon: Icon(Icons.electric_bike_outlined),
            selectedIcon: Icon(Icons.electric_bike),
            label: '爱车',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
