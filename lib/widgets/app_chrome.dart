import 'package:flutter/material.dart';
import '../ble/connection_manager.dart' as ble;
import '../theme/app_colors.dart';

class AppPageHeader extends StatelessWidget {
  final String title;
  final bool showBack;
  final List<Widget> actions;

  const AppPageHeader({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 0),
      child: Row(
        children: [
          if (showBack) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(title, style: AppTextStyles.subPageTitle)),
          ...actions,
        ],
      ),
    );
  }
}

class AppSectionLabel extends StatelessWidget {
  final String text;

  const AppSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(text, style: AppTextStyles.sectionLabel),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Color color;

  const AppCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpacing.screenX),
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AppHeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  const AppHeaderAction({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class ConnectionStatusBanner extends StatelessWidget {
  final ble.ConnectionState state;
  final VoidCallback? onScanTap;

  const ConnectionStatusBanner({
    super.key,
    required this.state,
    this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    final ready = state == ble.ConnectionState.ready;
    final connecting =
        state == ble.ConnectionState.connecting ||
        state == ble.ConnectionState.reconnecting;
    final color = ready
        ? AppColors.success
        : connecting
        ? AppColors.warning
        : AppColors.textTertiary;
    final title = switch (state) {
      ble.ConnectionState.ready => '车辆已连接',
      ble.ConnectionState.connecting => '正在连接车辆',
      ble.ConnectionState.reconnecting => '正在重连车辆',
      ble.ConnectionState.connected => '已连接，等待协议就绪',
      ble.ConnectionState.disconnected => '车辆未连接',
    };
    final subtitle = ready
        ? '可以读取状态并写入车辆设置'
        : connecting
        ? '请保持手机靠近车辆'
        : '连接车辆后才能执行此页面操作';

    return AppCard(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: color.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              ready ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!ready && onScanTap != null)
            TextButton(onPressed: onScanTap, child: const Text('去扫描')),
        ],
      ),
    );
  }
}
