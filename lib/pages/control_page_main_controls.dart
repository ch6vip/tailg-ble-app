part of 'control_page.dart';

/// 控车动作进行中的固定文案，避免散落硬编码字符串。
enum ControlLoadingLabel {
  unlock('解锁中'),
  lock('设防中'),
  find('寻车中'),
  start('启动中'),
  stop('熄火中'),
  execute('执行中');

  final String text;
  const ControlLoadingLabel(this.text);
}

/// 首页主控区：整条全宽黑色滑块 + 等宽控制按钮一排（寻车 / 设防 / 两个快捷）。
class _OfficialMainControlCard extends StatelessWidget {
  final String powerLabel;
  final String powerHint;
  final IconData powerIcon;
  final bool reverseSlide;
  final bool powerLoading;
  final String powerLoadingLabel;
  final Color powerColor;
  final bool enabled;
  final String disabledReason;
  final VoidCallback onDisabledTap;
  final VoidCallback onPowerSlideComplete;
  final IconData lockIcon;
  final String lockLabel;
  final bool lockActive;
  final VoidCallback onLockTap;
  final bool findActive;
  final bool findEnabled;
  final String findDisabledReason;
  final VoidCallback onFindTap;
  final _QuickControlSpec firstQuick;
  final _QuickControlSpec secondQuick;
  final bool firstQuickActive;
  final bool secondQuickActive;
  final bool firstQuickEnabled;
  final String firstQuickDisabledReason;
  final bool secondQuickEnabled;
  final String secondQuickDisabledReason;
  final VoidCallback onFirstQuickTap;
  final VoidCallback onSecondQuickTap;
  final VoidCallback onEditQuickTap;

  const _OfficialMainControlCard({
    required this.powerLabel,
    required this.powerHint,
    required this.powerIcon,
    required this.reverseSlide,
    required this.powerLoading,
    required this.powerLoadingLabel,
    required this.powerColor,
    required this.enabled,
    required this.disabledReason,
    required this.onDisabledTap,
    required this.onPowerSlideComplete,
    required this.lockIcon,
    required this.lockLabel,
    required this.lockActive,
    required this.onLockTap,
    required this.findActive,
    required this.findEnabled,
    required this.findDisabledReason,
    required this.onFindTap,
    required this.firstQuick,
    required this.secondQuick,
    required this.firstQuickActive,
    required this.secondQuickActive,
    required this.firstQuickEnabled,
    required this.firstQuickDisabledReason,
    required this.secondQuickEnabled,
    required this.secondQuickDisabledReason,
    required this.onFirstQuickTap,
    required this.onSecondQuickTap,
    required this.onEditQuickTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 60,
          child: _PrimaryPowerControl(
            label: powerLabel,
            hint: powerHint,
            icon: powerIcon,
            reverseSlide: reverseSlide,
            loading: powerLoading,
            loadingLabel: powerLoadingLabel,
            color: powerColor,
            enabled: enabled,
            disabledReason: disabledReason,
            onDisabledTap: onDisabledTap,
            onSlideComplete: onPowerSlideComplete,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 84,
          child: Row(
            children: [
              Expanded(
                child: _OfficialSmallControlButton(
                  icon: Icons.volume_up_outlined,
                  label: '寻车',
                  loadingLabel: ControlLoadingLabel.find.text,
                  enabled: findEnabled,
                  active: findActive,
                  loading: findActive,
                  disabledReason: findDisabledReason,
                  onTap: onFindTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OfficialSmallControlButton(
                  icon: lockIcon,
                  label: lockLabel,
                  loadingLabel: lockLabel == '解锁'
                      ? ControlLoadingLabel.unlock.text
                      : ControlLoadingLabel.lock.text,
                  enabled: enabled,
                  active: lockActive,
                  loading: lockActive,
                  disabledReason: disabledReason,
                  onTap: onLockTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OfficialSmallControlButton(
                  icon: firstQuick.icon,
                  label: firstQuick.label,
                  loadingLabel: ControlLoadingLabel.execute.text,
                  enabled: firstQuickEnabled,
                  active: firstQuickActive,
                  loading: firstQuickActive,
                  disabledReason: firstQuickDisabledReason,
                  onTap: onFirstQuickTap,
                  onLongPress: onEditQuickTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OfficialSmallControlButton(
                  icon: secondQuick.icon,
                  label: secondQuick.label,
                  loadingLabel: ControlLoadingLabel.execute.text,
                  enabled: secondQuickEnabled,
                  active: secondQuickActive,
                  loading: secondQuickActive,
                  disabledReason: secondQuickDisabledReason,
                  onTap: onSecondQuickTap,
                  onLongPress: onEditQuickTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfficialSmallControlButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String loadingLabel;
  final bool enabled;
  final bool active;
  final bool loading;
  final String disabledReason;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _OfficialSmallControlButton({
    required this.icon,
    required this.label,
    this.loadingLabel = '执行中',
    required this.enabled,
    required this.active,
    required this.loading,
    required this.disabledReason,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_OfficialSmallControlButton> createState() =>
      _OfficialSmallControlButtonState();
}

class _OfficialSmallControlButtonState
    extends State<_OfficialSmallControlButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _showDisabledReason() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.disabledReason),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.enabled && !widget.loading;
    final color = widget.active ? ReplicaColors.blue : AppColors.dark;
    final background = widget.active
        ? ReplicaColors.blue.withValues(alpha: _pressed ? 0.16 : 0.1)
        : _pressed
        ? const Color(0xFFF2F2F0)
        : Colors.white;
    final borderColor = widget.active
        ? ReplicaColors.blue.withValues(alpha: _pressed ? 0.24 : 0.14)
        : _pressed
        ? const Color(0xFFE0E0DD)
        : AppColors.border;
    const iconSize = 26.0;
    const fontSize = 12.0;
    const iconGap = 6.0;
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.96 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: AnimatedOpacity(
          opacity: widget.enabled || widget.loading ? 1 : 0.54,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: widget.loading
                  ? null
                  : interactive
                  ? () {
                      HapticFeedback.mediumImpact();
                      widget.onTap();
                    }
                  : _showDisabledReason,
              onLongPress: widget.onLongPress == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      widget.onLongPress!();
                    },
              onTapDown: interactive ? (_) => _setPressed(true) : null,
              onTapUp: interactive ? (_) => _setPressed(false) : null,
              onTapCancel: interactive ? () => _setPressed(false) : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.loading)
                      _PulseActionIcon(icon: widget.icon, color: color)
                    else
                      Icon(widget.icon, color: color, size: iconSize),
                    SizedBox(height: iconGap),
                    Flexible(
                      child: Text(
                        widget.loading ? widget.loadingLabel : widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          color: widget.enabled
                              ? AppColors.textSecondary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryPowerControl extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool reverseSlide;
  final bool loading;
  final String loadingLabel;
  final Color color;
  final bool enabled;
  final String disabledReason;
  final VoidCallback onDisabledTap;
  final VoidCallback onSlideComplete;

  const _PrimaryPowerControl({
    required this.label,
    required this.hint,
    required this.icon,
    required this.reverseSlide,
    required this.loading,
    required this.loadingLabel,
    required this.color,
    required this.enabled,
    required this.disabledReason,
    required this.onDisabledTap,
    required this.onSlideComplete,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SlideToAction(
        label: enabled ? (reverseSlide ? '左滑关闭' : '右滑启动') : '请连接车辆',
        icon: reverseSlide
            ? Icons.keyboard_double_arrow_left
            : Icons.keyboard_double_arrow_right,
        reverseSlide: reverseSlide,
        loading: loading,
        loadingLabel: loadingLabel,
        backgroundColor: enabled ? AppColors.dark : const Color(0xFFE8E8E5),
        thumbColor: Colors.white,
        enabled: enabled,
        height: 60,
        thumbSize: 48,
        thumbRadius: 14,
        trackInset: 6,
        iconSize: 24,
        labelFontSize: 14,
        loadingFontSize: 16,
        centerLabel: true,
        // The thumb already carries a double-arrow icon; a second pair of
        // direction chevrons next to the label is redundant.
        showCenterChevron: false,
        labelColor: enabled
            ? Colors.white.withValues(alpha: 0.85)
            : AppColors.textTertiary,
        chevronColor: Colors.white.withValues(alpha: 0.5),
        thumbIconColor: AppColors.dark,
        disabledBackgroundColor: const Color(0xFFE8E8E5),
        disabledThumbColor: Colors.white,
        disabledIconColor: AppColors.textTertiary,
        completionThreshold: 0.99,
        fadeLabelOnSlide: true,
        onDisabledTap: onDisabledTap,
        onSlideComplete: onSlideComplete,
      ),
    );
  }
}
