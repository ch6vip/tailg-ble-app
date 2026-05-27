import 'package:flutter/material.dart';
import '../services/proximity_service.dart';
import '../services/auto_connect_service.dart';
import 'log_page.dart';
import 'vehicle_settings_page.dart';
import 'diagnostic_page.dart';

const _pageBg = Color(0xFFF5F6FA);
const _primary = Color(0xFF1E88E5);
const _textPrimary = Color(0xFF1A1A2E);
const _textTertiary = Color(0xFF999999);

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                '设置',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ),
            _sectionLabel('连接'),
            StreamBuilder<bool>(
              stream: AutoConnectService().enabledStream,
              initialData: AutoConnectService().enabled,
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? false;
                return _settingItem(
                  icon: Icons.bluetooth,
                  title: '自动连接',
                  subtitle: enabled
                      ? '打开 app 时自动连接上次的设备'
                      : '关闭',
                  trailing: _buildToggle(enabled, (v) {
                    AutoConnectService().setEnabled(v);
                  }),
                );
              },
            ),
            StreamBuilder<bool>(
              stream: ProximityService().enabledStream,
              initialData: ProximityService().enabled,
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? false;
                return _settingItem(
                  icon: Icons.sensors,
                  title: '感应解锁',
                  subtitle: enabled
                      ? '靠近车辆时自动解锁（RSSI > -75dBm）'
                      : '关闭',
                  trailing: _buildToggle(enabled, (v) {
                    ProximityService().setEnabled(v);
                  }),
                );
              },
            ),
            _settingItem(
              icon: Icons.cloud_outlined,
              title: '云端 Token',
              subtitle: '与 Web 端共享连接凭证',
            ),
            _divider(),
            _sectionLabel('车辆'),
            _settingItem(
              icon: Icons.tune,
              title: '灯光与声音',
              subtitle: '前灯、转向灯、提示音设置',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VehicleSettingsPage()),
              ),
            ),
            _settingItem(
              icon: Icons.swap_horiz,
              title: '协议类型',
              subtitle: '自动识别',
            ),
            _divider(),
            _sectionLabel('调试'),
            _settingItem(
              icon: Icons.health_and_safety,
              title: '故障诊断',
              subtitle: '读取车辆错误码',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiagnosticPage()),
              ),
            ),
            _settingItem(
              icon: Icons.article_outlined,
              title: '日志',
              subtitle: '查看 BLE 通信和操作记录',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogPage()),
              ),
            ),
            _divider(),
            _sectionLabel('关于'),
            _settingItem(
              icon: Icons.info_outline,
              title: '版本',
              subtitle: '1.0.0',
              showChevron: false,
            ),
            _settingItem(
              icon: Icons.code,
              title: 'GitHub',
              subtitle: 'ch6vip/tailg-ble-app',
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _primary,
        ),
      ),
    );
  }

  Widget _settingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Icon(icon, size: 22, color: _textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle,
                        style:
                            const TextStyle(fontSize: 12, color: _textTertiary)),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (showChevron)
              Icon(Icons.chevron_right,
                  size: 20, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: value ? _primary : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(13),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Color(0xFFEEEEEE)),
    );
  }
}
