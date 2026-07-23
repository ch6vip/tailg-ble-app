import 'package:flutter/material.dart';

import '../services/control_channel_resolver.dart';
import '../services/control_channel_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_void.dart';
import 'lucide_icon.dart';
import 'void_canvas.dart';

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

  Color _channelDotColor() {
    if (channelBusy) return VoidColors.energyAmber;
    return switch (channelStatus.kind) {
      ControlTopBarChannelKind.bleDirect ||
      ControlTopBarChannelKind.mqttRemote ||
      ControlTopBarChannelKind.cloudStandby => VoidColors.energy,
      ControlTopBarChannelKind.bleConnecting ||
      ControlTopBarChannelKind.mqttConnecting ||
      ControlTopBarChannelKind.mqttRetry => VoidColors.energyAmber,
      ControlTopBarChannelKind.unavailable => VoidColors.energyRed,
    };
  }

  ButtonStyle _segmentStyle() {
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
            ? Colors.black
            : VoidColors.inkMuted;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? VoidColors.energy
            : VoidColors.voidPanelHi;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        return BorderSide(
          color: states.contains(WidgetState.selected)
              ? VoidColors.energy
              : VoidColors.hairline,
        );
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VoidRadii.sm),
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: cardMargin,
      child: VoidGlass(
        radius: cardRadius,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const LucideIcon(
                  Lucide.channel,
                  size: 16,
                  color: VoidColors.inkMuted,
                ),
                const SizedBox(width: 8),
                Text('控车渠道', style: VoidType.micro),
                const SizedBox(width: 8),
                Expanded(
                  child: channelBusy
                      ? const Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: VoidColors.energy,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: _channelDotColor(),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _channelStatusLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: VoidType.caption.copyWith(
                                  color: VoidColors.inkMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                if (onOpenInductionSettings != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: AppTouchTargets.min,
                      minHeight: AppTouchTargets.min,
                    ),
                    tooltip: '感应解锁设置',
                    onPressed: channelBusy ? null : onOpenInductionSettings,
                    icon: const LucideIcon(
                      Lucide.settings,
                      size: 18,
                      color: VoidColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<OfficialControlChannel>(
              style: _segmentStyle(),
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
              segments: const [
                ButtonSegment(
                  value: OfficialControlChannel.automatic,
                  label: Text('智能'),
                ),
                ButtonSegment(
                  value: OfficialControlChannel.ble,
                  label: Text('仅蓝牙'),
                ),
                ButtonSegment(
                  value: OfficialControlChannel.officialCloud,
                  label: Text('仅云端'),
                ),
              ],
              selected: {channelSelected},
              onSelectionChanged: channelBusy
                  ? null
                  : (next) {
                      if (next.isEmpty) return;
                      onChannelChanged(next.first);
                    },
            ),
            const SizedBox(height: 10),
            Text(
              _channelDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: VoidType.caption.copyWith(color: VoidColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}
