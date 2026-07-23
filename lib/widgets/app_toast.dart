import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';
import 'package:tailg_ble_app/theme/app_motion.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';
import 'package:tailg_ble_app/widgets/lucide_icon.dart';

/// Global unified Toast — slides down from the top of the screen.
///
/// Usage from anywhere (no BuildContext needed):
/// ```dart
/// AppToast.show('已通电');
/// AppToast.show('操作失败', isError: true);
/// ```
///
/// Aligns with v8 `.toast` HTML design:
/// - Teal background (success) / Red background (error)
/// - Slides in from top in ~300ms, auto-dismisses after 1.8s
class AppToast {
  static OverlayEntry? _entry;
  static bool _showing = false;
  static Timer? _dismissTimer;

  /// Show a toast at the top of the current screen.
  ///
  /// If a toast is already showing, it will be replaced immediately.
  static void show(String message, {bool isError = false}) {
    // Dismiss any existing toast first
    dismiss();

    final overlay = _rootKey.currentState?.overlay;
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        isError: isError,
        onDismissed: dismiss,
      ),
    );

    _entry = entry;
    overlay.insert(entry);
    _showing = true;

    // Auto-dismiss after 1.8 seconds via cancellable Timer
    _dismissTimer?.cancel();
    _dismissTimer = Timer(AppMotion.toastVisible, () {
      if (_showing && _entry == entry) {
        dismiss();
      }
    });
  }

  /// Dismiss the current toast with animation.
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (!_showing) return;
    _showing = false;
    _entry?.remove();
    _entry = null;
  }

  // Global key for accessing overlay from anywhere.
  static final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>();
  static GlobalKey<NavigatorState> get navigatorKey => _rootKey;
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.isError,
    required this.onDismissed,
  });

  final String message;
  final bool isError;
  final VoidCallback onDismissed;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppMotion.toastEntrance);
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: AppMotion.entranceCurve));
    _fade = Tween(begin: 0.0, end: 1.0).animate(_ctrl);
    unawaited(_ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bg => widget.isError ? AppColors.energyRed : AppColors.energyGreen;

  Color get _fg => widget.isError ? Colors.white : Colors.black;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 12,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.only(left: 18, right: 4),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(AppRadii.md),
                boxShadow: [
                  BoxShadow(
                    color: _bg.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isError ? Lucide.x : Lucide.checkCircle,
                    color: _fg,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: _fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AppPressable(
                    key: const ValueKey('app-toast-dismiss'),
                    onTap: widget.onDismissed,
                    haptic: false,
                    semanticsLabel: '关闭提示',
                    semanticsButton: true,
                    semanticsEnabled: true,
                    child: SizedBox(
                      width: AppTouchTargets.min,
                      height: AppTouchTargets.min,
                      child: Center(
                        child: Icon(
                          Lucide.x,
                          color: _fg.withValues(alpha: 0.7),
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
