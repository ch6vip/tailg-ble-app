import 'package:flutter/material.dart';

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
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('云端 Token'),
            subtitle: const Text('与 Web 端共享连接凭证'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          const _SectionHeader('协议'),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('协议类型'),
            subtitle: const Text('自动识别'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
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
