import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart'; // P0-6: service locator getters
import '../services/display_time_formatter.dart';
import '../services/log_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';

class VehicleMessagePage extends StatefulWidget {
  const VehicleMessagePage({super.key});

  @override
  State<VehicleMessagePage> createState() => _VehicleMessagePageState();
}

class _VehicleMessagePageState extends State<VehicleMessagePage>
    with SingleTickerProviderStateMixin {
  static const _prefReadIds = 'vehicle_message_read_ids';
  static const _prefHiddenIds = 'vehicle_message_hidden_ids';
  static const _recentLogLimit = 80;

  late final TabController _tabController;
  final _log = logService;
  StreamSubscription<void>? _logSub;
  int _activeTab = 0;
  final Set<String> _readIds = {};
  final Set<String> _hiddenIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
    _logSub = _log.changes.listen((_) {
      _refreshVisibleMessages();
    });
    _loadMessageState();
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  List<_VehicleMessage> _visibleMessages() {
    return _buildMessages()
        .where((message) => !_hiddenIds.contains(message.id))
        .toList(growable: false);
  }

  List<_VehicleMessage> _messagesForTab(
    int tabIndex, [
    List<_VehicleMessage>? visibleMessages,
  ]) {
    final all = visibleMessages ?? _visibleMessages();
    return switch (tabIndex) {
      0 => all,
      1 =>
        all
            .where((m) => m.category == _VehicleMessageCategory.system)
            .toList(growable: false),
      2 =>
        all
            .where((m) => m.category == _VehicleMessageCategory.device)
            .toList(growable: false),
      _ => all,
    };
  }

  List<_VehicleMessage> _buildMessages() {
    final messages = <_VehicleMessage>[];
    for (final entry in _recentLogEntries()) {
      final message = _mapEntry(entry);
      if (message != null) {
        messages.add(message);
      }
    }
    return messages;
  }

  List<LogEntry> _recentLogEntries() {
    final logs = _log.all;
    final firstIncluded = logs.length > _recentLogLimit
        ? logs.length - _recentLogLimit
        : 0;
    final entries = <LogEntry>[];
    for (var i = logs.length - 1; i >= firstIncluded; i--) {
      entries.add(logs[i]);
    }
    return entries;
  }

  _VehicleMessage? _mapEntry(LogEntry entry) {
    final lower = '${entry.message} ${entry.detail ?? ''}'.toLowerCase();
    final isBle = entry.category == LogCategory.ble;
    final isOp = entry.category == LogCategory.operation;

    if (isBle && lower.contains('重连成功')) {
      return _VehicleMessage(
        id: _makeId(entry),
        title: '车辆已恢复连接',
        subtitle: entry.detail ?? '蓝牙连接已恢复，设备服务重新就绪。',
        time: entry.time,
        icon: Icons.bluetooth_connected,
        category: _VehicleMessageCategory.system,
        severity: _VehicleMessageSeverity.info,
      );
    }
    if (isBle && lower.contains('设备断开连接')) {
      return _VehicleMessage(
        id: _makeId(entry),
        title: '车辆连接中断',
        subtitle: '车辆蓝牙连接已断开，正在尝试重连。',
        time: entry.time,
        icon: Icons.bluetooth_disabled,
        category: _VehicleMessageCategory.system,
        severity: _VehicleMessageSeverity.warning,
      );
    }
    if (isBle && lower.contains('连接失败')) {
      return _VehicleMessage(
        id: _makeId(entry),
        title: '车辆连接失败',
        subtitle: entry.detail ?? entry.message,
        time: entry.time,
        icon: Icons.error_outline,
        category: _VehicleMessageCategory.system,
        severity: _VehicleMessageSeverity.error,
      );
    }
    if (isBle && lower.contains('心跳连续失败')) {
      return _VehicleMessage(
        id: _makeId(entry),
        title: '通信状态异常',
        subtitle: entry.detail ?? entry.message,
        time: entry.time,
        icon: Icons.sync_problem,
        category: _VehicleMessageCategory.device,
        severity: _VehicleMessageSeverity.warning,
      );
    }
    if (isOp && lower.contains('指令失败')) {
      return _VehicleMessage(
        id: _makeId(entry),
        title: '控车指令失败',
        subtitle: entry.detail ?? entry.message,
        time: entry.time,
        icon: Icons.warning_amber_rounded,
        category: _VehicleMessageCategory.device,
        severity: _VehicleMessageSeverity.error,
      );
    }
    if (isOp && lower.contains('诊断完成')) {
      return _VehicleMessage(
        id: _makeId(entry),
        title: '故障诊断已完成',
        subtitle: entry.detail ?? entry.message,
        time: entry.time,
        icon: Icons.health_and_safety_outlined,
        category: _VehicleMessageCategory.device,
        severity: _VehicleMessageSeverity.info,
      );
    }
    if (isOp && lower.contains('记录车辆位置失败')) {
      return _VehicleMessage(
        id: _makeId(entry),
        title: '位置记录失败',
        subtitle: entry.detail ?? entry.message,
        time: entry.time,
        icon: Icons.location_off,
        category: _VehicleMessageCategory.device,
        severity: _VehicleMessageSeverity.warning,
      );
    }
    if (isOp && lower.contains('记录车辆位置')) {
      return _VehicleMessage(
        id: _makeId(entry),
        title: '车辆位置已更新',
        subtitle: entry.detail ?? entry.message,
        time: entry.time,
        icon: Icons.location_on_outlined,
        category: _VehicleMessageCategory.device,
        severity: _VehicleMessageSeverity.info,
      );
    }
    if (isOp && lower.contains('发送指令')) {
      return _VehicleMessage(
        id: _makeId(entry),
        title: entry.message,
        subtitle: entry.detail ?? '车辆指令已发送。',
        time: entry.time,
        icon: Icons.tune,
        category: _VehicleMessageCategory.device,
        severity: _VehicleMessageSeverity.info,
      );
    }
    return null;
  }

  String _makeId(LogEntry entry) {
    return '${entry.time.microsecondsSinceEpoch}_${entry.message}_${entry.detail ?? ''}';
  }

  void _refreshVisibleMessages() {
    if (!mounted) return;
    setState(() => _activeTab = _tabController.index);
  }

  Future<void> _loadMessageState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _readIds
        ..clear()
        ..addAll(prefs.getStringList(_prefReadIds) ?? const []);
      _hiddenIds
        ..clear()
        ..addAll(prefs.getStringList(_prefHiddenIds) ?? const []);
    });
  }

  Future<void> _saveMessageState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefReadIds, _readIds.toList());
    await prefs.setStringList(_prefHiddenIds, _hiddenIds.toList());
  }

  Future<void> _markReadAll() async {
    setState(() {
      for (final message in _messagesForTab(_tabController.index)) {
        _readIds.add(message.id);
      }
    });
    await _saveMessageState();
  }

  Future<void> _clearCurrentMessages() async {
    final currentMessages = _messagesForTab(_tabController.index);
    if (currentMessages.isEmpty) return;
    setState(() {
      _hiddenIds.addAll(currentMessages.map((message) => message.id));
      _readIds.addAll(currentMessages.map((message) => message.id));
    });
    await _saveMessageState();
    if (!mounted) return;
    AppSnack.success(context, '已清空 ${currentMessages.length} 条当前分组消息');
  }

  Future<void> _openMessage(_VehicleMessage message) async {
    if (!_readIds.contains(message.id)) {
      setState(() => _readIds.add(message.id));
      await _saveMessageState();
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (context) => _MessageDetailSheet(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleMessages = _visibleMessages();
    final tabMessages = List.generate(
      3,
      (index) => _messagesForTab(index, visibleMessages),
      growable: false,
    );
    final all = tabMessages[0];
    final currentMessages = tabMessages[_tabController.index];
    final unreadCount = all
        .where((message) => !_readIds.contains(message.id))
        .length;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '消息中心',
              actions: [
                IconButton(
                  tooltip: '全部已读',
                  onPressed: all.isEmpty ? null : _markReadAll,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.done_all, semanticLabel: '全部已读'),
                      if (unreadCount > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              unreadCount > 9 ? '9+' : unreadCount.toString(),
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '清空当前分组',
                  onPressed: currentMessages.isEmpty
                      ? null
                      : _clearCurrentMessages,
                  icon: const Icon(
                    Icons.delete_sweep_outlined,
                    semanticLabel: '清空',
                  ),
                ),
                IconButton(
                  tooltip: '刷新',
                  // LogService.changes auto-refreshes new messages; keep this
                  // as a manual force-rebuild for persisted read/hidden state.
                  onPressed: _refreshVisibleMessages,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            _buildTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (final messages in tabMessages)
                    _MessageList(
                      messages: messages,
                      readIds: _readIds,
                      onOpen: _openMessage,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    const tabs = ['全部', '系统消息', '设备消息'];
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
                          fontWeight: FontWeight.w600,
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

class _MessageList extends StatelessWidget {
  final List<_VehicleMessage> messages;
  final Set<String> readIds;
  final ValueChanged<_VehicleMessage> onOpen;

  const _MessageList({
    required this.messages,
    required this.readIds,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _EmptyMessageState();
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final read = readIds.contains(message.id);
        final readLabel = read ? '已读' : '未读';
        final semanticsLabel =
            '${message.title}，${message.subtitle}，${message.category.label}，$readLabel';
        void openMessage() => onOpen(message);
        final card = InkWell(
          onTap: openMessage,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: AppCard(
            margin: EdgeInsets.zero,
            color: read
                ? Colors.white
                : message.severity.color.withValues(alpha: 0.06),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MessageIcon(message: message, read: read),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message.title,
                              style: AppTextStyles.bodyLarge,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatMonthDayMinuteText(message.time),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _Tag(text: message.category.label),
                          const SizedBox(width: 8),
                          _Tag(text: readLabel),
                          const Spacer(),
                          const Icon(
                            Icons.chevron_right,
                            size: AppIconSizes.sm,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Semantics(
              label: semanticsLabel,
              button: true,
              enabled: true,
              onTap: openMessage,
              child: ExcludeSemantics(child: card),
            ),
          ),
        );
      },
    );
  }
}

class _MessageIcon extends StatelessWidget {
  final _VehicleMessage message;
  final bool read;

  const _MessageIcon({required this.message, required this.read});

  @override
  Widget build(BuildContext context) {
    final color = read ? AppColors.textTertiary : message.severity.color;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(message.icon, color: color, size: AppIconSizes.md),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MessageDetailSheet extends StatelessWidget {
  final _VehicleMessage message;

  const _MessageDetailSheet({required this.message});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _MessageIcon(message: message, read: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(message.title, style: AppTextStyles.sectionTitle),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              message.subtitle,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _Tag(text: message.category.label),
                const SizedBox(width: 8),
                _Tag(text: formatMonthDayMinuteText(message.time)),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMessageState extends StatelessWidget {
  const _EmptyMessageState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: AppEmptyState(
        icon: Icons.mark_email_unread_outlined,
        title: '暂无消息',
        subtitle: '车辆断连、重连、故障诊断、控车失败等事件会在这里汇总。',
      ),
    );
  }
}

class _VehicleMessage {
  final String id;
  final String title;
  final String subtitle;
  final DateTime time;
  final IconData icon;
  final _VehicleMessageCategory category;
  final _VehicleMessageSeverity severity;

  const _VehicleMessage({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.category,
    required this.severity,
  });
}

enum _VehicleMessageCategory {
  system('系统消息'),
  device('设备消息');

  final String label;
  const _VehicleMessageCategory(this.label);
}

enum _VehicleMessageSeverity {
  info(AppColors.info),
  warning(AppColors.warning),
  error(AppColors.danger);

  final Color color;
  const _VehicleMessageSeverity(this.color);
}
