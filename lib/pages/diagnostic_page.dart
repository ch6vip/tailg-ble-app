import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../widgets/lucide_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/persistence_value.dart';
import '../services/display_time_formatter.dart';
import '../services/log_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_void.dart';
import '../widgets/app_chrome.dart';
import '../widgets/void_canvas.dart';

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
  static const persistedHistoryLimit = 20;

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
    DateTime Function()? clock,
  }) => DiagnosticRecord(
    time: parsePersistedDateOr(json['time'], fallbackNow, clock: clock),
    rawByte: parsePersistedInt(json['raw']) ?? 0,
    faults: parsePersistedStringList(json['faults']),
  );

  static DiagnosticRecord? tryParse(
    String raw, {
    DateTime? fallbackNow,
    DateTime Function()? clock,
  }) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return DiagnosticRecord.fromJson(
        decoded,
        fallbackNow: fallbackNow,
        clock: clock,
      );
    } on Object {
      return null;
    }
  }

  static List<DiagnosticRecord> parseHistory(
    List<String> rawEntries, {
    DateTime Function()? clock,
  }) {
    final records = <DiagnosticRecord>[];
    for (final raw in rawEntries) {
      final record = tryParse(raw, clock: clock);
      if (record != null) records.add(record);
    }
    records.sort((a, b) => b.time.compareTo(a.time));
    return records;
  }

  static List<String> encodeHistory(List<DiagnosticRecord> records) {
    final sorted = [...records]..sort((a, b) => b.time.compareTo(a.time));
    final limited = sorted.take(persistedHistoryLimit).toList();
    return limited.map((r) => jsonEncode(r.toJson())).toList();
  }
}

class DiagnosticPage extends StatefulWidget {
  const DiagnosticPage({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage> {
  static const _historyKey = 'diagnostic_history';
  final _log = logService;
  List<DiagnosticRecord> _history = [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_historyKey) ?? [];
      final records = <DiagnosticRecord>[];
      for (final entry in raw) {
        final record = DiagnosticRecord.tryParse(entry, clock: widget.clock);
        if (record != null) records.add(record);
      }
      if (mounted) setState(() => _history = records);
    } catch (e) {
      _log.operation('加载诊断历史失败', detail: '$e', level: LogLevel.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VoidColors.voidDeep,
      body: VoidCanvas(
        child: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '故障诊断'),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: AppCard(
                margin: EdgeInsets.zero,
                child: Row(
                  children: [
                    Icon(
                      Lucide.info,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '实时故障诊断暂不可用，当前仅显示历史记录',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _history.isEmpty
                  ? const AppEmptyState(
                      icon: Lucide.stethoscope,
                      title: '暂无诊断记录',
                      subtitle: '历史诊断记录将在此显示',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final record = _history[index];
                        final hasFaults = record.faults.isNotEmpty;
                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    hasFaults
                                        ? Lucide.alert
                                        : Lucide.checkCircle,
                                    color: hasFaults
                                        ? AppColors.danger
                                        : AppColors.success,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      hasFaults
                                          ? '发现 ${record.faults.length} 个故障'
                                          : '车辆状态正常',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: hasFaults
                                            ? AppColors.danger
                                            : AppColors.success,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatMonthDayMinuteText(record.time),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                              if (hasFaults) ...[
                                const SizedBox(height: 8),
                                Text(
                                  record.faults.join('、'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
