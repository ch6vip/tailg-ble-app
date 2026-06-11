import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 统一的 SnackBar 提示封装，避免 30+ 处 ScaffoldMessenger 调用散落各页。
///
/// 调用：
///   AppSnack.error(context, '连接失败：$e');
///   AppSnack.success(context, '已保存');
///   AppSnack.info(context, '正在重新连接...');
abstract final class AppSnack {
  static const _errorDuration = Duration(seconds: 3);
  static const _infoDuration = Duration(seconds: 2);

  /// 错误提示：红色背景，长时间停留 3s。
  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      message: message,
      background: const Color(0xFFFF5252),
      icon: Icons.error_outline,
      duration: _errorDuration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// 成功提示：绿色背景，2s 停留。
  static void success(BuildContext context, String message) {
    _show(
      context,
      message: message,
      background: const Color(0xFF4CAF50),
      icon: Icons.check_circle_outline,
      duration: _infoDuration,
    );
  }

  /// 普通提示：深灰背景，2s 停留。
  static void info(BuildContext context, String message) {
    _show(
      context,
      message: message,
      background: const Color(0xFF323232),
      icon: Icons.info_outline,
      duration: _infoDuration,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required Color background,
    required IconData icon,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, size: AppIconSizes.sm, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: background,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}
