import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/battery_setup_models.dart';
import '../models/official_vehicle.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/lucide_icon.dart';

/// Official-like "更正电池信息" flow
/// (`ReplaceBatteryActivity` / `affirmBatteryInfo`).
class ReplaceBatteryPage extends StatefulWidget {
  const ReplaceBatteryPage({super.key});

  @override
  State<ReplaceBatteryPage> createState() => _ReplaceBatteryPageState();
}

class _ReplaceBatteryPageState extends State<ReplaceBatteryPage> {
  final _voltageController = TextEditingController();
  final _ahController = TextEditingController();

  bool _loadingTypes = true;
  bool _loadingSpecs = false;
  bool _submitting = false;
  String? _error;

  List<OfficialBatteryType> _types = const [];
  List<OfficialBatterySpec> _specs = const [];
  OfficialBatteryType? _selectedType;
  OfficialBatterySpec? _selectedSpec;
  DateTime? _bindDate;

  OfficialVehicle? get _vehicle => officialCloudService.state.selectedVehicle;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _voltageController.dispose();
    _ahController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final vehicle = _vehicle;
    if (vehicle == null) {
      setState(() {
        _loadingTypes = false;
        _error = '请先选择车辆';
      });
      return;
    }

    // Prefill bind date from vehicle if present.
    final rawBind = vehicle.batteryBindDate.trim();
    if (rawBind.length >= 10) {
      _bindDate = DateTime.tryParse(rawBind.substring(0, 10));
    }

    // Prefill custom V/AH if type is custom and label looks like "48V20AH".
    final label = vehicle.batterySpecLabel.trim().toUpperCase();
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*V\s*(\d+(?:\.\d+)?)\s*A?H?',
    ).firstMatch(label);
    if (match != null) {
      _voltageController.text = match.group(1) ?? '';
      _ahController.text = match.group(2) ?? '';
    }

    try {
      final types = await officialCloudService.fetchBatteryTypes();
      if (!mounted) return;
      OfficialBatteryType? selected;
      final currentTypeId = vehicle.batteryTypeId.trim();
      if (currentTypeId.isNotEmpty) {
        for (final type in types) {
          if (type.type == currentTypeId) {
            selected = type;
            break;
          }
        }
      }
      selected ??= types.isEmpty ? null : types.first;

      setState(() {
        _types = types;
        _selectedType = selected;
        _loadingTypes = false;
        _error = types.isEmpty ? '未获取到电池类型列表' : null;
      });

      if (selected != null && !selected.isCustom) {
        await _loadSpecs(
          selected.type,
          preselectCode: vehicle.raw['batterySpecCode']?.toString(),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTypes = false;
        _error = OfficialCloudRedactor.errorMessage(e);
      });
    }
  }

  Future<void> _loadSpecs(String typeId, {String? preselectCode}) async {
    setState(() {
      _loadingSpecs = true;
      _specs = const [];
      _selectedSpec = null;
    });
    try {
      final specs = await officialCloudService.fetchBatterySpecsByType(typeId);
      if (!mounted) return;
      OfficialBatterySpec? selected;
      final code = preselectCode?.trim() ?? '';
      if (code.isNotEmpty) {
        for (final spec in specs) {
          if (spec.code == code) {
            selected = spec;
            break;
          }
        }
      }
      selected ??= specs.isEmpty ? null : specs.first;
      setState(() {
        _specs = specs;
        _selectedSpec = selected;
        _loadingSpecs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSpecs = false;
        _error = OfficialCloudRedactor.errorMessage(e);
      });
    }
  }

  Future<void> _pickBindDate() async {
    final now = DateTime.now();
    final initial = _bindDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(2015),
      lastDate: now,
      helpText: '选择绑定日期',
    );
    if (picked == null || !mounted) return;
    setState(() => _bindDate = picked);
  }

  String get _bindDateLabel {
    final d = _bindDate;
    if (d == null) return '请选择绑定日期';
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _submit() async {
    final vehicle = _vehicle;
    final type = _selectedType;
    if (vehicle == null) {
      AppSnack.error(context, '请先选择车辆');
      return;
    }
    if (type == null) {
      AppSnack.error(context, '请选择电池类型');
      return;
    }

    final carId = vehicle.carId.trim();
    if (carId.isEmpty) {
      AppSnack.error(context, '车辆缺少 carId，无法提交');
      return;
    }

    final AffirmBatteryInfoRequest request;
    if (type.isCustom) {
      final voltage = _voltageController.text.trim();
      final ah = _ahController.text.trim();
      if (voltage.isEmpty) {
        AppSnack.error(context, '请输入电压');
        return;
      }
      if (ah.isEmpty) {
        AppSnack.error(context, '请输入安时数');
        return;
      }
      request = AffirmBatteryInfoRequest(
        carId: carId,
        batteryType: type.type,
        batteryVoltage: voltage,
        batteryCapacity: ah,
        bindDate: _bindDate == null ? null : _bindDateLabel,
      );
    } else {
      final spec = _selectedSpec;
      if (spec == null) {
        AppSnack.error(context, '请选择电池规格');
        return;
      }
      if (_bindDate == null) {
        AppSnack.error(context, '请选择绑定日期');
        return;
      }
      request = AffirmBatteryInfoRequest(
        carId: carId,
        batteryCode: spec.code,
        bindDate: _bindDateLabel,
      );
    }

    setState(() => _submitting = true);
    try {
      await officialCloudService.affirmBatteryInfo(request);
      if (!mounted) return;
      AppSnack.success(context, '电池信息已更正');
      Navigator.of(context).pop(true);
    } catch (e) {
      logService.operation(
        '更正电池失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (!mounted) return;
      AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _vehicle;
    final custom = _selectedType?.isCustom == true;

    return Scaffold(
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const _ReplaceBatteryHeader(),
            Expanded(
              child: _loadingTypes
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: CyberHomeColors.primary,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        if (vehicle != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: _replaceBatteryCardDecoration,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vehicle.displayName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: CyberHomeColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '当前：${vehicle.batterySpecLabel.isEmpty ? '未设置规格' : vehicle.batterySpecLabel}'
                                  '${vehicle.batteryBindDate.isEmpty ? '' : ' · ${vehicle.batteryBindDate}'}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: CyberHomeColors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CyberHomeColors.warning.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadii.tile,
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: CyberHomeColors.warning,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _SectionCard(
                          title: '电池类型',
                          child: DropdownButtonFormField<OfficialBatteryType>(
                            // ignore: deprecated_member_use
                            value: _selectedType,
                            isExpanded: true,
                            dropdownColor: CyberHomeColors.card,
                            icon: const LucideIcon(
                              Lucide.chevronDown,
                              size: 18,
                            ),
                            decoration: _replaceBatteryInputDecoration(),
                            style: const TextStyle(color: CyberHomeColors.ink),
                            items: [
                              for (final type in _types)
                                DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    type.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: _submitting
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _selectedType = value;
                                      _selectedSpec = null;
                                      _specs = const [];
                                    });
                                    if (!value.isCustom) {
                                      unawaited(_loadSpecs(value.type));
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (custom) ...[
                          _SectionCard(
                            title: '自定义电压 / 安时',
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _voltageController,
                                    enabled: !_submitting,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'),
                                      ),
                                    ],
                                    decoration: _replaceBatteryInputDecoration(
                                      labelText: '电压 (V)',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _ahController,
                                    enabled: !_submitting,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]'),
                                      ),
                                    ],
                                    decoration: _replaceBatteryInputDecoration(
                                      labelText: '安时 (AH)',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          _SectionCard(
                            title: '电池规格',
                            child: _loadingSpecs
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                : DropdownButtonFormField<OfficialBatterySpec>(
                                    // ignore: deprecated_member_use
                                    value: _selectedSpec,
                                    isExpanded: true,
                                    dropdownColor: CyberHomeColors.card,
                                    icon: const LucideIcon(
                                      Lucide.chevronDown,
                                      size: 18,
                                    ),
                                    decoration:
                                        _replaceBatteryInputDecoration(),
                                    style: const TextStyle(
                                      color: CyberHomeColors.ink,
                                    ),
                                    items: [
                                      for (final spec in _specs)
                                        DropdownMenuItem(
                                          value: spec,
                                          child: Text(
                                            spec.spec,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                    onChanged: _submitting
                                        ? null
                                        : (value) => setState(
                                            () => _selectedSpec = value,
                                          ),
                                  ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: '绑定日期',
                          child: AppPressable(
                            key: const ValueKey('replace-battery-bind-date'),
                            onTap: _submitting ? null : _pickBindDate,
                            enabled: !_submitting,
                            semanticsLabel: '选择绑定日期，$_bindDateLabel',
                            semanticsButton: true,
                            borderRadius: BorderRadius.circular(AppRadii.tile),
                            child: Container(
                              constraints: const BoxConstraints(
                                minHeight: AppTouchTargets.min,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: CyberHomeColors.cardMuted,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.tile,
                                ),
                                border: Border.all(
                                  color: CyberHomeColors.lineStrong,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _bindDateLabel,
                                      style: const TextStyle(
                                        color: CyberHomeColors.ink,
                                      ),
                                    ),
                                  ),
                                  const LucideIcon(
                                    Lucide.calendar,
                                    color: CyberHomeColors.primary,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            key: const ValueKey('replace-battery-submit'),
                            style: FilledButton.styleFrom(
                              backgroundColor: CyberHomeColors.primary,
                              foregroundColor: CyberHomeColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.tile,
                                ),
                              ),
                            ),
                            onPressed: _submitting ? null : _submit,
                            child: _submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: CyberHomeColors.white,
                                    ),
                                  )
                                : const Text('确认提交'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '提交后将调用官方 batterySetUp 接口，并自动刷新车辆与电池信息。',
                          style: TextStyle(
                            fontSize: 12,
                            color: CyberHomeColors.inkFaint,
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

class _ReplaceBatteryHeader extends StatelessWidget {
  const _ReplaceBatteryHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 8),
      child: Row(
        children: [
          AppPressable(
            key: const ValueKey('replace-battery-back'),
            onTap: () => Navigator.of(context).pop(),
            semanticsLabel: '返回',
            semanticsButton: true,
            child: Container(
              width: AppTouchTargets.min,
              height: AppTouchTargets.min,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: CyberHomeColors.card,
                shape: BoxShape.circle,
                boxShadow: AppShadows.cyberActionShadow,
              ),
              child: const LucideIcon(
                Lucide.arrowLeft,
                size: 20,
                color: CyberHomeColors.inkSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '更正电池信息',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: CyberHomeColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _replaceBatteryCardDecoration = BoxDecoration(
  color: CyberHomeColors.card,
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.tile)),
  border: Border.fromBorderSide(BorderSide(color: CyberHomeColors.line)),
);

InputDecoration _replaceBatteryInputDecoration({String? labelText}) {
  return InputDecoration(
    labelText: labelText,
    filled: true,
    fillColor: CyberHomeColors.cardMuted,
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      borderSide: const BorderSide(color: CyberHomeColors.lineStrong),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      borderSide: const BorderSide(color: CyberHomeColors.lineStrong),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      borderSide: const BorderSide(color: CyberHomeColors.primary, width: 1.5),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _replaceBatteryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: CyberHomeColors.inkSecondary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
