import 'package:flutter/material.dart';
import '../services/proximity_service.dart';
import 'log_page.dart';
import 'vehicle_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          const _SectionHeader('连接'),
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('自动连接'),
            subtitle: const Text('打开 app 时自动连接上次的设备'),
            trailing: Switch(value: false, onChanged: (v) {}),
          ),
          StreamBuilder<bool>(
            stream: ProximityService().enabledStream,
            initialData: ProximityService().enabled,
            builder: (context, snapshot) {
              final enabled = snapshot.data ?? false;
              return ListTile(
                leading: const Icon(Icons.sensors),
                title: const Text('感应解锁'),
                subtitle: Text(enabled
                    ? '靠近车辆时自动解锁（RSSI > -75dBm）'
                    : '关闭'),
                trailing: Switch(
                  value: enabled,
                  onChanged: (v) => ProximityService().setEnabled(v),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('云端 Token'),
            subtitle: const Text('与 Web 端共享连接凭证'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          const _SectionHeader('车辆'),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('灯光与声音'),
            subtitle: const Text('前灯、转向灯、提示音设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VehicleSettingsPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('协议类型'),
            subtitle: const Text('自动识别'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          const _SectionHeader('调试'),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('日志'),
            subtitle: const Text('查看 BLE 通信和操作记录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogPage()),
            ),
          ),
          const Divider(),
          const _SectionHeader('关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('GitHub'),
            subtitle: const Text('ch6vip/tailg-ble-app'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
