import 'package:flutter/material.dart';
import '../main.dart';
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
            const AppSectionLabel('账号与车辆'),
            _group([
              _settingItem(
                icon: Icons.cloud_outlined,
                title: '我的车辆',
                subtitle: '登录账号、车辆列表、远程控车',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const OfficialCloudPage(),
                  ),
                ),
              ),
              _settingItem(
                icon: Icons.garage_outlined,
                title: '车辆管理',
                subtitle: '我的车辆和默认车辆',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const GaragePage()),
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
            ]),
            const AppSectionLabel('用车设置'),
            _group([
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
            const AppSectionLabel('通用'),
            _group(const [
              _LanguageSettingTile(),
              _DistanceUnitSettingTile(),
              _RespectTextScaleSettingTile(),
            ]),
            const AppSectionLabel('高级'),
            _group([
              _settingItem(
                icon: Icons.admin_panel_settings_outlined,
                title: '高级诊断',
                subtitle: '设备信息、日志、协议和升级前检测',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const _AdvancedDiagnosticsPage(),
                  ),
                ),
              ),
            ]),
            const AppSectionLabel('关于'),
            _group([
              _settingItem(
                icon: Icons.info_outline,
                title: '关于台铃智能',
                subtitle: '版本信息、用户协议和隐私政策',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const AboutAppPage()),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _AdvancedDiagnosticsPage extends StatelessWidget {
  const _AdvancedDiagnosticsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppNav.contentBottomPadding),
          children: [
            const AppPageHeader(title: '高级诊断'),
            const SizedBox(height: 12),
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
                subtitle: '查看操作记录',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const LogPage()),
                ),
              ),
            ]),
          ],
        ),
      ),
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
                borderRadius: BorderRadius.circular(AppRadii.card),
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
    activeThumbColor: Colors.white,
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
