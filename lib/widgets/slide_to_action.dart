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
  double _progress = 0;
  bool _completed = false;
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(SlideToAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label) {
      _completed = false;
      _progress = 0;
    }
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _resetThumb() {
    final startVal = _progress;
    _resetAnimation = Tween<double>(begin: startVal, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.elasticOut),
    );
    _resetAnimation.addListener(() {
      setState(() => _progress = _resetAnimation.value.clamp(0, 1));
    });
    _resetController.forward(from: 0);
  }

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
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: (1 - _progress * 2).clamp(0, 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chevron_right,
                          color: Colors.white38, size: 20),
                      const Icon(Icons.chevron_right,
                          color: Colors.white54, size: 20),
                      const SizedBox(width: 4),
                      Text(widget.label,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: _resetController.isAnimating
                    ? Duration.zero
                    : const Duration(milliseconds: 0),
                left: (_progress * maxDrag) + 4,
                top: 4,
                child: GestureDetector(
                  onHorizontalDragUpdate: enabled
                      ? (details) {
                          setState(() {
                            _progress = (_progress + details.delta.dx / maxDrag)
                                .clamp(0.0, 1.0);
                          });
                          if (_progress > 0.3 && !_completed) {
                            HapticFeedback.selectionClick();
                          }
                        }
                      : null,
                  onHorizontalDragEnd: enabled
                      ? (details) {
                          if (_progress > 0.75) {
                            HapticFeedback.heavyImpact();
                            _completed = true;
                            setState(() => _progress = 1.0);
                            widget.onSlideComplete?.call();
                            Future.delayed(const Duration(milliseconds: 800), () {
                              if (mounted) {
                                _completed = false;
                                _resetThumb();
                              }
                            });
                          } else {
                            _resetThumb();
                          }
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _progress > 0.75
                          ? Colors.white.withValues(alpha: 0.4)
                          : widget.thumbColor,
                      shape: BoxShape.circle,
                      boxShadow: _progress > 0
                          ? [BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(2, 0),
                            )]
                          : null,
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 24),
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
