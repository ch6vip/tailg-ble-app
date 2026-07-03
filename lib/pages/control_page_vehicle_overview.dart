part of 'control_page.dart';

class _ManualModePill extends StatefulWidget {
  const _ManualModePill();

  @override
  State<_ManualModePill> createState() => _ManualModePillState();
}

class _ManualModePillState extends State<_ManualModePill> {
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
      child: AppPressable(
        onTap: _toggleManualMode,
        haptic: false,
        pressedScale: AppMotion.pressScale,
        duration: AppMotion.micro,
        curve: AppMotion.pressCurve,
        background: Colors.white.withValues(alpha: 0.78),
        pressedBackground: _officialPressedBg,
        borderRadius: BorderRadius.circular(18),
        semanticsLabel: '手动模式',
        semanticsButton: true,
        semanticsEnabled: true,
        semanticsToggled: _manualMode,
        builder: (context, pressed) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
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
    );
  }
}
