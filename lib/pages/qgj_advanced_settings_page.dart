import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart';
import '../main.dart';
import '../services/log_service.dart';
import '../services/vehicle_settings_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';

class QgjAdvancedSettingsPage extends StatefulWidget {
  const QgjAdvancedSettingsPage({super.key});

  @override
  State<QgjAdvancedSettingsPage> createState() =>
      _QgjAdvancedSettingsPageState();
}

class _QgjAdvancedSettingsPageState extends State<QgjAdvancedSettingsPage> {
  late final VehicleSettingsService _settingsService;
  VehicleAdvancedSettingsSnapshot? _snapshot;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _settingsService = VehicleSettingsService(
      connectionManager: connectionManager,
    );
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final snapshot = await _settingsService.refreshAdvancedReadOnly();
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
      _showSnack(snapshot == null ? '未读取到高级设置状态' : '高级设置已刷新', true);
    } on VehicleSettingsException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, false);
    } catch (e) {
      logService.operation(
        'QGJ 高级设置读取异常',
        detail: e.toString(),
        level: LogLevel.error,
      );
      if (!mounted) return;
      _showSnack('高级设置读取失败', false);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _copySnapshot() async {
    final snapshot = _snapshot;
    if (snapshot == null) {
      _showSnack('暂无高级设置结果', false);
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: _buildSnapshotReport(snapshot)),
    );
    if (!mounted) return;
    _showSnack('已复制高级设置结果', true);
  }

  String _buildSnapshotReport(VehicleAdvancedSettingsSnapshot snapshot) {
    final device = connectionManager.device;
    return [
      '# QGJ Advanced Settings Read-only Result',
      'Generated: ${DateTime.now().toIso8601String()}',
      'State: ${connectionManager.state.name}',
      'Protocol: ${connectionManager.protocol.name}',
      'Device: ${device?.platformName ?? 'none'}',
      'Remote ID: ${device?.remoteId.toString() ?? 'none'}',
      '',
      '## Values',
      'Auto lock: ${_switchLabel(snapshot.autoLockEnabled)}',
      'Auto lock raw seconds: ${snapshot.autoLockTimeSeconds ?? 'unread'}',
      'Power-on auto lock: ${_secondsLabel(snapshot.powerOnAutoLockTimeSeconds)}',
      'Proximity status: ${_switchLabel(snapshot.proximityEnabled)}',
      'Proximity distance: ${_levelLabel(snapshot.proximityDistance)}',
      'HID status: ${_hidLabel(snapshot.hidMode)}',
      'Handlebar lock: ${_switchLabel(snapshot.handlebarLockEnabled)}',
      'Safe lock: ${_switchLabel(snapshot.safeLockEnabled)}',
      'Kickstand: ${_switchLabel(snapshot.kickstandEnabled)}',
      'Seat sensor: ${_switchLabel(snapshot.seatSensorEnabled)}',
      'Posture detection: ${_switchLabel(snapshot.postureDetectionEnabled)}',
      '',
      '## Not Auto-read',
      'Password unlock: skipped',
      'OTA mode: blocked',
    ].join('\n');
  }

  void _showSnack(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? null : AppColors.danger,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ble.ConnectionState>(
      stream: connectionManager.stateStream,
      initialData: connectionManager.state,
      builder: (context, snapshot) {
        final connState = snapshot.data ?? ble.ConnectionState.disconnected;
        final canRefresh = connState == ble.ConnectionState.ready && !_loading;

        return Scaffold(
          backgroundColor: AppColors.pageBg,
          body: SafeArea(
            child: Column(
              children: [
                AppPageHeader(
                  title: '高级设置只读',
                  actions: [
                    IconButton(
                      tooltip: '复制结果',
                      onPressed: _snapshot == null ? null : _copySnapshot,
                      icon: const Icon(Icons.copy, size: AppIconSizes.md),
                    ),
                    _RefreshButton(
                      loading: _loading,
                      enabled: canRefresh,
                      onPressed: _refresh,
                    ),
                  ],
                ),
                ConnectionStatusBanner(
                  state: connState,
                  onScanTap: () => openScanTab(context),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      const AppSectionLabel('自动与感应'),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _ReadOnlyRow(
                              icon: Icons.lock_clock,
                              title: '自动锁车',
                              value: _switchLabel(_snapshot?.autoLockEnabled),
                              subtitle: _secondsSubtitle(
                                '原始时间',
                                _snapshot?.autoLockTimeSeconds,
                              ),
                            ),
                            const _InsetDivider(),
                            _ReadOnlyRow(
                              icon: Icons.power_settings_new,
                              title: '上电自动锁车',
                              value: _secondsLabel(
                                _snapshot?.powerOnAutoLockTimeSeconds,
                              ),
                              subtitle: '官方命令 0x2010',
                            ),
                            const _InsetDivider(),
                            _ReadOnlyRow(
                              icon: Icons.sensors,
                              title: '感应状态',
                              value: _switchLabel(_snapshot?.proximityEnabled),
                              subtitle: '官方命令 0x2030',
                            ),
                            const _InsetDivider(),
                            _ReadOnlyRow(
                              icon: Icons.social_distance_outlined,
                              title: '感应距离',
                              value: _levelLabel(_snapshot?.proximityDistance),
                              subtitle: '官方命令 0x2032',
                            ),
                            const _InsetDivider(),
                            _ReadOnlyRow(
                              icon: Icons.bluetooth_searching,
                              title: 'HID 配对状态',
                              value: _hidLabel(_snapshot?.hidMode),
                              subtitle: '官方命令 0x2142',
                            ),
                          ],
                        ),
                      ),
                      const AppSectionLabel('车辆功能'),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _ReadOnlyRow(
                              icon: Icons.lock_person_outlined,
                              title: '电子龙头锁',
                              value: _switchLabel(
                                _snapshot?.handlebarLockEnabled,
                              ),
                              subtitle: '官方命令 0x2051',
                            ),
                            const _InsetDivider(),
                            _ReadOnlyRow(
                              icon: Icons.security_outlined,
                              title: '安全锁',
                              value: _switchLabel(_snapshot?.safeLockEnabled),
                              subtitle: '官方命令 0x2361',
                            ),
                            const _InsetDivider(),
                            _ReadOnlyRow(
                              icon: Icons.sensor_occupied_outlined,
                              title: '边撑感应',
                              value: _switchLabel(_snapshot?.kickstandEnabled),
                              subtitle: '官方命令 0x2371',
                            ),
                            const _InsetDivider(),
                            _ReadOnlyRow(
                              icon: Icons.event_seat_outlined,
                              title: '坐垫感应',
                              value: _switchLabel(_snapshot?.seatSensorEnabled),
                              subtitle: '官方命令 0x2401',
                            ),
                            const _InsetDivider(),
                            _ReadOnlyRow(
                              icon: Icons.warning_amber_outlined,
                              title: '侧翻检测',
                              value: _switchLabel(
                                _snapshot?.postureDetectionEnabled,
                              ),
                              subtitle: '官方命令 0x2071',
                            ),
                          ],
                        ),
                      ),
                      const AppSectionLabel('未自动读取'),
                      const AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _ReadOnlyRow(
                              icon: Icons.key_outlined,
                              title: '密码解锁',
                              value: '未读取',
                              subtitle: '可能返回密码内容',
                            ),
                            _InsetDivider(),
                            _ReadOnlyRow(
                              icon: Icons.system_update_alt,
                              title: 'OTA 模式入口',
                              value: '禁止触发',
                              subtitle: '官方命令 0x5004',
                            ),
                          ],
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
}

class _RefreshButton extends StatelessWidget {
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  const _RefreshButton({
    required this.loading,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(right: 8),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      tooltip: '刷新',
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.refresh),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _ReadOnlyRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != '未读取';
    final color = hasValue ? AppColors.primary : AppColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: AppIconSizes.md),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
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
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsetDivider extends StatelessWidget {
  const _InsetDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      color: AppColors.border,
    );
  }
}

String _switchLabel(bool? value) {
  if (value == null) return '未读取';
  return value ? '开启' : '关闭';
}

String _secondsLabel(int? seconds) {
  if (seconds == null) return '未读取';
  if (seconds == 0) return '0 秒';
  if (seconds % 60 == 0) return '${seconds ~/ 60} 分钟';
  return '$seconds 秒';
}

String _secondsSubtitle(String label, int? seconds) {
  if (seconds == null) return '官方命令 0x2000';
  return '$label ${seconds.toString()} 秒';
}

String _levelLabel(int? value) {
  if (value == null) return '未读取';
  return '$value 档';
}

String _hidLabel(int? mode) {
  return switch (mode) {
    QgjHidModes.close => '关闭',
    QgjHidModes.open => '开启',
    QgjHidModes.openWithAutoLock => '自动锁',
    null => '未读取',
    _ => '未知 $mode',
  };
}
