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
    this.label = '滑动执行',
    this.icon = Icons.lock_outline,
    this.backgroundColor = const Color(0xFF424242),
    this.thumbColor = const Color(0xFF2D2D2D),
    this.reverseSlide = false,
    this.enabled = true,
    this.loading = false,
    this.loadingLabel = '执行中',
    this.onDisabledTap,
  });

  @override
  State<SlideToAction> createState() => _SlideToActionState();
}

class _SlideToActionState extends State<SlideToAction>
    with TickerProviderStateMixin {
  static const _thumbSize = 48.0;
  static const _thumbRadius = 12.0;
  static const _height = 56.0;
  static const _trackInset = 4.0;
  static const _thumbGap = 8.0;

  final _dragNotifier = ValueNotifier<double>(0);
  late AnimationController _resetController;
  late AnimationController _successController;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
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
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    anim.addListener(() {
      _dragNotifier.value = anim.value;
    });
    _resetController.forward();
  }

  /// 把 thumb 当前 left 折算成 0..1 的进度。
  double _progressFor(double left, double maxDrag) {
    if (maxDrag <= 0) return 0.0;
    return (left / maxDrag).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        widget.enabled && widget.onSlideComplete != null && !widget.loading;
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final maxDrag = trackWidth - _thumbSize - (_trackInset * 2);
        final chevronTextColor = widget.backgroundColor.computeLuminance() < 0.5
            ? Colors.white.withValues(alpha: 0.6)
            : AppColors.textTertiary;
        final labelColor = widget.backgroundColor.computeLuminance() < 0.5
            ? Colors.white
            : AppColors.textPrimary;

        return Semantics(
          slider: true,
          label: widget.label,
          hint: widget.reverseSlide ? '左滑以执行' : '右滑以执行',
          enabled: enabled,
          child: SizedBox(
            height: _height,
            child: Stack(
              children: [
                // 背景轨道：保持 backgroundColor；透明圆角让外层卡片显出
                AnimatedBuilder(
                  animation: _successController,
                  builder: (context, child) {
                    final successValue = _successController.value;
                    final glowOpacity = successValue < 0.5
                        ? successValue * 2
                        : (1 - successValue) * 2;
                    return Container(
                      decoration: BoxDecoration(
                        color: enabled
                            ? widget.backgroundColor
                            : widget.backgroundColor.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(_thumbRadius),
                        boxShadow: glowOpacity > 0
                            ? [
                                BoxShadow(
                                  color: AppColors.success.withValues(
                                    alpha: glowOpacity * 0.5,
                                  ),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    );
                  },
                ),

                // 右侧 label 永远可见
                if (!widget.loading)
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: enabled
                              ? labelColor
                              : labelColor.withValues(alpha: 0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                // 跟 thumb 走的 chevron 提示
                if (!widget.loading)
                  ValueListenableBuilder<double>(
                    valueListenable: _dragNotifier,
                    builder: (context, pos, _) {
                      final left = widget.reverseSlide
                          ? (maxDrag - pos) + _trackInset
                          : pos + _trackInset;
                      final progress = _progressFor(pos, maxDrag);
                      // 拖动过半时 chevron 淡出，让 thumb 单独承担前进感
                      final chevronAlpha = (1 - progress * 1.4).clamp(0.0, 1.0);
                      return Positioned(
                        left: left + _thumbSize + _thumbGap,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: chevronTextColor.withValues(
                                    alpha: chevronAlpha,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: chevronTextColor.withValues(
                                    alpha: chevronAlpha,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // 拖动 thumb
                if (!widget.loading)
                  ValueListenableBuilder<double>(
                    valueListenable: _dragNotifier,
                    builder: (context, pos, child) {
                      final left = widget.reverseSlide
                          ? (maxDrag - pos) + _trackInset
                          : pos + _trackInset;
                      return Positioned(
                        left: left,
                        top: _trackInset,
                        child: child!,
                      );
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: enabled ? null : widget.onDisabledTap,
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
                      child: _buildThumb(enabled),
                    ),
                  ),

                // loading 态：thumb 居中显示 spinner，label 仍可见
                if (widget.loading)
                  Positioned.fill(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.loadingLabel,
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumb(bool enabled) {
    return Container(
      width: _thumbSize,
      height: _thumbSize,
      decoration: BoxDecoration(
        color: enabled
            ? widget.thumbColor
            : widget.thumbColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(_thumbRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
    );
  }
}
