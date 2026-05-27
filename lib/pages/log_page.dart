import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/log_service.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _log = LogService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              _log.clear();
              setState(() {});
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: '全部'),
            Tab(text: 'BLE'),
            Tab(text: '操作'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(3, (i) => _LogList(entries: _getEntries(i))),
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
      return const Center(child: Text('暂无日志'));
    }
    return ListView.builder(
      reverse: true,
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
      LogLevel.debug => Colors.grey,
      LogLevel.info => Colors.blue,
      LogLevel.warning => Colors.orange,
      LogLevel.error => Colors.red,
    };

    return InkWell(
      onLongPress: () {
        final text = '$timeStr ${entry.message}${entry.detail != null ? '\n${entry.detail}' : ''}';
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(timeStr,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace')),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(color: levelColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.message, style: const TextStyle(fontSize: 13)),
                  if (entry.detail != null)
                    Text(entry.detail!,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
