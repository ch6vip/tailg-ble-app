import 'package:flutter/material.dart';
import '../main.dart'; // P0-6: service locator getters
import '../services/app_preferences_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
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

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    // AppPreferencesService is already initialized in main().
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
              child: Text('设置', style: AppTextStyles.pageTitle),
            ),
            const AppSectionLabel('连接'),
            _group(const [
              _AutoConnectSettingTile(),
              _ProximityUnlockSettingTile(),
            ]),
            const AppSectionLabel('通用'),
            _group(const [
              _LanguageSettingTile(),
              _DistanceUnitSettingTile(),
              _RespectTextScaleSettingTile(),
            ]),
            const AppSectionLabel('车辆'),
            _group([
              _settingItem(
                icon: Icons.garage_outlined,
                title: '我的车库',
                subtitle: '绑定车辆、默认车辆、多车管理',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const GaragePage()),
                ),
              ),
              _settingItem(
                icon: Icons.tune,
                title: '车辆设置',
                subtitle: '声音、灵敏度、车辆功能、骑行设置',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const VehicleSettingsPage(),
                  ),
                ),
              ),
              _settingItem(
                icon: Icons.directions_bike_outlined,
                title: '车辆信息',
                subtitle: '车辆档案、蓝牙设备、服务和固件信息',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const DeviceInfoPage(),
                  ),
                ),
              ),
              _settingItem(
                icon: Icons.mark_email_unread_outlined,
                title: '消息中心',
                subtitle: '系统消息、设备消息和安全提醒',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const VehicleMessagePage(),
                  ),
                ),
              ),
              _settingItem(
                icon: Icons.battery_charging_full,
                title: '电池/BMS',
                subtitle: '电量、电压、温度、故障和预留 BMS 数据',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const BatteryDetailsPage(),
                  ),
                ),
              ),
            ]),
            const AppSectionLabel('高级'),
            _group([
              _settingItem(
                icon: Icons.system_update_alt,
                title: 'OTA 前置检测',
                subtitle: '协议、设备信息、固件版本和升级风险检查',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const OtaPrecheckPage(),
                  ),
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
                  MaterialPageRoute<void>(
                    builder: (_) => const OfficialCloudPage(),
                  ),
                ),
              ),
            ]),
            const AppSectionLabel('调试'),
            _group([
              _settingItem(
                icon: Icons.health_and_safety_outlined,
                title: '故障诊断',
                subtitle: '读取车辆错误码',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const DiagnosticPage(),
                  ),
                ),
              ),
              _settingItem(
                icon: Icons.article_outlined,
                title: '日志',
                subtitle: '查看 BLE 通信和操作记录',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const LogPage()),
                ),
              ),
            ]),
            const AppSectionLabel('关于'),
            _group([
              _settingItem(
                icon: Icons.info_outline,
                title: '关于 Tailg BLE',
                subtitle: '版本、开源依赖、诊断导出',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const AboutAppPage()),
                ),
              ),
              _settingItem(
                icon: Icons.code,
                title: 'GitHub',
                subtitle: 'ch6vip/tailg-ble-app',
                showChevron: false,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _showProtocolDialog() {
    showDialog<void>(
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
        color: selected ? AppColors.primary : AppColors.textTertiary,
      ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(subtitle, style: AppTextStyles.caption),
      onTap: () => Navigator.pop(context),
    );
  }
}

Widget _group(List<Widget> rows) {
  final children = <Widget>[];
  for (var i = 0; i < rows.length; i++) {
    if (i > 0) children.add(_insetDivider());
    children.add(rows[i]);
  }
  return AppCard(
    padding: EdgeInsets.zero,
    child: Column(children: children),
  );
}

Widget _insetDivider() {
  return const Divider(
    height: 1,
    thickness: 1,
    indent: 66,
    color: AppColors.border,
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
  final row = Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.itemTitle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.caption),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (showChevron)
              const Icon(
                Icons.chevron_right,
                size: 22,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    ),
  );
  if (onTap == null) return row;
  return Semantics(
    label: subtitle == null ? title : '$title，$subtitle',
    button: true,
    enabled: true,
    onTap: onTap,
    child: ExcludeSemantics(child: row),
  );
}

Widget _buildToggle({
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final toggle = Switch(
    value: value,
    onChanged: onChanged,
    activeColor: Colors.white,
    activeTrackColor: AppColors.primary,
    inactiveThumbColor: Colors.white,
    inactiveTrackColor: AppColors.border,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  return Semantics(
    container: true,
    label: label,
    enabled: true,
    toggled: value,
    onTap: () => onChanged(!value),
    child: ExcludeSemantics(child: toggle),
  );
}

class _AutoConnectSettingTile extends StatelessWidget {
  const _AutoConnectSettingTile();

  static final _service = autoConnectService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _service.enabledStream,
      initialData: _service.enabled,
      builder: (context, snapshot) {
        final enabled = snapshot.data ?? false;
        return _settingItem(
          icon: Icons.bluetooth_outlined,
          title: '自动连接',
          subtitle: enabled ? '打开 app 时自动连接上次的设备' : '关闭',
          trailing: _buildToggle(
            label: '自动连接开关',
            value: enabled,
            onChanged: _service.setEnabled,
          ),
        );
      },
    );
  }
}

class _ProximityUnlockSettingTile extends StatelessWidget {
  const _ProximityUnlockSettingTile();

  static final _service = proximityService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _service.enabledStream,
      initialData: _service.enabled,
      builder: (context, snapshot) {
        final enabled = snapshot.data ?? false;
        return _settingItem(
          icon: Icons.sensors_outlined,
          title: '感应解锁',
          subtitle: enabled ? '靠近车辆时自动解锁（RSSI > -75dBm）' : '关闭',
          trailing: _buildToggle(
            label: '感应解锁开关',
            value: enabled,
            onChanged: _service.setEnabled,
          ),
        );
      },
    );
  }
}

class _LanguageSettingTile extends StatelessWidget {
  const _LanguageSettingTile();

  static final _prefs = appPreferencesService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppLanguagePreference>(
      stream: _prefs.languageStream,
      initialData: _prefs.language,
      builder: (context, snapshot) {
        return _settingItem(
          icon: Icons.language_outlined,
          title: '语言设置',
          subtitle: snapshot.data?.label ?? '跟随系统',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const LanguageSettingsPage(),
            ),
          ),
        );
      },
    );
  }
}

class _DistanceUnitSettingTile extends StatelessWidget {
  const _DistanceUnitSettingTile();

  static final _prefs = appPreferencesService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DistanceUnitPreference>(
      stream: _prefs.distanceUnitStream,
      initialData: _prefs.distanceUnit,
      builder: (context, snapshot) {
        final unit = snapshot.data ?? DistanceUnitPreference.metric;
        return _settingItem(
          icon: Icons.straighten,
          title: '单位设置',
          subtitle: '${unit.label} · ${unit.hint}',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const UnitSettingsPage()),
          ),
        );
      },
    );
  }
}

class _RespectTextScaleSettingTile extends StatelessWidget {
  const _RespectTextScaleSettingTile();

  static final _prefs = appPreferencesService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _prefs.respectTextScaleStream,
      initialData: _prefs.respectSystemTextScale,
      builder: (context, snapshot) {
        final enabled = snapshot.data ?? true;
        return _settingItem(
          icon: Icons.text_fields,
          title: '跟随系统字号',
          subtitle: enabled ? '允许系统字号设置生效（限 0.9-1.3 倍）' : '关闭后忽略系统字号',
          trailing: _buildToggle(
            label: '跟随系统字号开关',
            value: enabled,
            onChanged: _prefs.setRespectSystemTextScale,
          ),
        );
      },
    );
  }
}
