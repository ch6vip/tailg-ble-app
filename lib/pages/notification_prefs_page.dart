import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_snack.dart';

class NotificationPrefsPage extends StatefulWidget {
  const NotificationPrefsPage({super.key});

  @override
  State<NotificationPrefsPage> createState() => _NotificationPrefsPageState();
}

class _NotificationPrefsPageState extends State<NotificationPrefsPage> {
  Map<String, bool> _config = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await officialCloudService.getMessageControl();
      if (mounted) {
        setState(() {
          _config = config;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败';
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await officialCloudService.setMessagePushConfig(_config);
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.success(context, '通知偏好已保存');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnack.error(context, '保存失败，请重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.officialPageBg,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '通知偏好'),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_config.isEmpty) {
      return const Center(
        child: Text('暂无可配置项', style: AppTextStyles.bodyMedium),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: _config.entries.map((entry) {
              return SwitchListTile(
                title: Text(
                  _labelFor(entry.key),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                value: entry.value,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => setState(() => _config[entry.key] = v),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('保存', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  static String _labelFor(String key) {
    const labels = {
      'carMsg': '车辆消息通知',
      'sysMsg': '系统消息通知',
      'alarm': '报警通知',
      'fence': '围栏通知',
      'lowBattery': '低电量提醒',
      'maintenance': '保养提醒',
    };
    return labels[key] ?? key;
  }
}
