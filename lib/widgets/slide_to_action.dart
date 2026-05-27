import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SlideToAction extends StatefulWidget {
  final VoidCallback? onSlideComplete;
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color thumbColor;

  const SlideToAction({
    super.key,
    this.onSlideComplete,
    this.label = '右滑启动',
    this.icon = Icons.power_settings_new,
    this.backgroundColor = const Color(0xFF424242),
    this.thumbColor = const Color(0x44FFFFFF),
  });

  @override
  State<SlideToAction> createState() => _SlideToActionState();
}

class _SlideToActionState extends State<SlideToAction>
    with SingleTickerProviderStateMixin {
  final _dragNotifier = ValueNotifier<double>(0);
  late AnimationController _resetController;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _resetController.dispose();
    _dragNotifier.dispose();
    super.dispose();
  }

  void _resetThumb() {
    final startVal = _dragNotifier.value;
    _resetController.reset();
    _resetController.addListener(_onResetTick);
    _resetController.forward();
    _resetController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _resetController.removeListener(_onResetTick);
      }
    });
    _onResetTick = () {
      final t = Curves.easeOut.transform(_resetController.value);
      _dragNotifier.value = startVal * (1 - t);
    };
  }

  late VoidCallback _onResetTick = () {};

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onSlideComplete != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - 56;
        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: enabled
                ? widget.backgroundColor
                : widget.backgroundColor.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _dragNotifier,
                builder: (context, pos, _) {
                  final progress = maxDrag > 0 ? pos / maxDrag : 0.0;
                  return Center(
                    child: Opacity(
                      opacity: (1 - progress * 1.5).clamp(0, 1),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chevron_right,
                              color: Colors.white54, size: 20),
                          const Icon(Icons.chevron_right,
                              color: Colors.white70, size: 20),
                          const SizedBox(width: 4),
                          Text(widget.label,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              ValueListenableBuilder<double>(
                valueListenable: _dragNotifier,
                builder: (context, pos, child) {
                  return Positioned(
                    left: pos + 4,
                    top: 4,
                    child: child!,
                  );
                },
                child: GestureDetector(
                  onHorizontalDragUpdate: enabled
                      ? (details) {
                          _dragNotifier.value =
                              (_dragNotifier.value + details.delta.dx)
                                  .clamp(0.0, maxDrag);
                        }
                      : null,
                  onHorizontalDragEnd: enabled
                      ? (details) {
                          if (_dragNotifier.value > maxDrag * 0.75) {
                            HapticFeedback.heavyImpact();
                            widget.onSlideComplete?.call();
                          }
                          _resetThumb();
                        }
                      : null,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.thumbColor,
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(widget.icon, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
