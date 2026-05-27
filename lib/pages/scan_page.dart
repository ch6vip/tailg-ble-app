import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  List<ScanResult> _results = [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) setState(() => _results = results);
    });
    FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) setState(() => _scanning = scanning);
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> _startScan() async {
    await _requestPermissions();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    _stopScan();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在连接 ${device.platformName}...')),
    );
    try {
      await connectionManager.connect(device);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索设备'),
        actions: [
          if (_scanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _results.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bluetooth_disabled,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _scanning ? '正在搜索...' : '点击下方按钮开始搜索',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final r = _results[index];
                final name = r.device.platformName.isNotEmpty
                    ? r.device.platformName
                    : '未知设备';
                final isTailg = name.contains('TL') ||
                    name.contains('tailg') ||
                    name.contains('Tailg');
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isTailg
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        isTailg ? Icons.electric_bike : Icons.bluetooth,
                        color: isTailg
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    title: Text(name),
                    subtitle: Text(r.device.remoteId.toString()),
                    trailing: Text('${r.rssi} dBm'),
                    onTap: () => _connectDevice(r.device),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanning ? _stopScan : _startScan,
        icon: Icon(_scanning ? Icons.stop : Icons.bluetooth_searching),
        label: Text(_scanning ? '停止' : '扫描'),
      ),
    );
  }
}
