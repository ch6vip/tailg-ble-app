import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/lucide_icon.dart';

import '../main.dart';
import '../models/official_vehicle.dart';
import '../services/display_time_formatter.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_void.dart';
import '../theme/app_motion.dart';
import '../widgets/app_chrome.dart';
import '../widgets/void_canvas.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import 'official_cloud_page.dart';

class VehicleMessagePage extends StatefulWidget {
  const VehicleMessagePage({super.key});

  @override
  State<VehicleMessagePage> createState() => _VehicleMessagePageState();
}

class _VehicleMessagePageState extends State<VehicleMessagePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  StreamSubscription<OfficialCloudState>? _cloudSub;
  int _activeTab = 0;
  final Set<String> _readIds = {};
  final Set<String> _hiddenIds = {};
  var _loading = false;
  var _clearing = false;
  String? _error;
  var _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
    _cloudSub = officialCloudService.stateStream.listen((_) {
      if (!mounted) return;
      setState(_syncFromCloudState);
    });
    unawaited(
      _bootstrap().catchError((Object error) {
        logService.operation(
          '消息页初始化失败',
          detail: OfficialCloudRedactor.errorMessage(error),
          level: LogLevel.warning,
        );
      }),
    );
  }

  @override
  void dispose() {
    final cloudSub = _cloudSub;
    if (cloudSub != null) unawaited(cloudSub.cancel());
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadMessageState();
    if (!mounted) return;
    await _refreshMessages(force: true);
  }

  void _syncFromCloudState() {
    // Rebuild against the latest OfficialCloudState snapshot.
  }

  Future<void> _loadMessageState() async {
    await messageReadStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _readIds
        ..clear()
        ..addAll(messageReadStore.readIds);
      _hiddenIds
        ..clear()
        ..addAll(messageReadStore.hiddenIds);
    });
    await _syncUnreadBadge();
  }

  Future<void> _saveMessageState() async {
    await messageReadStore.replaceState(
      readIds: _readIds,
      hiddenIds: _hiddenIds,
    );
    await _syncUnreadBadge();
  }

  Future<void> _syncUnreadBadge() async {
    final state = officialCloudService.state;
    await messageReadStore.syncFromCloudMessages(
      vehicleMessages: state.vehicleMessages,
      systemMessages: state.systemMessages,
    );
  }

  Future<void> _refreshMessages({bool force = false}) async {
    if (!officialCloudService.state.signedIn) {
      setState(() {
        _initialized = true;
        _loading = false;
        _error = null;
      });
      messageReadStore.setUnreadCount(0);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await officialCloudService.refreshMessages(force: force);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _initialized = true;
        _error = officialCloudService.state.messagesError;
      });
      await _syncUnreadBadge();
    } catch (e) {
      if (!mounted) return;
      final message = OfficialCloudRedactor.errorMessage(e);
      setState(() {
        _loading = false;
        _initialized = true;
        _error = message;
      });
      logService.operation(
        '官方消息刷新失败',
        detail: message,
        level: LogLevel.warning,
      );
    }
  }

  List<_VehicleMessage> _visibleMessages() {
    final state = officialCloudService.state;
    final messages = <_VehicleMessage>[
      ...state.vehicleMessages.map(_mapCloudMessage),
      ...state.systemMessages.map(_mapCloudMessage),
    ]..sort((a, b) => b.time.compareTo(a.time));
    return messages
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

  _VehicleMessage _mapCloudMessage(OfficialCloudMessage message) {
    final isSystem = message.category == OfficialCloudMessageCategory.system;
    final lower = '${message.title} ${message.content}'.toLowerCase();
    final severity = _severityFor(lower);
    return _VehicleMessage(
      id: message.id,
      title: message.title,
      subtitle: message.content.isEmpty ? '暂无详细内容' : message.content,
      time: message.time,
      icon: isSystem ? Lucide.megaphone : _iconFor(lower, severity),
      category: isSystem
          ? _VehicleMessageCategory.system
          : _VehicleMessageCategory.device,
      severity: severity,
    );
  }

  _VehicleMessageSeverity _severityFor(String lower) {
    if (lower.contains('故障') ||
        lower.contains('报警') ||
        lower.contains('异常') ||
        lower.contains('失败') ||
        lower.contains('warning') ||
        lower.contains('error')) {
      if (lower.contains('故障') ||
          lower.contains('error') ||
          lower.contains('报警')) {
        return _VehicleMessageSeverity.error;
      }
      return _VehicleMessageSeverity.warning;
    }
    return _VehicleMessageSeverity.info;
  }

  IconData _iconFor(String lower, _VehicleMessageSeverity severity) {
    if (lower.contains('位置') || lower.contains('定位')) {
      return Lucide.mapPin;
    }
    if (lower.contains('电') || lower.contains('电池')) {
      return Lucide.batteryWarning;
    }
    if (severity == _VehicleMessageSeverity.error) {
      return Lucide.alert;
    }
    return Lucide.vehicle;
  }

  Future<void> _markReadAll() async {
    setState(() {
      for (final message in _messagesForTab(_tabController.index)) {
        _readIds.add(message.id);
      }
    });
    await _saveMessageState();
  }

  Future<void> _clearAllMessages() async {
    final allMessages = _visibleMessages();
    if (allMessages.isEmpty || _clearing) return;
    setState(() => _clearing = true);
    try {
      await officialCloudService.deleteMessages();
      if (!mounted) return;
      setState(() {
        _hiddenIds.addAll(allMessages.map((message) => message.id));
        _readIds.addAll(allMessages.map((message) => message.id));
        _clearing = false;
      });
      await _saveMessageState();
      if (!mounted) return;
      AppSnack.success(context, '已清空 ${allMessages.length} 条消息');
    } catch (e) {
      if (!mounted) return;
      setState(() => _clearing = false);
      final message = OfficialCloudRedactor.errorMessage(e);
      AppSnack.error(context, message);
    }
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
    final signedIn = officialCloudService.state.signedIn;
    final visibleMessages = signedIn
        ? _visibleMessages()
        : const <_VehicleMessage>[];
    final tabMessages = List.generate(
      3,
      (index) => _messagesForTab(index, visibleMessages),
      growable: false,
    );
    final all = tabMessages[0];
    final unreadCount = all
        .where((message) => !_readIds.contains(message.id))
        .length;
    return Scaffold(
      backgroundColor: VoidColors.voidDeep,
      body: VoidCanvas(
        child: SafeArea(
          child: Column(
            children: [
              AppPageHeader(
                title: '消息中心',
                actions: [
                  IconButton(
                    tooltip: '全部已读',
                    onPressed: !signedIn || all.isEmpty ? null : _markReadAll,
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Lucide.check, semanticLabel: '全部已读'),
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
                    tooltip: '清空全部消息',
                    onPressed: !signedIn || all.isEmpty || _clearing
                        ? null
                        : _clearAllMessages,
                    icon: _clearing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Lucide.trash, semanticLabel: '清空全部消息'),
                  ),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: _loading
                        ? null
                        : () => _refreshMessages(force: true),
                    icon: const Icon(Lucide.refresh),
                  ),
                ],
              ),
              _buildTabs(),
              Expanded(
                child: _buildBody(signedIn: signedIn, tabMessages: tabMessages),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required bool signedIn,
    required List<List<_VehicleMessage>> tabMessages,
  }) {
    if (!signedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppEmptyState(
                icon: Lucide.lock,
                title: OfficialCloudMessages.signInRequired,
                subtitle: '登录后可同步官方车辆消息与系统通知。',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OfficialCloudPage(),
                      ),
                    ),
                  );
                },
                child: const Text('去登录'),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading && !_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && tabMessages[0].isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppEmptyState(
                icon: Lucide.wifiOff,
                title: '消息加载失败',
                subtitle: _error,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading
                    ? null
                    : () => _refreshMessages(force: true),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshMessages(force: true),
      color: VoidColors.energy,
      backgroundColor: VoidColors.voidPanel,
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
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: const [SizedBox(height: 120), _EmptyMessageState()],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
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
                            Lucide.chevronRight,
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
        icon: Lucide.message,
        title: '暂无消息',
        subtitle: '官方车辆告警、系统通知会显示在这里。',
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
