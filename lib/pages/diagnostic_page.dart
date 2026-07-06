import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../ble/hex.dart';
import '../models/persistence_value.dart';
import '../services/log_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_snack.dart';

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

  DiagnosticRecord({
    required this.time,
    required this.rawByte,
    required this.faults,
  });

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'raw': rawByte,
    'faults': faults,
  };

  factory DiagnosticRecord.fromJson(
    Map<String, dynamic> json, {
    DateTime? fallbackNow,
  }) => DiagnosticRecord(
    time: parsePersistedDate(json['time']) ?? fallbackNow ?? DateTime.now(),
    rawByte: parsePersistedInt(json['raw']) ?? 0,
    faults: parsePersistedStringList(json['faults']),
  );

  static DiagnosticRecord? tryParse(String raw) {
    try {
      return _fromDecoded(jsonDecode(raw));
    } on Object {
      // One corrupt history entry should not hide later diagnostic records.
      return null;
    }
  }

  static DiagnosticRecord? _fromDecoded(Object? decoded) {
    final json = parsePersistedMap(decoded);
    return json == null ? null : DiagnosticRecord.fromJson(json);
  }

  static List<DiagnosticRecord> parseHistory(Iterable<String> entries) {
    return entries
        .map(DiagnosticRecord.tryParse)
        .whereType<DiagnosticRecord>()
        .toList()
        .reversed
        .toList();
  }

  static List<String> encodeHistory(Iterable<DiagnosticRecord> records) {
    final ordered = records.toList(growable: false);
    return ordered.reversed
        .take(20)
        .map((record) => jsonEncode(record.toJson()))
        .toList();
  }
}

class DiagnosticPage extends StatefulWidget {
  const DiagnosticPage({super.key});

  @override
  State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage> {
  final _log = logService;
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
    if (!mounted) return;
    setState(() {
      _history = DiagnosticRecord.parseHistory(data);
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = DiagnosticRecord.encodeHistory(_history);
    await prefs.setStringList('diagnostic_history', data);
  }

  List<FaultInfo> _parseFaults(int faultByte) {
    return [
      FaultInfo(
        code: 0x01,
        name: '电机故障',
        description: '电机运行异常或线路断开',
        icon: Icons.settings_suggest,
        active: (faultByte & 0x01) != 0,
      ),
      FaultInfo(
        code: 0x02,
        name: '转把故障',
        description: '转把信号异常或接触不良',
        icon: Icons.rotate_right,
        active: (faultByte & 0x02) != 0,
      ),
      FaultInfo(
        code: 0x04,
        name: '控制器故障',
        description: '控制器通信异常',
        icon: Icons.memory,
        active: (faultByte & 0x04) != 0,
      ),
      FaultInfo(
        code: 0x08,
        name: '电机缺相',
        description: '电机相线接触不良或断开',
        icon: Icons.electrical_services,
        active: (faultByte & 0x08) != 0,
      ),
      FaultInfo(
        code: 0x10,
        name: '刹车故障',
        description: '刹车传感器异常或常闭',
        icon: Icons.do_not_disturb,
        active: (faultByte & 0x10) != 0,
      ),
      FaultInfo(
        code: 0x20,
        name: '欠压保护',
        description: '电池电压过低，请及时充电',
        icon: Icons.battery_alert,
        active: (faultByte & 0x20) != 0,
      ),
    ];
  }

  // PLACEHOLDER_DIAGNOSTIC_METHODS
  Future<void> _runDiagnostic() async {
    if (connectionManager.state != ble.ConnectionState.ready) {
      AppSnack.info(context, '请先连接车辆');
      return;
    }
    setState(() => _scanning = true);
    _log.operation('开始故障诊断');
    try {
      final data = await connectionManager.readFeb3();
      if (data == null) throw Exception('feb3 特征未找到');
      if (data.length < 6) throw Exception('数据不完整 (${data.length} bytes)');
      final faultByte = data[5];
      final faults = _parseFaults(faultByte);
      final activeFaults = faults.where((f) => f.active).toList();
      setState(() {
        _rawFaultByte = faultByte;
        _currentFaults = faults;
      });
      final record = DiagnosticRecord(
        time: DateTime.now(),
        rawByte: faultByte,
        faults: activeFaults.map((f) => f.name).toList(),
      );
      _history.insert(0, record);
      await _saveHistory();
      _log.operation(
        '诊断完成',
        detail:
            'raw=0x${faultByte.toRadixString(16)}, 故障数=${activeFaults.length}',
      );
    } catch (e) {
      _log.operation('诊断失败', detail: e.toString(), level: LogLevel.error);
      if (mounted) {
        AppSnack.error(context, '诊断失败: $e');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawFaultByte = _rawFaultByte;
    final activeFaults = _currentFaults.where((f) => f.active).toList();
    final allClear = rawFaultByte != null && activeFaults.isEmpty;
    return StreamBuilder<ble.ConnectionState>(
      stream: connectionManager.stateStream,
      initialData: connectionManager.state,
      builder: (context, snapshot) {
        final connState = snapshot.data ?? ble.ConnectionState.disconnected;
        return Scaffold(
          backgroundColor: AppColors.pageBg,
          body: SafeArea(
            child: Column(
              children: [
                const AppPageHeader(title: '故障诊断'),
                ConnectionStatusBanner(
                  state: connState,
                  onScanTap: () => openScanTab(context),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      FilledButton.icon(
                        onPressed: _scanning ? null : _runDiagnostic,
                        icon: _scanning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.search,
                                size: AppIconSizes.lg,
                                semanticLabel: '诊断',
                              ),
                        label: Text(_scanning ? '诊断中...' : '一键诊断'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                      if (rawFaultByte != null) ...[
                        const SizedBox(height: 20),
                        AppCard(
                          margin: EdgeInsets.zero,
                          color: allClear
                              ? AppColors.success.withValues(alpha: 0.08)
                              : AppColors.danger.withValues(alpha: 0.08),
                          child: Row(
                            children: [
                              Icon(
                                allClear ? Icons.check_circle : Icons.warning,
                                color: allClear
                                    ? AppColors.success
                                    : AppColors.danger,
                                size: AppIconSizes.lg,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      allClear
                                          ? '车辆状态正常'
                                          : '检测到 ${activeFaults.length} 个故障',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: allClear
                                            ? AppColors.success
                                            : AppColors.danger,
                                      ),
                                    ),
                                    Text(
                                      '原始码: 0x${intToHex2(rawFaultByte)}',
                                      style: AppTextStyles.smallText,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._currentFaults.map(
                          (f) => AppCard(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.zero,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: f.active
                                    ? AppColors.danger.withValues(alpha: 0.15)
                                    : AppColors.success.withValues(alpha: 0.15),
                                child: Icon(
                                  f.icon,
                                  color: f.active
                                      ? AppColors.danger
                                      : AppColors.success,
                                  size: AppIconSizes.md,
                                ),
                              ),
                              title: Text(f.name),
                              subtitle: Text(
                                f.description,
                                style: AppTextStyles.caption,
                              ),
                              trailing: Text(
                                f.active ? '异常' : '正常',
                                style: TextStyle(
                                  color: f.active
                                      ? AppColors.danger
                                      : AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_history.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          '历史记录',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        ..._history.take(10).map((r) {
                          final timeStr =
                              '${r.time.month}/${r.time.day} '
                              '${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}';
                          final hasFaults = r.faults.isNotEmpty;
                          return AppCard(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: EdgeInsets.zero,
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                hasFaults
                                    ? Icons.warning_amber
                                    : Icons.check_circle_outline,
                                color: hasFaults
                                    ? AppColors.warning
                                    : AppColors.success,
                                size: AppIconSizes.md,
                              ),
                              title: Text(
                                hasFaults ? r.faults.join('、') : '无故障',
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                '0x${intToHex2(r.rawByte)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              trailing: Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
