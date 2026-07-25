import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/persistence_value.dart';
import '../services/display_time_formatter.dart';
import '../services/log_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/lucide_icon.dart';

const _diagnosticCardDecoration = BoxDecoration(
  color: CyberHomeColors.card,
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.tile)),
  border: Border.fromBorderSide(BorderSide(color: CyberHomeColors.line)),
);

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
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const _DiagnosticHeader(),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: DecoratedBox(
                decoration: _diagnosticCardDecoration,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      LucideIcon(
                        Lucide.info,
                        color: CyberHomeColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '实时故障诊断暂不可用，当前仅显示历史记录',
                          style: TextStyle(
                            fontSize: 13,
                            color: CyberHomeColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _history.isEmpty
                  ? const _DiagnosticEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final record = _history[index];
                        final hasFaults = record.faults.isNotEmpty;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: _diagnosticCardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  LucideIcon(
                                    hasFaults
                                        ? Lucide.alert
                                        : Lucide.checkCircle,
                                    color: hasFaults
                                        ? CyberHomeColors.danger
                                        : CyberHomeColors.success,
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
                                            ? CyberHomeColors.danger
                                            : CyberHomeColors.success,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatMonthDayMinuteText(record.time),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: CyberHomeColors.inkFaint,
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
                                    color: CyberHomeColors.inkMuted,
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
    );
  }
}

class _DiagnosticHeader extends StatelessWidget {
  const _DiagnosticHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 8),
      child: Row(
        children: [
          AppPressable(
            key: const ValueKey('diagnostic-back'),
            onTap: () => Navigator.of(context).pop(),
            semanticsLabel: '返回',
            semanticsButton: true,
            child: Container(
              width: AppTouchTargets.min,
              height: AppTouchTargets.min,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: CyberHomeColors.card,
                shape: BoxShape.circle,
                boxShadow: AppShadows.cyberActionShadow,
              ),
              child: const LucideIcon(
                Lucide.arrowLeft,
                size: 20,
                color: CyberHomeColors.inkSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '故障诊断',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: CyberHomeColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticEmptyState extends StatelessWidget {
  const _DiagnosticEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LucideIcon(
              Lucide.stethoscope,
              size: AppIconSizes.xl,
              color: CyberHomeColors.inkFaint,
            ),
            const SizedBox(height: 10),
            const Text(
              '暂无诊断记录',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: CyberHomeColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '历史诊断记录将在此显示',
              style: TextStyle(fontSize: 13, color: CyberHomeColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
