import 'package:flutter/material.dart';
import '../services/proximity_service.dart';
import '../services/auto_connect_service.dart';
import '../services/app_preferences_service.dart';
import '../theme/app_colors.dart';
import 'app_preferences_pages.dart';
import 'log_page.dart';
import 'vehicle_settings_page.dart';
import 'diagnostic_page.dart';
import 'official_cloud_page.dart';
import 'garage_page.dart';
import 'battery_details_page.dart';
import 'device_info_page.dart';
import 'ota_precheck_page.dart';
import 'vehicle_message_page.dart';

const _textPrimary = Color(0xFF1A1A2E);
const _textTertiary = Color(0xFF999999);

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _preferences = AppPreferencesService();

  @override
  void initState() {
    super.initState();
    _preferences.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppNav.contentBottomPadding),
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
                  subtitle: enabled ? '打开 app 时自动连接上次的设备' : '关闭',
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
                  subtitle: enabled ? '靠近车辆时自动解锁（RSSI > -75dBm）' : '关闭',
                  trailing: _buildToggle(enabled, (v) {
                    ProximityService().setEnabled(v);
                  }),
                );
              },
            ),
            _divider(),
            _sectionLabel('通用'),
            StreamBuilder<AppLanguagePreference>(
              stream: _preferences.languageStream,
              initialData: _preferences.language,
              builder: (context, snapshot) {
                return _settingItem(
                  icon: Icons.language,
                  title: '语言设置',
                  subtitle: snapshot.data?.label ?? '跟随系统',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LanguageSettingsPage(),
                    ),
                  ),
                );
              },
            ),
            StreamBuilder<DistanceUnitPreference>(
              stream: _preferences.distanceUnitStream,
              initialData: _preferences.distanceUnit,
              builder: (context, snapshot) {
                final unit = snapshot.data ?? DistanceUnitPreference.metric;
                return _settingItem(
                  icon: Icons.straighten,
                  title: '单位设置',
                  subtitle: '${unit.label} · ${unit.hint}',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UnitSettingsPage()),
                  ),
                );
              },
            ),
            StreamBuilder<bool>(
              stream: _preferences.respectTextScaleStream,
              initialData: _preferences.respectSystemTextScale,
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? true;
                return _settingItem(
                  icon: Icons.text_fields,
                  title: '跟随系统字号',
                  subtitle: enabled ? '允许系统字号设置生效（限 0.9-1.3 倍）' : '关闭后忽略系统字号',
                  trailing: _buildToggle(enabled, (v) {
                    _preferences.setRespectSystemTextScale(v);
                  }),
                );
              },
            ),
            _divider(),
            _sectionLabel('车辆'),
            _settingItem(
              icon: Icons.garage_outlined,
              title: '我的车库',
              subtitle: '绑定车辆、默认车辆、多车管理',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GaragePage()),
              ),
            ),
            _settingItem(
              icon: Icons.tune,
              title: '车辆设置',
              subtitle: '声音、灵敏度、车辆功能、骑行设置',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VehicleSettingsPage()),
              ),
            ),
            _settingItem(
              icon: Icons.directions_bike_outlined,
              title: '车辆信息',
              subtitle: '车辆档案、蓝牙设备、服务和固件信息',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DeviceInfoPage()),
              ),
            ),
            _settingItem(
              icon: Icons.mark_email_unread_outlined,
              title: '消息中心',
              subtitle: '系统消息、设备消息和安全提醒',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VehicleMessagePage()),
              ),
            ),
            _settingItem(
              icon: Icons.battery_charging_full,
              title: '电池/BMS',
              subtitle: '电量、电压、温度、故障和预留 BMS 数据',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BatteryDetailsPage()),
              ),
            ),
            _divider(),
            _sectionLabel('高级'),
            _settingItem(
              icon: Icons.system_update_alt,
              title: 'OTA 前置检测',
              subtitle: '协议、设备信息、固件版本和升级风险检查',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OtaPrecheckPage()),
              ),
            ),
            _settingItem(
              icon: Icons.swap_horiz,
              title: '协议类型',
              subtitle: '自动识别',
              onTap: () => _showProtocolDialog(),
            ),
            _settingItem(
              icon: Icons.cloud_outlined,
              title: '官方账号',
              subtitle: '登录官方账号、车辆列表、云端控车',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OfficialCloudPage()),
              ),
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
              title: '关于 Tailg BLE',
              subtitle: '版本、开源依赖、诊断导出',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutAppPage()),
              ),
            ),
            _settingItem(
              icon: Icons.code,
              title: 'GitHub',
              subtitle: 'ch6vip/tailg-ble-app',
              showChevron: false,
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
          color: AppColors.primary,
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (showChevron)
              Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
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
          color: value ? AppColors.primary : AppColors.border,
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

  void _showProtocolDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择协议类型'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        children: [
          _protocolOption('自动识别', '根据服务 UUID 自动判断', true),
          _protocolOption('Standard (fee5)', '标准台铃协议', false),
          _protocolOption('QGJ (feb0)', '骑管家协议', false),
        ],
      ),
    );
  }

  Widget _protocolOption(String title, String subtitle, bool selected) {
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? AppColors.primary : _textTertiary,
      ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: _textTertiary),
      ),
      onTap: () => Navigator.pop(context),
    );
  }
}
