part of 'control_page.dart';

class _RidingModeSelector extends StatelessWidget {
  final ble.ConnectionState connState;
  const _RidingModeSelector({required this.connState});

  @override
  Widget build(BuildContext context) {
    final enabled = connState == ble.ConnectionState.ready;
    return StreamBuilder<RidingMode>(
      stream: connectionManager.ridingModeStream,
      initialData: connectionManager.ridingMode,
      builder: (context, snapshot) {
        final currentMode = snapshot.data ?? RidingMode.standard;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '骑行模式',
                  style: AppTextStyles.itemTitle.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!enabled) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '需 BLE 连接后切换，云端模式仅展示车辆状态',
                    style: AppTextStyles.caption,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: RidingMode.values.map((mode) {
                    final selected = mode == currentMode;
                    final icon = switch (mode) {
                      RidingMode.eco => Icons.eco,
                      RidingMode.standard => Icons.speed,
                      RidingMode.sport => Icons.bolt,
                    };
                    final color = switch (mode) {
                      RidingMode.eco => AppColors.success,
                      RidingMode.standard => AppColors.accentSky,
                      RidingMode.sport => AppColors.warning,
                    };
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _RidingModeOption(
                          mode: mode,
                          icon: icon,
                          color: color,
                          selected: selected,
                          enabled: enabled,
                          onTap: enabled && !selected
                              ? () async {
                                  HapticFeedback.mediumImpact();
                                  await connectionManager.setRidingMode(mode);
                                }
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RidingModeOption extends StatefulWidget {
  final RidingMode mode;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _RidingModeOption({
    required this.mode,
    required this.icon,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_RidingModeOption> createState() => _RidingModeOptionState();
}

class _RidingModeOptionState extends State<_RidingModeOption> {
  static const _motionDuration = AppMotion.micro;
  static const _motionCurve = AppMotion.pressCurve;

  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.selected
        ? widget.color
        : widget.enabled
        ? AppColors.textSecondary
        : AppColors.textTertiary;
    final textColor = widget.selected
        ? widget.color
        : widget.enabled
        ? AppColors.textSecondary
        : AppColors.textTertiary;
    final backgroundColor = widget.selected
        ? widget.color.withValues(alpha: _pressed ? 0.19 : 0.15)
        : _pressed
        ? AppColors.surfaceContainerHigh
        : AppColors.surfaceContainerLow;

    return AnimatedScale(
      duration: _motionDuration,
      curve: _motionCurve,
      scale: widget.enabled && _pressed ? AppMotion.pressScale : 1,
      child: SizedBox(
        height: 72,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedContainer(
              duration: _motionDuration,
              curve: _motionCurve,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(_phoneControlRadius),
                boxShadow: widget.selected ? AppShadows.elevation2 : null,
              ),
            ),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(_phoneControlRadius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: widget.onTap != null
                    ? (_) => _setPressed(true)
                    : null,
                onTapUp: widget.onTap != null
                    ? (_) => _setPressed(false)
                    : null,
                onTapCancel: widget.onTap != null
                    ? () => _setPressed(false)
                    : null,
                splashColor: widget.color.withValues(alpha: 0.08),
                highlightColor: widget.color.withValues(alpha: 0.05),
              ),
            ),
            IgnorePointer(
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: _motionDuration,
                  curve: _motionCurve,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: widget.selected ? 1 : 0,
                        ),
                        duration: _motionDuration,
                        curve: _motionCurve,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, -2 * value),
                            child: IconTheme(
                              data: IconThemeData(
                                color: iconColor,
                                size: 24 + value,
                              ),
                              child: child!,
                            ),
                          );
                        },
                        child: Icon(widget.icon),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.mode.label, maxLines: 1),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualModeToggle extends StatefulWidget {
  final bool enabled;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  const _ManualModeToggle({required this.enabled, this.value, this.onChanged});

  @override
  State<_ManualModeToggle> createState() => _ManualModeToggleState();
}

class _ManualModeToggleState extends State<_ManualModeToggle> {
  bool _manualMode = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.value ?? _manualMode;
    return Semantics(
      toggled: selected,
      label: '手动模式',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled
            ? () {
                final next = !selected;
                if (widget.value == null) {
                  setState(() => _manualMode = next);
                }
                widget.onChanged?.call(next);
                HapticFeedback.selectionClick();
              }
            : null,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 26,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(13),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: selected
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
