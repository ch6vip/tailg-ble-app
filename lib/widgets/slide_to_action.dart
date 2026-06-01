import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class SlideToAction extends StatefulWidget {
  final VoidCallback? onSlideComplete;
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color thumbColor;
  final bool reverseSlide;
  final bool enabled;
  final bool loading;
  final String loadingLabel;
  final VoidCallback? onDisabledTap;

  const SlideToAction({
    super.key,
    this.onSlideComplete,
    this.label = '右滑启动',
    this.icon = Icons.lock_outline,
    this.backgroundColor = const Color(0xFF424242),
    this.thumbColor = const Color(0x40FFFFFF),
    this.reverseSlide = false,
    this.enabled = true,
    this.loading = false,
    this.loadingLabel = '发送中',
    this.onDisabledTap,
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
      duration: const Duration(milliseconds: 200),
    );
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void didUpdateWidget(SlideToAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label ||
        oldWidget.reverseSlide != widget.reverseSlide ||
        oldWidget.loading != widget.loading) {
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
    if (startVal <= 0) {
      _dragNotifier.value = 0;
      return;
    }
    _resetController.stop();
    _resetController.reset();
    final anim = Tween<double>(begin: startVal, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.elasticOut),
    );
    anim.addListener(() {
      _dragNotifier.value = anim.value;
    });
    _resetController.forward();
  }

  /// 根据 backgroundColor 亮度自适应 thumb 颜色：
  /// 浅色背景用半透明深色，深色背景用半透明白色。
  /// 保证 thumb 在白底/深底上都能看到。
  Color _resolvedThumbColor(BuildContext context) {
    final isDarkBg = widget.backgroundColor.computeLuminance() < 0.5;
    if (isDarkBg) return widget.thumbColor;
    return Colors.black.withValues(alpha: 0.18);
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        widget.enabled && widget.onSlideComplete != null && !widget.loading;
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
                          color: AppColors.success.withValues(
                            alpha: glowOpacity * 0.4,
                          ),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: child,
            );
          },
          child: Semantics(
            slider: true,
            label: widget.label,
            hint: '右滑以执行',
            enabled: enabled,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? null : widget.onDisabledTap,
              child: Stack(
                children: [
                  ValueListenableBuilder<double>(
                    valueListenable: _dragNotifier,
                    builder: (context, pos, _) {
                      final progress = maxDrag > 0 ? pos / maxDrag : 0.0;
                      if (widget.loading) {
                        return Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.loadingLabel,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final progressAlpha = (1 - progress * 1.8).clamp(
                        0.0,
                        1.0,
                      );
                      return Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chevron_right,
                              textDirection: widget.reverseSlide
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              color: Colors.white.withValues(
                                alpha: 0.5 * progressAlpha,
                              ),
                              size: 18,
                            ),
                            Icon(
                              Icons.chevron_right,
                              textDirection: widget.reverseSlide
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              color: Colors.white.withValues(
                                alpha: 0.5 * progressAlpha,
                              ),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.label,
                              style: TextStyle(
                                color: Colors.white.withValues(
                                  alpha: 0.6 * progressAlpha,
                                ),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  ValueListenableBuilder<double>(
                    valueListenable: _dragNotifier,
                    builder: (context, pos, child) {
                      return Positioned(
                        left: (widget.reverseSlide ? maxDrag - pos : pos) + 4,
                        top: 4,
                        child: child!,
                      );
                    },
                    child: GestureDetector(
                      onHorizontalDragUpdate: enabled
                          ? (details) {
                              final prev = _dragNotifier.value;
                              final delta = widget.reverseSlide
                                  ? -details.delta.dx
                                  : details.delta.dx;
                              _dragNotifier.value =
                                  (_dragNotifier.value + delta).clamp(
                                    0.0,
                                    maxDrag,
                                  );
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
                              ? _resolvedThumbColor(context)
                              : _resolvedThumbColor(
                                  context,
                                ).withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: widget.loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(widget.icon, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
