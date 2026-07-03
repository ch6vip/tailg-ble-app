part of 'control_page.dart';

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

  void _toggle() {
    final selected = widget.value ?? _manualMode;
    final next = !selected;
    if (widget.value == null) {
      setState(() => _manualMode = next);
    }
    widget.onChanged?.call(next);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.value ?? _manualMode;
    return Semantics(
      toggled: selected,
      label: '手动模式',
      button: true,
      enabled: widget.enabled,
      onTap: widget.enabled ? _toggle : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? _toggle : null,
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
