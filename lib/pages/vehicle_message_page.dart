import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/lucide_icon.dart';

import '../main.dart';
import '../models/official_vehicle.dart';
import '../services/display_time_formatter.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/motion_policy.dart';
import '../widgets/app_chrome.dart';
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
      backgroundColor: CyberHomeColors.card,
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
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _MessageHeader(
              unreadCount: unreadCount,
              canMarkRead: signedIn && unreadCount > 0,
              canClear: signedIn && all.isNotEmpty && !_clearing,
              clearing: _clearing,
              refreshing: _loading,
              onMarkRead: () => unawaited(_markReadAll()),
              onClear: () => unawaited(_clearAllMessages()),
              onRefresh: () => unawaited(_refreshMessages(force: true)),
            ),
            _buildTabs(),
            Expanded(
              child: AnimatedSwitcher(
                duration: MotionPolicy.duration(context, AppMotion.dataChange),
                child: _buildBody(signedIn: signedIn, tabMessages: tabMessages),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({
    required bool signedIn,
    required List<List<_VehicleMessage>> tabMessages,
  }) {
    if (!signedIn) {
      return KeyedSubtree(
        key: const ValueKey('message-signed-out'),
        child: _MessageState(
          icon: Lucide.lock,
          title: OfficialCloudMessages.signInRequired,
          subtitle: '登录后可同步车辆消息与系统通知',
          actionLabel: '去登录',
          onAction: () => unawaited(
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const OfficialCloudPage(),
              ),
            ),
          ),
        ),
      );
    }

    if (_loading && !_initialized) {
      return const _MessageListSkeleton(
        key: ValueKey('message-loading-skeleton'),
      );
    }

    if (_error != null && tabMessages[0].isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('message-error'),
        child: _MessageState(
          icon: Lucide.wifiOff,
          title: '消息加载失败',
          subtitle: _error,
          actionLabel: '重试',
          onAction: _loading
              ? null
              : () => unawaited(_refreshMessages(force: true)),
        ),
      );
    }

    return RefreshIndicator(
      key: const ValueKey('message-content'),
      onRefresh: () => _refreshMessages(force: true),
      color: CyberHomeColors.primary,
      backgroundColor: CyberHomeColors.card,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Container(
        height: AppTouchTargets.min,
        decoration: BoxDecoration(
          color: CyberHomeColors.control,
          borderRadius: BorderRadius.circular(AppRadii.tile),
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
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: AnimatedContainer(
                    duration: AppMotion.tabIndicator,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? CyberHomeColors.card
                          : CyberHomeColors.transparent,
                      borderRadius: BorderRadius.circular(AppRadii.xs),
                      boxShadow: active
                          ? AppShadows.cyberActionShadow
                          : const [],
                    ),
                    child: Text(
                      tabs[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        color: active
                            ? CyberHomeColors.ink
                            : CyberHomeColors.inkMuted,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _MessageHeader extends StatelessWidget {
  const _MessageHeader({
    required this.unreadCount,
    required this.canMarkRead,
    required this.canClear,
    required this.clearing,
    required this.refreshing,
    required this.onMarkRead,
    required this.onClear,
    required this.onRefresh,
  });

  final int unreadCount;
  final bool canMarkRead;
  final bool canClear;
  final bool clearing;
  final bool refreshing;
  final VoidCallback onMarkRead;
  final VoidCallback onClear;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          _HeaderButton(
            icon: Lucide.arrowLeft,
            label: '返回',
            onTap: () => Navigator.of(context).pop(),
            filled: true,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '消息中心',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: CyberHomeColors.ink,
              ),
            ),
          ),
          _HeaderButton(
            icon: Lucide.check,
            label: '全部已读',
            enabled: canMarkRead,
            badge: unreadCount,
            onTap: onMarkRead,
          ),
          _HeaderButton(
            icon: Lucide.trash,
            label: '清空全部消息',
            enabled: canClear,
            loading: clearing,
            onTap: onClear,
          ),
          _HeaderButton(
            icon: Lucide.refresh,
            label: '刷新',
            enabled: !refreshing,
            loading: refreshing,
            onTap: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.filled = false,
    this.loading = false,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool filled;
  final bool loading;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: AppPressable(
        onTap: onTap,
        enabled: enabled,
        semanticsLabel: label,
        semanticsButton: true,
        semanticsEnabled: enabled,
        child: SizedBox(
          width: AppTouchTargets.min,
          height: AppTouchTargets.min,
          child: Center(
            child: Container(
              width: filled ? AppTouchTargets.min : 36,
              height: filled ? AppTouchTargets.min : 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filled
                    ? CyberHomeColors.card
                    : CyberHomeColors.transparent,
                shape: BoxShape.circle,
                boxShadow: filled ? AppShadows.cyberActionShadow : const [],
              ),
              child: loading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: CyberHomeColors.primary,
                      ),
                    )
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        LucideIcon(
                          icon,
                          size: 20,
                          color: enabled
                              ? CyberHomeColors.inkSecondary
                              : CyberHomeColors.inkFaint,
                        ),
                        if (badge > 0)
                          Positioned(
                            right: -8,
                            top: -7,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 16),
                              height: 16,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: CyberHomeColors.danger,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(AppRadii.pill),
                                ),
                              ),
                              child: Text(
                                badge > 9 ? '9+' : '$badge',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: CyberHomeColors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
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
    final duration = MotionPolicy.duration(context, AppMotion.dataChange);
    if (messages.isEmpty) {
      return AnimatedSwitcher(
        duration: duration,
        child: ListView(
          key: const ValueKey('message-list-empty'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: const [SizedBox(height: 100), _EmptyMessageState()],
        ),
      );
    }

    final listKey = ValueKey(
      'message-list-${messages.map((message) => message.id).join('|')}',
    );
    return AnimatedSwitcher(
      duration: duration,
      child: ListView.builder(
        key: listKey,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        itemCount: messages.length,
        findChildIndexCallback: (key) {
          if (key is! ValueKey<String>) return null;
          final index = messages.indexWhere(
            (message) => message.id == key.value,
          );
          return index < 0 ? null : index;
        },
        itemBuilder: (context, index) {
          final message = messages[index];
          final read = readIds.contains(message.id);
          final readLabel = read ? '已读' : '未读';
          final semanticsLabel =
              '${message.title}，${message.subtitle}，${message.category.label}，$readLabel';
          void openMessage() => onOpen(message);
          return RepaintBoundary(
            key: ValueKey(message.id),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: AppPressable(
                onTap: openMessage,
                semanticsLabel: semanticsLabel,
                semanticsButton: true,
                semanticsEnabled: true,
                child: AnimatedContainer(
                  duration: AppMotion.status,
                  curve: AppMotion.pressCurve,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: read
                        ? CyberHomeColors.card
                        : message.severity.color.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                    border: Border.all(
                      color: read
                          ? CyberHomeColors.line
                          : message.severity.color.withValues(alpha: 0.16),
                    ),
                  ),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    message.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: CyberHomeColors.ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatMonthDayMinuteText(message.time),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: CyberHomeColors.inkFaint,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              message.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: CyberHomeColors.inkMuted,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _Tag(text: message.category.label),
                                const SizedBox(width: 8),
                                AnimatedContainer(
                                  duration: AppMotion.status,
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: read
                                        ? CyberHomeColors.inkFaint
                                        : message.severity.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  readLabel,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: CyberHomeColors.inkMuted,
                                  ),
                                ),
                                const Spacer(),
                                const LucideIcon(
                                  Lucide.chevronRight,
                                  size: AppIconSizes.sm,
                                  color: CyberHomeColors.inkFaint,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MessageListSkeleton extends StatelessWidget {
  const _MessageListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        for (var index = 0; index < 4; index++)
          Container(
            height: 112,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CyberHomeColors.card,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              border: Border.all(color: CyberHomeColors.line),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(
                  width: 42,
                  height: 42,
                  borderRadius: BorderRadius.all(Radius.circular(21)),
                  baseColor: CyberHomeColors.control,
                  highlightColor: CyberHomeColors.cardMuted,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton(
                        width: 146,
                        height: 16,
                        baseColor: CyberHomeColors.control,
                        highlightColor: CyberHomeColors.cardMuted,
                      ),
                      SizedBox(height: 10),
                      AppSkeleton(
                        width: double.infinity,
                        height: 12,
                        baseColor: CyberHomeColors.control,
                        highlightColor: CyberHomeColors.cardMuted,
                      ),
                      SizedBox(height: 8),
                      AppSkeleton(
                        width: 110,
                        height: 10,
                        baseColor: CyberHomeColors.control,
                        highlightColor: CyberHomeColors.cardMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MessageIcon extends StatelessWidget {
  final _VehicleMessage message;
  final bool read;

  const _MessageIcon({required this.message, required this.read});

  @override
  Widget build(BuildContext context) {
    final color = read ? CyberHomeColors.inkFaint : message.severity.color;
    return AnimatedContainer(
      duration: AppMotion.status,
      curve: AppMotion.pressCurve,
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: LucideIcon(message.icon, color: color, size: AppIconSizes.md),
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
        color: CyberHomeColors.control,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: CyberHomeColors.inkMuted,
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
                  child: Text(
                    message.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: CyberHomeColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              message.subtitle,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: CyberHomeColors.inkMuted,
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
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: CyberHomeColors.primary,
                  foregroundColor: CyberHomeColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.tile),
                  ),
                ),
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

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: CyberHomeColors.card,
                shape: BoxShape.circle,
                boxShadow: AppShadows.cyberActionShadow,
              ),
              child: LucideIcon(
                icon,
                size: 28,
                color: CyberHomeColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: CyberHomeColors.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 7),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: CyberHomeColors.inkMuted,
                ),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: 148,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: CyberHomeColors.primary,
                    foregroundColor: CyberHomeColors.white,
                    disabledBackgroundColor: CyberHomeColors.controlStrong,
                    disabledForegroundColor: CyberHomeColors.inkFaint,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                    ),
                  ),
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ),
            ],
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
    return const _MessageState(
      icon: Lucide.message,
      title: '暂无消息',
      subtitle: '车辆告警和系统通知会显示在这里',
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
  info(CyberHomeColors.primary),
  warning(CyberHomeColors.warning),
  error(CyberHomeColors.danger);

  final Color color;
  const _VehicleMessageSeverity(this.color);
}
