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
  final String lockStatus;
  final bool lockActive;
  final VoidCallback onLockTap;
  final bool findActive;
  final bool findEnabled;
  final String findDisabledReason;
  final VoidCallback onFindTap;

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
    required this.lockStatus,
    required this.lockActive,
    required this.onLockTap,
    required this.findActive,
    required this.findEnabled,
    required this.findDisabledReason,
    required this.onFindTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _officialControlCardDecoration,
      child: Column(
        children: [
          SizedBox(
            height: 76,
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
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _OfficialSmallControlButton(
                    icon: Icons.volume_up_outlined,
                    label: '寻车',
                    loadingLabel: ControlLoadingLabel.find.text,
                    large: true,
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
                    large: true,
                    enabled: enabled,
                    active: lockActive,
                    loading: lockActive,
                    disabledReason: disabledReason,
                    onTap: onLockTap,
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

BoxDecoration get _officialControlCardDecoration => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(_phoneControlRadius),
  border: Border.all(color: Colors.white),
  boxShadow: AppShadows.cardShadow,
);

class _OfficialSmallControlButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String loadingLabel;
  final bool enabled;
  final bool active;
  final bool loading;
  final String disabledReason;
  final VoidCallback onTap;
  final bool large;

  const _OfficialSmallControlButton({
    required this.icon,
    required this.label,
    this.loadingLabel = '执行中',
    this.large = false,
    required this.enabled,
    required this.active,
    required this.loading,
    required this.disabledReason,
    required this.onTap,
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
    final color = widget.active ? ReplicaColors.blue : ReplicaColors.muted;
    final background = widget.active
        ? ReplicaColors.blue.withValues(alpha: _pressed ? 0.16 : 0.1)
        : _pressed
        ? const Color(0xFFE4E6EB)
        : const Color(0xFFF3F3F7);
    final borderColor = widget.active
        ? ReplicaColors.blue.withValues(alpha: _pressed ? 0.24 : 0.14)
        : _pressed
        ? const Color(0xFFD7D9DE)
        : const Color(0xFFEDEFF3);
    final iconSize = widget.large ? 34.0 : 26.0;
    final fontSize = widget.large ? 18.0 : 12.0;
    final iconGap = widget.large ? 5.0 : 6.0;
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.96 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: AnimatedOpacity(
          opacity: widget.enabled || widget.loading ? 1 : 0.54,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: widget.loading
                  ? null
                  : interactive
                  ? () {
                      HapticFeedback.mediumImpact();
                      widget.onTap();
                    }
                  : _showDisabledReason,
              onTapDown: interactive ? (_) => _setPressed(true) : null,
              onTapUp: interactive ? (_) => _setPressed(false) : null,
              onTapCancel: interactive ? () => _setPressed(false) : null,
              borderRadius: BorderRadius.circular(8),
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
                    Text(
                      widget.loading ? widget.loadingLabel : widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        color: widget.enabled
                            ? ReplicaColors.muted
                            : Colors.grey,
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
    return SlideToAction(
      label: enabled ? (reverseSlide ? '左滑关闭' : '右滑启动') : '请连接车辆',
      icon: reverseSlide
          ? Icons.keyboard_double_arrow_left
          : Icons.keyboard_double_arrow_right,
      reverseSlide: reverseSlide,
      loading: loading,
      loadingLabel: loadingLabel,
      backgroundColor: _phoneControlItemBg,
      thumbColor: enabled ? _phoneControlItemBg : _phoneControlPrimaryPressed,
      enabled: enabled,
      height: 76,
      thumbSize: 64,
      thumbRadius: 8,
      trackInset: 6,
      iconSize: 30,
      labelFontSize: 13,
      loadingFontSize: 17,
      centerLabel: true,
      labelColor: enabled ? ReplicaColors.muted : AppColors.warning,
      chevronColor: ReplicaColors.subtle,
      thumbIconColor: ReplicaColors.muted,
      disabledBackgroundColor: _phoneControlItemBg,
      disabledThumbColor: const Color(0xFFE3E6EC),
      disabledIconColor: ReplicaColors.subtle,
      completionThreshold: 0.99,
      fadeLabelOnSlide: true,
      onDisabledTap: onDisabledTap,
      onSlideComplete: onSlideComplete,
    );
  }
}
