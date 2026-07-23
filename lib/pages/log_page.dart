import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/lucide_icon.dart';
import '../main.dart';
import '../services/clipboard_text.dart';
import '../services/diagnostic_export_service.dart';
import '../services/display_time_formatter.dart';
import '../services/log_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_void.dart';
import '../widgets/app_chrome.dart';
import '../widgets/void_canvas.dart';
import '../widgets/app_snack.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  final _log = logService;
  StreamSubscription<void>? _logSub;
  // Bumped on refresh so setState is never empty (test convention).
  int _listGeneration = 0;

  @override
  void initState() {
    super.initState();
    // Subscribe to LogService.changes so the list refreshes automatically
    // when new entries arrive (P3-12). The manual refresh button remains as
    // a force-rebuild escape hatch.
    _logSub = _log.changes.listen((_) {
      _refreshVisibleLogs();
    });
  }

  @override
  void dispose() {
    final logSub = _logSub;
    if (logSub != null) unawaited(logSub.cancel());
    super.dispose();
  }

  void _refreshVisibleLogs() {
    if (!mounted) return;
    setState(() => _listGeneration++);
  }

  Future<void> _copyAll() async {
    final entries = _log.all;
    if (entries.isEmpty) {
      AppSnack.info(context, '当前没有可复制的日志');
      return;
    }
    final report = DiagnosticExportService(
      logService: _log,
      vehicleStore: vehicleStore,
      officialCloudService: officialCloudService,
    ).buildReport(entries);
    await writeClipboardText(report);
    if (!mounted) return;
    AppSnack.success(context, '已复制诊断报告（${entries.length} 条日志）');
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('清空后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _log.clear();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _log.all;
    return Scaffold(
      backgroundColor: VoidColors.voidDeep,
      body: VoidCanvas(
        child: SafeArea(
          child: Column(
            children: [
              AppPageHeader(
                title: '日志',
                actions: [
                  AppHeaderAction(
                    icon: Lucide.copy,
                    tooltip: '复制全部',
                    onTap: _copyAll,
                  ),
                  AppHeaderAction(
                    icon: Lucide.refresh,
                    tooltip: '刷新',
                    // LogService.changes now auto-refreshes the page, but keep
                    // the manual button for cases where the user wants to force
                    // a re-read (e.g. after rotating the device).
                    onTap: _refreshVisibleLogs,
                  ),
                  AppHeaderAction(
                    icon: Lucide.trash,
                    tooltip: '清空',
                    onTap: _confirmClear,
                  ),
                ],
              ),
              Expanded(
                child: _LogList(
                  key: ValueKey<int>(_listGeneration),
                  entries: entries,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  final List<LogEntry> entries;
  const _LogList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: AppEmptyState(
          icon: Lucide.receipt,
          title: '暂无日志',
          subtitle: '云端控车与诊断操作的运行日志会显示在这里。',
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[entries.length - 1 - index];
        return _LogTile(entry: entry);
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  final LogEntry entry;
  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final timeStr = formatLogClockTime(entry.time);
    final detail = entry.detail;
    final levelColor = switch (entry.level) {
      LogLevel.debug => AppColors.textTertiary,
      LogLevel.info => AppColors.info,
      LogLevel.warning => AppColors.warning,
      LogLevel.error => AppColors.danger,
    };

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              timeStr,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: levelColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  if (detail != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
