import 'package:flutter/material.dart';

import '../services/control_channel_resolver.dart';
import '../services/control_channel_status.dart';
import '../theme/app_colors.dart';

/// Home card for **control channel only** (智能 / 仅蓝牙 / 仅云端).
///
/// Unlock / induction controls live on [InductionSettingsPage].
class ControlAndUnlockCard extends StatelessWidget {
  const ControlAndUnlockCard({
    super.key,
    required this.channelSelected,
    required this.availability,
    required this.channelStatus,
    required this.channelBusy,
    required this.onChannelChanged,
    this.onOpenInductionSettings,
    this.cardMargin = const EdgeInsets.symmetric(horizontal: 20),
    this.cardRadius = 20,
    this.cardShadow = const <BoxShadow>[],
  });

  final OfficialControlChannel channelSelected;
  final ControlChannelAvailability availability;
  final ControlTopBarChannel channelStatus;
  final bool channelBusy;
  final ValueChanged<OfficialControlChannel> onChannelChanged;

  /// Optional gear → induction settings (unlock mode / distance).
  final VoidCallback? onOpenInductionSettings;

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
              Icon(Icons.alt_route, size: 18, color: colors.textSecondary),
              const SizedBox(width: 7),
              Text(
                '控车渠道',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: channelBusy
                    ? const Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
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
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              if (onOpenInductionSettings != null)
                IconButton(
                  tooltip: '感应设置',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: onOpenInductionSettings,
                  icon: Icon(
                    Icons.sensors,
                    size: 20,
                    color: colors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          Text(
            _channelDescription,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: availability.enabled ? colors.textTertiary : colors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
