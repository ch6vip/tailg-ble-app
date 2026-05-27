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
    this.icon = Icons.lock_outline,
    this.backgroundColor = const Color(0xFF424242),
    this.thumbColor = const Color(0x40FFFFFF),
  });

  @override
  State<SlideToAction> createState() => _SlideToActionState();
}

class _SlideToActionState extends State<SlideToAction>
    with TickerProviderStateMixin {
  final _dragNotifier = ValueNotifier<double>(0);
  late AnimationController _resetController;
  late AnimationController _successController;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(SlideToAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label) {
      _dragNotifier.value = 0;
    }
  }

  @override
  void dispose() {
    _resetController.dispose();
    _successController.dispose();
    _dragNotifier.dispose();
    super.dispose();
  }

  void _onSlideSuccess(double maxDrag) {
    HapticFeedback.heavyImpact();
    _dragNotifier.value = maxDrag;
    _successController.forward(from: 0).then((_) {
      _resetThumb();
    });
    widget.onSlideComplete?.call();
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
      final t = Curves.elasticOut.transform(_resetController.value);
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
        return AnimatedBuilder(
          animation: _successController,
          builder: (context, child) {
            final successValue = _successController.value;
            final glowOpacity = successValue < 0.5
                ? successValue * 2
                : (1 - successValue) * 2;
            return Container(
              height: 56,
              decoration: BoxDecoration(
                color: enabled
                    ? widget.backgroundColor
                    : widget.backgroundColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(28),
                boxShadow: glowOpacity > 0
                    ? [
                        BoxShadow(
                          color: const Color(0xFF4CAF50)
                              .withValues(alpha: glowOpacity * 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: child,
            );
          },
          child: Stack(
            children: [
              ValueListenableBuilder<double>(
                valueListenable: _dragNotifier,
                builder: (context, pos, _) {
                  final progress = maxDrag > 0 ? pos / maxDrag : 0.0;
                  return Center(
                    child: Opacity(
                      opacity: (1 - progress * 1.8).clamp(0.0, 1.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_right,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 18),
                          Icon(Icons.chevron_right,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 18),
                          const SizedBox(width: 4),
                          Text(widget.label,
                              style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.6),
                                  fontSize: 14)),
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
                          final prev = _dragNotifier.value;
                          _dragNotifier.value =
                              (_dragNotifier.value + details.delta.dx)
                                  .clamp(0.0, maxDrag);
                          if (prev < maxDrag * 0.3 &&
                              _dragNotifier.value >= maxDrag * 0.3) {
                            HapticFeedback.selectionClick();
                          }
                        }
                      : null,
                  onHorizontalDragEnd: enabled
                      ? (details) {
                          if (_dragNotifier.value > maxDrag * 0.75) {
                            _onSlideSuccess(maxDrag);
                          } else {
                            _resetThumb();
                          }
                        }
                      : null,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: enabled
                          ? widget.thumbColor
                          : Colors.white.withValues(alpha: 0.1),
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
