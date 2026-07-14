import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 统一的 SnackBar 提示封装，避免 30+ 处 ScaffoldMessenger 调用散落各页。
///
/// 调用：
///   AppSnack.error(context, '连接失败，请稍后重试');
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
    final scheme = Theme.of(context).colorScheme;
    _show(
      context,
      message: message,
      background: scheme.error,
      foreground: scheme.onError,
      icon: Icons.error_outline,
      duration: _errorDuration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// 成功提示：绿色背景，2s 停留。
  static void success(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    _show(
      context,
      message: message,
      background: scheme.primary,
      foreground: scheme.onPrimary,
      icon: Icons.check_circle_outline,
      duration: _infoDuration,
    );
  }

  /// 普通提示：深灰背景，2s 停留。
  static void info(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    _show(
      context,
      message: message,
      background: scheme.inverseSurface,
      foreground: scheme.onInverseSurface,
      icon: Icons.info_outline,
      duration: _infoDuration,
    );
  }

  /// Placeholder / not-yet-open feature entry (cloud-only product boundary).
  ///
  /// [label] is the feature name shown before the fixed suffix, e.g.
  /// `导航投屏` → `导航投屏暂未开放，可先使用官方云端控车`.
  static void featureUnavailable(BuildContext context, String label) {
    info(context, '$label暂未开放，可先使用官方云端控车');
  }

  /// Short not-yet-open notice for legal/support entries without a cloud fallback.
  ///
  /// e.g. `用户协议` → `用户协议暂未开放`.
  static void notYetOpen(BuildContext context, String label) {
    info(context, '$label暂未开放');
  }

  static void _show(
    BuildContext context, {
    required String message,
    required Color background,
    required Color foreground,
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
            Icon(icon, size: AppIconSizes.sm, color: foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foreground,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        margin: const EdgeInsets.all(16),
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                textColor: foreground,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}
