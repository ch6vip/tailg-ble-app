part of 'control_page.dart';

class _ManualModePill extends StatefulWidget {
  const _ManualModePill();

  @override
  State<_ManualModePill> createState() => _ManualModePillState();
}

class _ManualModePillState extends State<_ManualModePill> {
  static const _motionDuration = AppMotion.micro;
  static const _motionCurve = AppMotion.pressCurve;

  bool _pressed = false;
  late bool _manualMode = manualModeService.enabled;
  StreamSubscription<bool>? _manualModeSub;

  @override
  void initState() {
    super.initState();
    _manualModeSub = manualModeService.enabledStream.listen((value) {
      if (mounted) setState(() => _manualMode = value);
    });
  }

  @override
  void dispose() {
    _manualModeSub?.cancel();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _toggleManualMode() {
    // Manual mode disables automatic actions (proximity unlock / auto-connect)
    // which run while disconnected, so it stays toggleable regardless of the
    // current connection state.
    manualModeService.setEnabled(!_manualMode);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _manualMode ? '已开启手动模式：已禁用感应解锁/自动连接，点按关闭' : '开启手动模式：禁用感应解锁/自动连接',
      child: AnimatedScale(
        duration: _motionDuration,
        curve: _motionCurve,
        scale: _pressed ? AppMotion.pressScale : 1,
        child: AnimatedContainer(
          duration: _motionDuration,
          curve: _motionCurve,
          decoration: BoxDecoration(
            color: _pressed
                ? _officialPressedBg
                : Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _toggleManualMode,
              onTapDown: (_) => _setPressed(true),
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              borderRadius: BorderRadius.circular(18),
              splashColor: AppColors.primary.withValues(alpha: 0.08),
              highlightColor: AppColors.primary.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '手动模式',
                      style: AppTextStyles.smallText.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _ManualModeToggle(
                      enabled: true,
                      value: _manualMode,
                      onChanged: (_) => _toggleManualMode(),
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
