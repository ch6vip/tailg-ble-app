import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../services/log_service.dart';

class FaultInfo {
  final int code;
  final String name;
  final String description;
  final IconData icon;
  final bool active;

  const FaultInfo({
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.active,
  });
}

class DiagnosticRecord {
  final DateTime time;
  final int rawByte;
  final List<String> faults;

  DiagnosticRecord({required this.time, required this.rawByte, required this.faults});

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'raw': rawByte,
    'faults': faults,
  };

  factory DiagnosticRecord.fromJson(Map<String, dynamic> json) => DiagnosticRecord(
    time: DateTime.parse(json['time']),
    rawByte: json['raw'],
    faults: List<String>.from(json['faults']),
  );
}

class DiagnosticPage extends StatefulWidget {
  const DiagnosticPage({super.key});

  @override
  State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage> {
  final _log = LogService();
  bool _scanning = false;
  List<FaultInfo> _currentFaults = [];
  int? _rawFaultByte;
  List<DiagnosticRecord> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('diagnostic_history') ?? [];
    setState(() {
      _history = data
          .map((s) => DiagnosticRecord.fromJson(jsonDecode(s)))
          .toList()
          .reversed
          .toList();
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _history.reversed
        .take(20)
        .map((r) => jsonEncode(r.toJson()))
        .toList();
    await prefs.setStringList('diagnostic_history', data);
  }

  List<FaultInfo> _parseFaults(int faultByte) {
    return [
      FaultInfo(code: 0x01, name: '电机故障',
        description: '电机运行异常或线路断开',
        icon: Icons.settings_suggest, active: (faultByte & 0x01) == 0),
      FaultInfo(code: 0x02, name: '转把故障',
        description: '转把信号异常或接触不良',
        icon: Icons.rotate_right, active: (faultByte & 0x02) == 0),
      FaultInfo(code: 0x04, name: '控制器故障',
        description: '控制器通信异常',
        icon: Icons.memory, active: (faultByte & 0x04) == 0),
      FaultInfo(code: 0x08, name: '电机缺相',
        description: '电机相线接触不良或断开',
        icon: Icons.electrical_services, active: (faultByte & 0x08) == 0),
      FaultInfo(code: 0x10, name: '刹车故障',
        description: '刹车传感器异常或常闭',
        icon: Icons.do_not_disturb, active: (faultByte & 0x10) == 0),
      FaultInfo(code: 0x20, name: '欠压保护',
        description: '电池电压过低，请及时充电',
        icon: Icons.battery_alert, active: (faultByte & 0x20) == 0),
    ];
  }

  // PLACEHOLDER_DIAGNOSTIC_METHODS
  Future<void> _runDiagnostic() async {
    if (connectionManager.state != ble.ConnectionState.ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先连接车辆')),
      );
      return;
    }
    setState(() => _scanning = true);
    _log.operation('开始故障诊断');
    try {
      final device = connectionManager.device;
      if (device == null) throw Exception('设备未连接');
      dynamic feb3Char;
      for (final service in device.servicesList) {
        if (service.serviceUuid.toString().contains('feb0')) {
          for (final c in service.characteristics) {
            if (c.characteristicUuid.toString().contains('feb3')) {
              feb3Char = c;
              break;
            }
          }
        }
      }
      if (feb3Char == null) throw Exception('feb3 特征未找到');
      final data = await feb3Char.read();
      if (data.length < 9) throw Exception('数据不完整 (${data.length} bytes)');
      final faultByte = data[8] as int;
      final faults = _parseFaults(faultByte);
      final activeFaults = faults.where((f) => f.active).toList();
      setState(() { _rawFaultByte = faultByte; _currentFaults = faults; });
      final record = DiagnosticRecord(
        time: DateTime.now(), rawByte: faultByte,
        faults: activeFaults.map((f) => f.name).toList(),
      );
      _history.insert(0, record);
      await _saveHistory();
      _log.operation('诊断完成',
          detail: 'raw=0x${faultByte.toRadixString(16)}, 故障数=${activeFaults.length}');
    } catch (e) {
      _log.operation('诊断失败', detail: e.toString(), level: LogLevel.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('诊断失败: $e')));
      }
    } finally {
      setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _rawFaultByte != null;
    final activeFaults = _currentFaults.where((f) => f.active).toList();
    final allClear = hasResult && activeFaults.isEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('故障诊断')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _scanning ? null : _runDiagnostic,
            icon: _scanning
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search),
            label: Text(_scanning ? '诊断中...' : '一键诊断'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          if (hasResult) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: allClear ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(allClear ? Icons.check_circle : Icons.warning,
                    color: allClear ? Colors.green : Colors.red, size: 32),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(allClear ? '车辆状态正常' : '检测到 ${activeFaults.length} 个故障',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                          color: allClear ? Colors.green.shade800 : Colors.red.shade800)),
                    Text('原始码: 0x${_rawFaultByte!.toRadixString(16).padLeft(2, '0').toUpperCase()}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 16),
            ..._currentFaults.map((f) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: f.active ? Colors.red.shade100 : Colors.green.shade100,
                  child: Icon(f.icon, color: f.active ? Colors.red : Colors.green, size: 20),
                ),
                title: Text(f.name),
                subtitle: Text(f.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                trailing: Text(f.active ? '异常' : '正常',
                    style: TextStyle(color: f.active ? Colors.red : Colors.green, fontWeight: FontWeight.w600)),
              ),
            )),
          ],
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('历史记录', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ..._history.take(10).map((r) {
              final timeStr = '${r.time.month}/${r.time.day} '
                  '${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}';
              final hasFaults = r.faults.isNotEmpty;
              return Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  leading: Icon(hasFaults ? Icons.warning_amber : Icons.check_circle_outline,
                      color: hasFaults ? Colors.orange : Colors.green, size: 20),
                  title: Text(hasFaults ? r.faults.join('、') : '无故障', style: const TextStyle(fontSize: 13)),
                  subtitle: Text('0x${r.rawByte.toRadixString(16).padLeft(2, '0').toUpperCase()}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  trailing: Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}