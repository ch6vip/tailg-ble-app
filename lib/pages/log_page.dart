import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/log_service.dart';

const _pageBg = Color(0xFFF5F6FA);
const _primary = Color(0xFF1E88E5);
const _textPrimary = Color(0xFF1A1A2E);
const _textSecondary = Color(0xFF666666);
const _textTertiary = Color(0xFF999999);

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

  String _formatEntries(List<LogEntry> entries) {
    return entries.map((e) {
      final t = '${e.time.hour.toString().padLeft(2, '0')}:'
          '${e.time.minute.toString().padLeft(2, '0')}:'
          '${e.time.second.toString().padLeft(2, '0')}';
      final tag = e.category == LogCategory.ble ? '[BLE]' : '[OP]';
      return '$t $tag ${e.message}${e.detail != null ? ' | ${e.detail}' : ''}';
    }).join('\n');
  }

  void _copyAll() {
    final entries = _getEntries(_tabController.index);
    if (entries.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _formatEntries(entries)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('已复制 ${entries.length} 条日志'),
          duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children:
                    List.generate(3, (i) => _LogList(entries: _getEntries(i))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: _textPrimary),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '日志',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ),
          _headerAction(Icons.copy, _copyAll),
          _headerAction(Icons.refresh, () => setState(() {})),
          _headerAction(Icons.delete_outline, () {
            _log.clear();
            setState(() {});
          }),
        ],
      ),
    );
  }

  Widget _headerAction(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: _textSecondary),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    const tabs = ['全部', 'BLE', '操作'];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
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
                        color: active ? _primary : _textTertiary,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: active ? _primary : Colors.transparent,
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
          child: Text('暂无日志', style: TextStyle(color: _textTertiary)));
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
    final timeStr = '${entry.time.hour.toString().padLeft(2, '0')}:'
        '${entry.time.minute.toString().padLeft(2, '0')}:'
        '${entry.time.second.toString().padLeft(2, '0')}';
    final levelColor = switch (entry.level) {
      LogLevel.debug => const Color(0xFFBDBDBD),
      LogLevel.info => const Color(0xFF2196F3),
      LogLevel.warning => const Color(0xFFFF9800),
      LogLevel.error => const Color(0xFFFF5252),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(timeStr,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9E9E9E),
                fontFamily: 'monospace',
              )),
          const SizedBox(width: 8),
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: levelColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.message,
                    style: const TextStyle(
                        fontSize: 13, color: _textPrimary, height: 1.4)),
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
    );
  }
}
