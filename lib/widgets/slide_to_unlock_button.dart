import 'package:flutter/material.dart';

/// 滑动开锁组件 - 像素级还原设计图
class SlideToUnlockButton extends StatefulWidget {
  const SlideToUnlockButton({
    super.key,
    required this.onUnlocked,
    this.isLocked = true,
  });

  final VoidCallback onUnlocked;
  final bool isLocked;

  @override
  State<SlideToUnlockButton> createState() => _SlideToUnlockButtonState();
}

class _SlideToUnlockButtonState extends State<SlideToUnlockButton>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
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
    )..addListener(() {
        setState(() {
          _dragPosition = _resetAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (!widget.isLocked) return;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.isLocked) return;
    setState(() {
      _dragPosition += details.delta.dx;
      _dragPosition = _dragPosition.clamp(0.0, _maxDragDistance);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.isLocked) return;

    // 滑动超过 80% 即解锁
    if (_dragPosition > _maxDragDistance * 0.8) {
      widget.onUnlocked();
      setState(() {
        _dragPosition = _maxDragDistance;
      });
    } else {
      // 回弹动画
      _resetAnimation = Tween<double>(
        begin: _dragPosition,
        end: 0.0,
      ).animate(
        CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
      );
      // AnimationController.forward returns a TickerFuture we intentionally
      // ignore; the listener already drives setState.
      _resetController.forward(from: 0);
    }
  }

  double get _maxDragDistance => 152.0; // 240px宽度 - 88px按钮

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 240,
          height: 88,
          child: Stack(
            children: [
              // 背景轨道
              Container(
                width: 240,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE8E8E8),
                      const Color(0xFFF5F5F5),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(44),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildArrow(),
                      const SizedBox(width: 4),
                      _buildArrow(),
                      const SizedBox(width: 4),
                      _buildArrow(),
                    ],
                  ),
                ),
              ),
              // 滑动按钮
              Positioned(
                left: _dragPosition,
                child: GestureDetector(
                  onHorizontalDragStart: _onHorizontalDragStart,
                  onHorizontalDragUpdate: _onHorizontalDragUpdate,
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.isLocked ? Icons.lock_outline : Icons.lock_open,
                      size: 32,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '滑动开锁',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF666666),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildArrow() {
    return Icon(
      Icons.chevron_right,
      size: 24,
      color: const Color(0xFFCCCCCC),
    );
  }
}
