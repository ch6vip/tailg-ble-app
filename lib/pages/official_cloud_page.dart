import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/lucide_icon.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/app_navigation.dart';
import '../models/official_vehicle.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../services/sensitive_value_masker.dart';
import '../services/sms_countdown.dart';
import '../theme/app_colors.dart';
import '../theme/app_void.dart';
import '../widgets/app_chrome.dart';
import '../widgets/void_canvas.dart';
import '../widgets/app_snack.dart';

class OfficialCloudPage extends StatefulWidget {
  const OfficialCloudPage({super.key});

  @override
  State<OfficialCloudPage> createState() => _OfficialCloudPageState();
}

class _OfficialCloudPageState extends State<OfficialCloudPage> {
  final _phoneController = TextEditingController();
  final _smsController = TextEditingController();
  final _smsCountdown = SmsCountdown();

  @override
  void initState() {
    super.initState();
    final phone = officialCloudService.state.phone;
    if (phone.isNotEmpty) _phoneController.text = phone;
  }

  @override
  void dispose() {
    _smsCountdown.dispose();
    _phoneController.dispose();
    _smsController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_smsCountdown.isActive) return;
    try {
      await officialCloudService.requestSmsCode(_normalizedPhone);
      if (!mounted) return;
      _smsCountdown.start(isMounted: () => mounted);
      AppSnack.success(context, '验证码已发送');
    } catch (e) {
      logService.operation(
        '官云验证码发送失败',
        detail: OfficialCloudRedactor.errorMessage(e),
        level: LogLevel.warning,
      );
      if (!mounted) return;
      AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
    }
  }

  Future<void> _login() async {
    try {
      await officialCloudService.login(
        _normalizedPhone,
        _smsController.text.trim(),
      );
      if (!mounted) return;
      AppSnack.success(context, '官方账号登录成功');
    } catch (e) {
      logService.operation(
        '官云登录失败',
        detail: OfficialCloudRedactor.errorMessage(e),
        level: LogLevel.warning,
      );
      if (!mounted) return;
      AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
    }
  }

  String get _normalizedPhone =>
      OfficialCloudLoginValidator.compactPhone(_phoneController.text);

  Future<void> _refresh() async {
    try {
      await officialCloudService.refreshVehicles();
      if (!mounted) return;
      AppSnack.success(context, '官方车辆已刷新');
    } catch (e) {
      logService.operation(
        '官云车辆刷新失败',
        detail: OfficialCloudRedactor.errorMessage(e),
        level: LogLevel.warning,
      );
      if (!mounted) return;
      AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VoidColors.voidDeep,
      body: VoidCanvas(
        child: SafeArea(
          child: StreamBuilder<OfficialCloudState>(
            stream: officialCloudService.stateStream,
            initialData: officialCloudService.state,
            builder: (context, snapshot) {
              final state = snapshot.data ?? officialCloudService.state;
              final error = state.error;
              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                  bottom: AppNav.contentBottomPadding,
                ),
                children: [
                  AppPageHeader(
                    title: '我的车辆',
                    actions: [
                      if (state.signedIn)
                        AppHeaderAction(
                          icon: Lucide.refresh,
                          tooltip: '刷新车辆',
                          onTap: state.loading ? null : _refresh,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!state.signedIn)
                    _LoginCard(
                      phoneController: _phoneController,
                      smsController: _smsController,
                      loading: state.loading,
                      smsCountdown: _smsCountdown.remaining,
                      onRequestCode: _requestCode,
                      onLogin: _login,
                    )
                  else ...[
                    _VehicleListCard(state: state),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    AppCard(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      child: Text(
                        error,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const AppCard(
                    child: Text(
                      '登录后会同步账号下已绑定车辆。车辆绑定、解绑和转让请按官方服务流程完成。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatefulWidget {
  final TextEditingController phoneController;
  final TextEditingController smsController;
  final bool loading;
  final ValueListenable<int> smsCountdown;
  final VoidCallback onRequestCode;
  final VoidCallback onLogin;

  const _LoginCard({
    required this.phoneController,
    required this.smsController,
    required this.loading,
    required this.smsCountdown,
    required this.onRequestCode,
    required this.onLogin,
  });

  @override
  State<_LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<_LoginCard> {
  bool _showPhoneError = false;
  bool _showSmsError = false;
  bool _validPhone = false;
  bool _validSms = false;

  @override
  void initState() {
    super.initState();
    _syncInputState();
    widget.phoneController.addListener(_onTextChanged);
    widget.smsController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(_LoginCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    var inputControllersChanged = false;
    if (oldWidget.phoneController != widget.phoneController) {
      oldWidget.phoneController.removeListener(_onTextChanged);
      widget.phoneController.addListener(_onTextChanged);
      inputControllersChanged = true;
    }
    if (oldWidget.smsController != widget.smsController) {
      oldWidget.smsController.removeListener(_onTextChanged);
      widget.smsController.addListener(_onTextChanged);
      inputControllersChanged = true;
    }
    if (inputControllersChanged) {
      _syncInputState();
    }
  }

  @override
  void dispose() {
    widget.phoneController.removeListener(_onTextChanged);
    widget.smsController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted) return;
    setState(_syncInputState);
  }

  String get _phoneText =>
      OfficialCloudLoginValidator.compactPhone(widget.phoneController.text);

  String get _smsText => widget.smsController.text.trim();

  void _syncInputState() {
    _validPhone = OfficialCloudLoginValidator.isValidPhone(_phoneText);
    _validSms = OfficialCloudLoginValidator.isValidSmsCode(_smsText);
    _showPhoneError = widget.phoneController.text.isNotEmpty && !_validPhone;
    _showSmsError = widget.smsController.text.isNotEmpty && !_validSms;
  }

  @override
  Widget build(BuildContext context) {
    final canRequestCode = !widget.loading && _validPhone;
    final canLogin = !widget.loading && _validPhone && _validSms;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('登录后查看车辆', style: AppTextStyles.subtitle),
          const SizedBox(height: 14),
          TextField(
            controller: widget.phoneController,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: _inputDecoration(
              '手机号',
              errorText: _showPhoneError ? '请输入 11 位手机号' : null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.smsController,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: _inputDecoration(
                    '短信验证码',
                    errorText: _showSmsError ? '请输入短信验证码' : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ValueListenableBuilder<int>(
                  valueListenable: widget.smsCountdown,
                  builder: (context, smsCountdown, _) {
                    return OutlinedButton(
                      onPressed: canRequestCode && smsCountdown == 0
                          ? widget.onRequestCode
                          : null,
                      child: Text(smsCountdown > 0 ? '${smsCountdown}s' : '获取'),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: canLogin ? widget.onLogin : null,
              child: widget.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('登录'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {String? errorText}) {
    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }
}

class _VehicleListCard extends StatefulWidget {
  final OfficialCloudState state;

  const _VehicleListCard({required this.state});

  @override
  State<_VehicleListCard> createState() => _VehicleListCardState();
}

class _VehicleListCardState extends State<_VehicleListCard> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.loading && state.vehicles.isEmpty) {
      return const AppCard(child: Center(child: CircularProgressIndicator()));
    }
    if (state.vehicles.isEmpty) {
      return const AppCard(
        child: Text('暂无车辆，请确认当前账号已完成车辆绑定。', style: AppTextStyles.bodyMedium),
      );
    }
    return Column(
      children: state.vehicles.map((vehicle) {
        final selected = state.selectedVehicle?.key == vehicle.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _OfficialVehicleCard(vehicle: vehicle, selected: selected),
        );
      }).toList(),
    );
  }
}

class _OfficialVehicleCard extends StatelessWidget {
  final OfficialVehicle vehicle;
  final bool selected;

  const _OfficialVehicleCard({required this.vehicle, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : AppColors.surface,
      child: InkWell(
        onTap: () async {
          unawaited(HapticFeedback.selectionClick());
          await officialCloudService.selectVehicle(vehicle);
          if (!context.mounted) return;
          AppNavigation.returnToVehicleHome(context);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vehicle.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle,
                  ),
                ),
                _StatusChip(
                  label: vehicle.onlineLabel,
                  color: vehicle.online
                      ? AppColors.success
                      : AppColors.textTertiary,
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Lucide.checkCircle,
                    color: AppColors.primary,
                    size: AppIconSizes.sm,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  label: vehicle.defenceLabel,
                  color: AppColors.primary,
                ),
                _StatusChip(
                  label: vehicle.powerLabel,
                  color: AppColors.warning,
                ),
                _StatusChip(
                  label: vehicle.electricQuantity == null
                      ? '电量 --'
                      : '电量 ${vehicle.electricQuantity}%',
                  color: AppColors.success,
                ),
                _StatusChip(
                  label: vehicle.voltage == null
                      ? '电压 --'
                      : '${vehicle.voltage}V',
                  color: AppColors.info,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => OfficialVehicleDetailPage(vehicle: vehicle),
                  ),
                ),
                icon: const Icon(Lucide.info, size: AppIconSizes.sm),
                label: const Text('详情'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfficialVehicleDetailPage extends StatefulWidget {
  final OfficialVehicle vehicle;

  const OfficialVehicleDetailPage({super.key, required this.vehicle});

  @override
  State<OfficialVehicleDetailPage> createState() =>
      _OfficialVehicleDetailPageState();
}

class _OfficialVehicleDetailPageState extends State<OfficialVehicleDetailPage> {
  bool _savingNick = false;

  OfficialVehicle _resolveVehicle(OfficialCloudState state) {
    for (final item in state.vehicles) {
      if (item.key == widget.vehicle.key) return item;
      if (widget.vehicle.carId.isNotEmpty &&
          item.carId == widget.vehicle.carId) {
        return item;
      }
    }
    return widget.vehicle;
  }

  Future<void> _editCarNickName(OfficialVehicle vehicle) async {
    if (_savingNick) return;
    if (vehicle.carId.trim().isEmpty) {
      AppSnack.error(context, '车辆 ID 无效，无法修改昵称');
      return;
    }
    final controller = TextEditingController(text: vehicle.carNickName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑车辆昵称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(hintText: '输入车辆昵称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || name == null) return;
    final nick = name.trim();
    if (nick.isEmpty) {
      AppSnack.error(context, '车辆昵称不能为空');
      return;
    }
    if (nick == vehicle.carNickName.trim()) return;

    setState(() => _savingNick = true);
    try {
      await officialCloudService.updateCarNickName(
        carId: vehicle.carId,
        carNickName: nick,
      );
      if (!mounted) return;
      AppSnack.success(context, '车辆昵称已更新');
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
    } finally {
      if (mounted) setState(() => _savingNick = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OfficialCloudState>(
      stream: officialCloudService.stateStream,
      initialData: officialCloudService.state,
      builder: (context, snapshot) {
        final vehicle = _resolveVehicle(
          snapshot.data ?? officialCloudService.state,
        );
        return Scaffold(
          backgroundColor: VoidColors.voidDeep,
          body: VoidCanvas(
            child: SafeArea(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                  bottom: AppNav.contentBottomPadding,
                ),
                children: [
                  AppPageHeader(title: vehicle.displayName),
                  const SizedBox(height: 12),
                  if (vehicle.carPhoto.isNotEmpty)
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        child: Image.network(
                          vehicle.carPhoto,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            height: 120,
                            child: Center(
                              child: Icon(
                                Lucide.vehicle,
                                size: AppIconSizes.xl,
                                semanticLabel: '车辆',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      children: [
                        _DetailLine(
                          '车辆昵称',
                          vehicle.carNickName,
                          trailing: _savingNick
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Lucide.edit,
                                  size: AppIconSizes.sm,
                                  color: AppColors.textTertiary,
                                ),
                          onTap: _savingNick
                              ? null
                              : () => _editCarNickName(vehicle),
                        ),
                        _DetailLine('车辆名称', vehicle.carName),
                        _DetailLine('车架号', vehicle.frame),
                        _DetailLine(
                          '官方 IMEI',
                          SensitiveValueMasker.compact(
                            vehicle.imei,
                            emptyValue: '未返回',
                            trim: false,
                          ),
                        ),
                        _DetailLine(
                          'GPS IMEI',
                          SensitiveValueMasker.compact(
                            vehicle.imeiGps,
                            emptyValue: '未返回',
                            trim: false,
                          ),
                        ),
                        _DetailLine(
                          '命令 IMEI',
                          SensitiveValueMasker.compact(
                            vehicle.commandImei,
                            emptyValue: '未返回',
                            trim: false,
                          ),
                        ),
                        _DetailLine(
                          '车型 modelType',
                          vehicle.modelType?.toString() ?? '未返回',
                        ),
                        _DetailLine('在线状态', vehicle.onlineLabel),
                        _DetailLine('设防状态', vehicle.defenceLabel),
                        _DetailLine('启动状态', vehicle.powerLabel),
                        _DetailLine(
                          '电量',
                          vehicle.electricQuantity == null
                              ? '未返回'
                              : '${vehicle.electricQuantity}%',
                        ),
                        _DetailLine(
                          '电压',
                          vehicle.voltage == null
                              ? '未返回'
                              : '${vehicle.voltage}V',
                        ),
                        _DetailLine(
                          '里程',
                          vehicle.mileage == null
                              ? '未返回'
                              : '${vehicle.mileage} km',
                        ),
                        _DetailLine('经度', vehicle.longitude),
                        _DetailLine('纬度', vehicle.latitude),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                OfficialVehicleSelfCheckPage(vehicle: vehicle),
                          ),
                        ),
                        icon: const Icon(Lucide.stethoscope),
                        label: const Text('云端自检'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class OfficialVehicleSelfCheckPage extends StatefulWidget {
  final OfficialVehicle vehicle;

  const OfficialVehicleSelfCheckPage({super.key, required this.vehicle});

  @override
  State<OfficialVehicleSelfCheckPage> createState() =>
      _OfficialVehicleSelfCheckPageState();
}

class _OfficialVehicleSelfCheckPageState
    extends State<OfficialVehicleSelfCheckPage> {
  OfficialVehicleSelfCheck? _result;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_runCheck());
  }

  Future<void> _runCheck() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await officialCloudService.selfCheck();
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      logService.operation(
        '官云自检失败',
        detail: OfficialCloudRedactor.errorMessage(e),
        level: LogLevel.warning,
      );
      if (!mounted) return;
      setState(() => _error = OfficialCloudRedactor.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final result = _result;
    return Scaffold(
      backgroundColor: VoidColors.voidDeep,
      body: VoidCanvas(
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: AppNav.contentBottomPadding),
            children: [
              AppPageHeader(
                title: '云端自检',
                actions: [
                  AppHeaderAction(
                    icon: Lucide.refresh,
                    tooltip: '重新自检',
                    onTap: _loading ? null : _runCheck,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.vehicle.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle,
                    ),
                    const SizedBox(height: 8),
                    _DetailLine(
                      '命令 IMEI',
                      SensitiveValueMasker.compact(
                        widget.vehicle.commandImei,
                        emptyValue: '未返回',
                        trim: false,
                      ),
                    ),
                    _DetailLine(
                      '车型 modelType',
                      widget.vehicle.modelType?.toString() ?? '未返回',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const AppCard(child: Center(child: CircularProgressIndicator()))
              else if (error != null)
                AppCard(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  child: Text(
                    error,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                )
              else if (result != null)
                _SelfCheckResultCard(result: result)
              else
                const AppCard(
                  child: Text(
                    '暂未返回自检结果',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelfCheckResultCard extends StatelessWidget {
  final OfficialVehicleSelfCheck result;

  const _SelfCheckResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final data = result.dataMap;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailLine('返回状态', result.displayMessage),
          _DetailLine('返回 code', result.code?.toString() ?? '未返回'),
          if (data.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('自检字段', style: AppTextStyles.bodyLarge),
            const SizedBox(height: 6),
            ...data.entries.map(
              (entry) => _DetailLine(
                entry.key,
                _maskSensitiveValue(entry.key, entry.value),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              '官方自检字段含义待真车确认，当前保留原始返回摘要。',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _maskSensitiveValue(String key, Object? value) {
    final text = value?.toString() ?? '未返回';
    final lowerKey = key.toLowerCase();
    if (lowerKey.contains('imei') ||
        lowerKey.contains('mac') ||
        lowerKey.contains('phone') ||
        lowerKey.contains('token')) {
      return SensitiveValueMasker.compact(text, emptyValue: '未返回', trim: false);
    }
    return text;
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _DetailLine(this.label, this.value, {this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = value.trim();
    final display = text.isEmpty ? '未返回' : text;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: AppTextStyles.valueText,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: row,
    );
  }
}
