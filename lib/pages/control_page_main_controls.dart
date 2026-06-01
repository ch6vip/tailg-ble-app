part of 'control_page.dart';

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
          _PrimaryPowerControl(
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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _OfficialSmallControlButton(
                  icon: Icons.volume_up_outlined,
                  label: '寻车',
                  subLabel: '鸣笛定位',
                  loadingLabel: '寻车中',
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
                  subLabel: lockStatus,
                  loadingLabel: lockLabel == '解锁' ? '解锁中' : '设防中',
                  enabled: enabled,
                  active: lockActive,
                  loading: lockActive,
                  disabledReason: disabledReason,
                  onTap: onLockTap,
                ),
              ),
            ],
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
  final String? subLabel;
  final String loadingLabel;
  final bool enabled;
  final bool active;
  final bool loading;
  final String disabledReason;
  final VoidCallback onTap;

  const _OfficialSmallControlButton({
    required this.icon,
    required this.label,
    this.subLabel,
    this.loadingLabel = '执行中',
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
        ? _officialPressedBg
        : const Color(0xFFF0F0F5);
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.96 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Opacity(
          opacity: widget.enabled || widget.loading ? 1 : 0.54,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.loading)
                      _PulseActionIcon(icon: widget.icon, color: color)
                    else
                      Icon(widget.icon, color: color, size: 26),
                    const SizedBox(height: 6),
                    Text(
                      widget.loading ? widget.loadingLabel : widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: widget.enabled
                            ? ReplicaColors.muted
                            : Colors.grey,
                      ),
                    ),
                    if (widget.subLabel != null && !widget.loading) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: ReplicaColors.subtle,
                        ),
                      ),
                    ],
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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _phoneControlItemBg,
        borderRadius: BorderRadius.circular(_phoneControlRadius),
        border: Border.all(
          color: enabled ? color.withValues(alpha: 0.18) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: enabled ? color : _phoneControlPrimaryPressed,
              borderRadius: BorderRadius.circular(_phoneControlRadius),
            ),
            child: Icon(icon, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: ReplicaColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  enabled ? hint : disabledReason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: enabled ? ReplicaColors.muted : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 104, maxWidth: 132),
            child: SlideToAction(
              label: reverseSlide ? '左滑关闭' : '右滑启动',
              icon: icon,
              reverseSlide: reverseSlide,
              loading: loading,
              loadingLabel: loadingLabel,
              backgroundColor: color,
              enabled: enabled,
              onDisabledTap: onDisabledTap,
              onSlideComplete: onSlideComplete,
            ),
          ),
        ],
      ),
    );
  }
}
