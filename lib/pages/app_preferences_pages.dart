import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/app_preferences_service.dart';
import '../services/clipboard_text.dart';
import '../services/diagnostic_export_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_snack.dart';

const _appVersion = '1.0.0+1';
const _buildCommit = String.fromEnvironment(
  'GIT_COMMIT',
  defaultValue: 'local',
);

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  final _preferences = appPreferencesService;
  AppLanguagePreference _selected = AppLanguagePreference.system;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await _preferences.init();
    if (!mounted) return;
    setState(() => _selected = _preferences.language);
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      await _preferences.setLanguage(_selected);
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '语言设置'),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const AppSectionLabel('语言'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (
                          var i = 0;
                          i < AppLanguagePreference.values.length;
                          i++
                        ) ...[
                          _OptionRow(
                            title: AppLanguagePreference.values[i].label,
                            selected:
                                _selected == AppLanguagePreference.values[i],
                            onTap: () => setState(
                              () => _selected = AppLanguagePreference.values[i],
                            ),
                          ),
                          if (i != AppLanguagePreference.values.length - 1)
                            const _InsetDivider(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _confirm,
                  child: Text(_saving ? '保存中...' : '确认'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UnitSettingsPage extends StatefulWidget {
  const UnitSettingsPage({super.key});

  @override
  State<UnitSettingsPage> createState() => _UnitSettingsPageState();
}

class _UnitSettingsPageState extends State<UnitSettingsPage> {
  final _preferences = appPreferencesService;
  DistanceUnitPreference _selected = DistanceUnitPreference.metric;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await _preferences.init();
    if (!mounted) return;
    setState(() => _selected = _preferences.distanceUnit);
  }

  Future<void> _select(DistanceUnitPreference preference) async {
    setState(() => _selected = preference);
    await _preferences.setDistanceUnit(preference);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '单位设置'),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const AppSectionLabel('距离单位'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (
                          var i = 0;
                          i < DistanceUnitPreference.values.length;
                          i++
                        ) ...[
                          _OptionRow(
                            title: DistanceUnitPreference.values[i].label,
                            subtitle: DistanceUnitPreference.values[i].hint,
                            selected:
                                _selected == DistanceUnitPreference.values[i],
                            onTap: () =>
                                _select(DistanceUnitPreference.values[i]),
                          ),
                          if (i != DistanceUnitPreference.values.length - 1)
                            const _InsetDivider(),
                        ],
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
  }
}

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  Future<void> _copyDiagnosticReport(BuildContext context) async {
    // P0-6: 直接使用 main.dart 顶层 getter logService，无需局部变量
    final report = DiagnosticExportService(
      logService: logService,
      vehicleStore: vehicleStore,
      officialCloudService: officialCloudService,
    ).buildReport(logService.all);
    await writeClipboardText(report);
    if (!context.mounted) return;
    AppSnack.success(context, '已复制诊断报告');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '关于台铃智能'),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const SizedBox(height: 18),
                  AppCard(
                    child: Column(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadii.sheet),
                          ),
                          child: const Icon(
                            Icons.electric_moped,
                            color: AppColors.primary,
                            size: AppIconSizes.xl,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text('台铃智能', style: AppTextStyles.dialogTitle),
                        const SizedBox(height: 4),
                        const Text('智慧用车服务', style: AppTextStyles.smallText),
                      ],
                    ),
                  ),
                  const AppSectionLabel('版本'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: const [
                        _InfoRow(label: '应用版本', value: _appVersion),
                        _InsetDivider(),
                        _InfoRow(label: 'Git 提交', value: _buildCommit),
                      ],
                    ),
                  ),
                  const AppSectionLabel('服务支持'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _ActionRow(
                          icon: Icons.support_agent_outlined,
                          title: '服务诊断',
                          subtitle: '复制信息用于客服排查问题',
                          onTap: () => _copyDiagnosticReport(context),
                        ),
                        const _InsetDivider(),
                        _ActionRow(
                          icon: Icons.description_outlined,
                          title: '用户协议',
                          subtitle: '查看服务使用条款',
                          onTap: () => AppSnack.notYetOpen(context, '用户协议'),
                        ),
                        _InsetDivider(),
                        _ActionRow(
                          icon: Icons.privacy_tip_outlined,
                          title: '隐私政策',
                          subtitle: '了解个人信息保护规则',
                          onTap: () => AppSnack.notYetOpen(context, '隐私政策'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text('Copyright 2026', style: AppTextStyles.caption),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _OptionRow({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final semanticLabel = subtitle == null ? title : '$title，$subtitle';
    return _PreferenceRowPressable(
      semanticLabel: semanticLabel,
      selected: selected,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.itemTitle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTextStyles.smallText),
                  ],
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PreferenceRowPressable(
      semanticLabel: '$title，$subtitle',
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            _RowIcon(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.itemTitle),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTextStyles.smallText),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: AppIconSizes.md,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceRowPressable extends StatelessWidget {
  final String semanticLabel;
  final bool? selected;
  final VoidCallback onTap;
  final Widget child;

  const _PreferenceRowPressable({
    required this.semanticLabel,
    this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: true,
      selected: selected,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(onTap: onTap, child: child),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.valueText,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  final IconData icon;

  const _RowIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Icon(icon, color: AppColors.primary, size: AppIconSizes.md),
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
      indent: 16,
      endIndent: 16,
      color: AppColors.border,
    );
  }
}
