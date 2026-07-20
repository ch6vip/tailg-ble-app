import 'package:flutter/material.dart';

import '../services/control_channel_resolver.dart';
import '../services/control_channel_status.dart';
import '../theme/app_colors.dart';
import 'app_pressable.dart';

/// Unified home card: control channel (智能/蓝牙/云端) + unlock mode (感应/手动).
///
/// Extracted from [VehicleControlHomePage] to keep the page thinner.
class ControlAndUnlockCard extends StatelessWidget {
  const ControlAndUnlockCard({
    super.key,
    required this.channelSelected,
    required this.availability,
    required this.channelStatus,
    required this.channelBusy,
    required this.onChannelChanged,
    required this.supportsInduction,
    required this.unlockSelection,
    required this.unlockBusy,
    required this.bleReady,
    required this.distance,
    required this.bondIncomplete,
    required this.onSelectInduction,
    required this.onSelectManual,
    required this.onConnectBle,
    required this.onOpenSettings,
    this.cardMargin = const EdgeInsets.symmetric(horizontal: 20),
    this.cardRadius = 20,
    this.cardShadow = const <BoxShadow>[],
  });

  final OfficialControlChannel channelSelected;
  final ControlChannelAvailability availability;
  final ControlTopBarChannel channelStatus;
  final bool channelBusy;
  final ValueChanged<OfficialControlChannel> onChannelChanged;

  final bool supportsInduction;

  /// `true` = induction, `false` = manual, `null` = unknown / reading.
  final bool? unlockSelection;
  final bool unlockBusy;
  final bool bleReady;
  final int? distance;
  final bool bondIncomplete;
  final VoidCallback onSelectInduction;
  final VoidCallback onSelectManual;
  final VoidCallback onConnectBle;
  final VoidCallback onOpenSettings;

  final EdgeInsetsGeometry cardMargin;
  final double cardRadius;
  final List<BoxShadow> cardShadow;

  String get _channelStatusLabel {
    if (channelBusy) return '指令执行中';
    if (availability.enabled ||
        channelStatus.kind == ControlTopBarChannelKind.bleConnecting ||
        channelStatus.kind == ControlTopBarChannelKind.mqttConnecting ||
        channelStatus.kind == ControlTopBarChannelKind.mqttRetry) {
      return channelStatus.label;
    }
    return '当前不可用';
  }

  String get _channelDescription {
    if (channelBusy) return '指令执行中，暂不能切换渠道';
    if (!availability.enabled) {
      final reason = switch (channelSelected) {
        OfficialControlChannel.automatic => availability.disabledReason,
        OfficialControlChannel.ble => availability.bleUnavailableReason,
        OfficialControlChannel.officialCloud =>
          availability.cloudUnavailableReason,
      };
      if (reason.trim().isNotEmpty) return reason.trim();
    }
    return switch (channelSelected) {
      OfficialControlChannel.automatic => '按车辆能力自动选择蓝牙或云端',
      OfficialControlChannel.ble => '仅附近蓝牙直连',
      OfficialControlChannel.officialCloud => '仅官方账号远程',
    };
  }

  String get _unlockStatusLine {
    if (!supportsInduction) {
      return bleReady ? '当前车型仅支持手动控车' : '连接蓝牙后识别车型';
    }
    if (unlockSelection == null) {
      return bleReady ? '正在读取解锁模式…' : '连接蓝牙后可开启感应';
    }
    if (unlockSelection == false) {
      return '手动控车 · 已关闭自动连接与感应';
    }
    if (!bleReady) return '开启感应前请先连接车辆蓝牙';
    if (bondIncomplete) {
      return '感应已开 · 请允许系统蓝牙配对';
    }
    final dist = distance == null ? '' : ' · 距离档 $distance';
    return '靠近自动解防，离开自动上锁$dist';
  }

  Color _channelDotColor(AppColorsData colors) {
    if (channelBusy) return colors.warning;
    return switch (channelStatus.kind) {
      ControlTopBarChannelKind.bleDirect ||
      ControlTopBarChannelKind.mqttRemote ||
      ControlTopBarChannelKind.cloudStandby => colors.success,
      ControlTopBarChannelKind.bleConnecting ||
      ControlTopBarChannelKind.mqttConnecting ||
      ControlTopBarChannelKind.mqttRetry => colors.warning,
      ControlTopBarChannelKind.unavailable => colors.danger,
    };
  }

  ButtonStyle _segmentStyle(AppColorsData colors) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 4),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? Colors.white
            : colors.textSecondary;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? colors.primary
            : colors.surfaceContainerHigh;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        return BorderSide(
          color: states.contains(WidgetState.selected)
              ? colors.primary
              : colors.outlineVariant,
        );
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final anyBusy = channelBusy || unlockBusy;
    final selection = unlockSelection;
    final showConnectCta = supportsInduction && !bleReady && selection != false;

    return Container(
      margin: cardMargin,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
        boxShadow: dark ? const [] : cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: colors.textSecondary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '控车与解锁',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (anyBusy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _channelDotColor(colors),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _channelStatusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                if (supportsInduction) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: '感应设置',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: onOpenSettings,
                    icon: Icon(
                      Icons.settings_outlined,
                      size: 18,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '渠道',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          SegmentedButton<OfficialControlChannel>(
            segments: const [
              ButtonSegment(
                value: OfficialControlChannel.automatic,
                icon: Icon(Icons.alt_route, size: 15),
                label: Text('智能'),
              ),
              ButtonSegment(
                value: OfficialControlChannel.ble,
                icon: Icon(Icons.bluetooth, size: 15),
                label: Text('仅蓝牙'),
              ),
              ButtonSegment(
                value: OfficialControlChannel.officialCloud,
                icon: Icon(Icons.cloud_outlined, size: 15),
                label: Text('仅云端'),
              ),
            ],
            selected: {channelSelected},
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
            onSelectionChanged: channelBusy
                ? null
                : (selection) => onChannelChanged(selection.first),
            style: _segmentStyle(colors),
          ),
          const SizedBox(height: 6),
          Text(
            _channelDescription,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.3,
              color: availability.enabled ? colors.textTertiary : colors.danger,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: colors.outlineVariant),
          ),
          Text(
            '解锁',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          SegmentedButton<bool>(
            emptySelectionAllowed: true,
            segments: [
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.sensors, size: 15),
                label: const Text('感应'),
                enabled: supportsInduction,
              ),
              const ButtonSegment(
                value: false,
                icon: Icon(Icons.touch_app_outlined, size: 15),
                label: Text('手动'),
              ),
            ],
            selected: {
              if (selection != null) selection,
              if (selection == null && !supportsInduction) false,
            },
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
            onSelectionChanged: unlockBusy
                ? null
                : (next) {
                    if (next.isEmpty) return;
                    if (next.first) {
                      onSelectInduction();
                    } else {
                      onSelectManual();
                    }
                  },
            style: _segmentStyle(colors),
          ),
          const SizedBox(height: 6),
          if (showConnectCta)
            AppPressable(
              onTap: onConnectBle,
              child: Row(
                children: [
                  Icon(Icons.bluetooth, size: 14, color: colors.primary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _unlockStatusLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.primary),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: colors.primary),
                ],
              ),
            )
          else
            Text(
              _unlockStatusLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: bondIncomplete ? colors.warning : colors.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
}
