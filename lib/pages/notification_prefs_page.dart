import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/lucide_icon.dart';

class NotificationPrefsPage extends StatefulWidget {
  const NotificationPrefsPage({super.key});

  @override
  State<NotificationPrefsPage> createState() => _NotificationPrefsPageState();
}

class _NotificationPrefsPageState extends State<NotificationPrefsPage> {
  Map<String, bool> _config = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await officialCloudService.getMessageControl();
      if (mounted) {
        setState(() {
          _config = config;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败';
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await officialCloudService.setMessagePushConfig(_config);
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.success(context, '通知偏好已保存');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, '保存失败，请重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const _NotificationHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: CyberHomeColors.primary),
      );
    }
    if (_error != null) {
      return _NotificationState(
        icon: Lucide.wifiOff,
        title: '通知偏好加载失败',
        subtitle: _error!,
        actionLabel: '重试',
        onAction: () => unawaited(_load()),
      );
    }
    if (_config.isEmpty) {
      return const _NotificationState(
        icon: Lucide.message,
        title: '暂无可配置项',
        subtitle: '当前账号没有可同步的消息开关',
      );
    }
    final entries = _config.entries.toList(growable: false);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const _SectionLabel('消息推送'),
              Material(
                key: const ValueKey('notification-preferences-group'),
                color: CyberHomeColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                  side: const BorderSide(color: CyberHomeColors.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var index = 0; index < entries.length; index++)
                      _PreferenceRow(
                        configKey: entries[index].key,
                        label: _labelFor(entries[index].key),
                        value: entries[index].value,
                        showDivider: index < entries.length - 1,
                        onChanged: (value) =>
                            setState(() => _config[entries[index].key] = value),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          decoration: const BoxDecoration(
            color: CyberHomeColors.pageBg,
            border: Border(top: BorderSide(color: CyberHomeColors.line)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              key: const ValueKey('notification-preferences-save'),
              onPressed: _saving ? null : () => unawaited(_save()),
              style: FilledButton.styleFrom(
                backgroundColor: CyberHomeColors.primary,
                foregroundColor: CyberHomeColors.white,
                disabledBackgroundColor: CyberHomeColors.controlStrong,
                disabledForegroundColor: CyberHomeColors.inkFaint,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CyberHomeColors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LucideIcon(Lucide.check, size: 18),
                        SizedBox(width: 8),
                        Text(
                          '保存设置',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  static String _labelFor(String key) {
    const labels = {
      'carMsg': '车辆消息通知',
      'sysMsg': '系统消息通知',
      'alarm': '报警通知',
      'fence': '围栏通知',
      'lowBattery': '低电量提醒',
      'maintenance': '保养提醒',
    };
    return labels[key] ?? key;
  }
}

class _NotificationHeader extends StatelessWidget {
  const _NotificationHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 8),
      child: Row(
        children: [
          AppPressable(
            key: const ValueKey('notification-preferences-back'),
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
                color: CyberHomeColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '通知偏好',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 9),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: CyberHomeColors.inkMuted,
        ),
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.configKey,
    required this.label,
    required this.value,
    required this.showDivider,
    required this.onChanged,
  });

  final String configKey;
  final String label;
  final bool value;
  final bool showDivider;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: CyberHomeColors.line))
            : null,
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        secondary: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: value
                ? CyberHomeColors.primarySoft
                : CyberHomeColors.control,
            shape: BoxShape.circle,
          ),
          child: LucideIcon(
            _iconFor(configKey),
            size: 20,
            color: value ? CyberHomeColors.primary : CyberHomeColors.inkMuted,
          ),
        ),
        title: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: CyberHomeColors.ink,
          ),
        ),
        value: value,
        activeThumbColor: CyberHomeColors.white,
        activeTrackColor: CyberHomeColors.primary,
        inactiveThumbColor: CyberHomeColors.white,
        inactiveTrackColor: CyberHomeColors.controlStrong,
        trackOutlineColor: const WidgetStatePropertyAll(
          CyberHomeColors.transparent,
        ),
        onChanged: onChanged,
      ),
    );
  }

  static IconData _iconFor(String key) {
    return switch (key) {
      'carMsg' => Lucide.message,
      'sysMsg' => Lucide.megaphone,
      'alarm' => Lucide.alert,
      'fence' => Lucide.mapPin,
      'lowBattery' => Lucide.batteryWarning,
      'maintenance' => Lucide.settings,
      _ => Lucide.message,
    };
  }
}

class _NotificationState extends StatelessWidget {
  const _NotificationState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: CyberHomeColors.inkMuted,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: 148,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: CyberHomeColors.primary,
                    foregroundColor: CyberHomeColors.white,
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
