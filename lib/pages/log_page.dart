import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/diagnostic_export_service.dart';
import '../services/display_time_formatter.dart';
import '../services/log_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _log = logService;
  StreamSubscription<void>? _logSub;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
    // Subscribe to LogService.changes so the list refreshes automatically
    // when new entries arrive (P3-12). The manual refresh button remains as
    // a force-rebuild escape hatch.
    _logSub = _log.changes.listen((_) {
      _refreshVisibleLogs();
    });
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  List<LogEntry> _getEntries(int tabIndex) {
    return switch (tabIndex) {
      0 => _log.all,
      1 => _log.byCategory(LogCategory.ble),
      2 => _log.byCategory(LogCategory.operation),
      _ => _log.all,
    };
  }

  void _refreshVisibleLogs() {
    if (!mounted) return;
    setState(() => _activeTab = _tabController.index);
  }

  Future<void> _copyAll() async {
    final entries = _getEntries(_tabController.index);
    if (entries.isEmpty) {
      AppSnack.info(context, '当前没有可复制的日志');
      return;
    }
    final report = DiagnosticExportService(
      connectionManager: connectionManager,
      logService: _log,
      vehicleStore: vehicleStore,
      officialCloudService: officialCloudService,
    ).buildReport(entries);
    await Clipboard.setData(ClipboardData(text: report));
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
    final tabEntries = List.generate(3, _getEntries, growable: false);
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '日志',
              actions: [
                AppHeaderAction(
                  icon: Icons.copy,
                  tooltip: '复制全部',
                  onTap: _copyAll,
                ),
                AppHeaderAction(
                  icon: Icons.refresh,
                  tooltip: '刷新',
                  // LogService.changes now auto-refreshes the page, but keep
                  // the manual button for cases where the user wants to force
                  // a re-read (e.g. after rotating the device).
                  onTap: _refreshVisibleLogs,
                ),
                AppHeaderAction(
                  icon: Icons.delete_outline,
                  tooltip: '清空',
                  onTap: _confirmClear,
                ),
              ],
            ),
            _buildTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (final entries in tabEntries) _LogList(entries: entries),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    const tabs = ['全部', 'BLE', '操作'];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final active = _activeTab == i;
          void selectTab() => _tabController.animateTo(i);
          return Expanded(
            child: AppPressable(
              onTap: selectTab,
              haptic: false,
              semanticsLabel: tabs[i],
              semanticsButton: true,
              semanticsEnabled: true,
              semanticsSelected: active,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppTouchTargets.min,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        tabs[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: active
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: AppMotion.tabIndicator,
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  final List<LogEntry> entries;
  const _LogList({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: '暂无日志',
          subtitle: '蓝牙连接、控车与诊断操作的运行日志会显示在这里。',
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
                  if (entry.detail != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        entry.detail!,
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
