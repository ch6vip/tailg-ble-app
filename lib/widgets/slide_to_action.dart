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
  double _dragPosition = 0;
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _resetAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
    );
    _resetController.addListener(() {
      setState(() => _dragPosition = _resetAnimation.value);
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chevron_right,
                        color: Colors.white54.withValues(
                            alpha: 0.5 * (1 - _dragPosition / maxDrag)),
                        size: 20),
                    Icon(Icons.chevron_right,
                        color: Colors.white70.withValues(
                            alpha: 0.7 * (1 - _dragPosition / maxDrag)),
                        size: 20),
                    const SizedBox(width: 4),
                    Opacity(
                      opacity: (1 - _dragPosition / maxDrag * 2).clamp(0, 1),
                      child: Text(widget.label,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: _dragPosition + 4,
                top: 4,
                child: GestureDetector(
                  onHorizontalDragUpdate: enabled
                      ? (details) {
                          setState(() {
                            _dragPosition = (_dragPosition + details.delta.dx)
                                .clamp(0.0, maxDrag);
                          });
                        }
                      : null,
                  onHorizontalDragEnd: enabled
                      ? (details) {
                          if (_dragPosition > maxDrag * 0.75) {
                            HapticFeedback.heavyImpact();
                            widget.onSlideComplete?.call();
                          }
                          _resetAnimation = Tween<double>(
                            begin: _dragPosition,
                            end: 0,
                          ).animate(CurvedAnimation(
                              parent: _resetController, curve: Curves.easeOut));
                          _resetController.forward(from: 0);
                        }
                      : null,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.thumbColor,
                      shape: BoxShape.circle,
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
