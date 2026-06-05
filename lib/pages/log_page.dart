import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/diagnostic_export_service.dart';
import '../services/log_service.dart';
import '../services/vehicle_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _log = LogService();
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
  }

  @override
  void dispose() {
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

  void _copyAll() {
    final entries = _getEntries(_tabController.index);
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前没有可复制的日志'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    final report = DiagnosticExportService(
      connectionManager: connectionManager,
      logService: _log,
      vehicleStore: VehicleStore(),
      officialCloudService: officialCloudService,
    ).buildReport(entries);
    Clipboard.setData(ClipboardData(text: report));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制诊断报告（${entries.length} 条日志）'),
        duration: const Duration(seconds: 1),
      ),
    );
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
    setState(() {});
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
                  // Full-page rebuild is intentional: LogService exposes no
                  // stream/notifier, so only setState forces a re-read of its
                  // synchronous getters. Scoping to the list would require
                  // adding a stream to LogService (out of scope here).
                  onTap: () => setState(() {}),
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
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final active = _activeTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => _tabController.animateTo(i),
              behavior: HitTestBehavior.opaque,
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
                    duration: const Duration(milliseconds: 200),
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
    final timeStr =
        '${entry.time.hour.toString().padLeft(2, '0')}:'
        '${entry.time.minute.toString().padLeft(2, '0')}:'
        '${entry.time.second.toString().padLeft(2, '0')}';
    final levelColor = switch (entry.level) {
      LogLevel.debug => const Color(0xFFBDBDBD),
      LogLevel.info => const Color(0xFF2196F3),
      LogLevel.warning => const Color(0xFFFF9800),
      LogLevel.error => const Color(0xFFFF5252),
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
                color: Color(0xFF9E9E9E),
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
                          color: Color(0xFF757575),
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
