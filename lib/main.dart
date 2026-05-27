import 'package:flutter/material.dart';
import 'pages/scan_page.dart';
import 'pages/control_page.dart';
import 'pages/settings_page.dart';

void main() {
  runApp(const TailgBleApp());
}

class TailgBleApp extends StatelessWidget {
  const TailgBleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tailg BLE',
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
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 1;

  final _pages = const [
    ScanPage(),
    ControlPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
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
