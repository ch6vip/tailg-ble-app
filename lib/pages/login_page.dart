import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/app_navigation.dart';
import '../services/clipboard_text.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../services/sms_countdown.dart';
import '../theme/app_colors.dart';
import '../theme/app_void.dart';
import '../widgets/app_snack.dart';
import '../widgets/lucide_icon.dart';
import '../widgets/void_canvas.dart';

/// 登录页 — 参考官方 LoginOnActivity / LoginPhoneCodeActivity，
/// 顶部品牌区 + 手机号验证码登录，底部附加粘贴 Token 登录入口。
///
/// 官方流程：SplashActivity → LoginOnActivity（视频背景+登录按钮）
///           → LoginPhoneCodeActivity（手机号+验证码+协议勾选）
/// 此页将两步合并为单页，并额外提供 Token 登录（多设备迁移 / 调试）。
class LoginPage extends StatefulWidget {
  /// 登录成功后跳转的回调（默认 pop 回上一页）。
  final VoidCallback? onSignedIn;

  const LoginPage({super.key, this.onSignedIn});

  const LoginPage.withCallback({super.key, this.onSignedIn});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

enum _LoginMode { sms, token }

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _smsController = TextEditingController();
  final _tokenController = TextEditingController();
  final _smsCountdown = SmsCountdown();
  StreamSubscription<OfficialCloudState>? _sub;
  bool _agreed = false;
  bool _busy = false;
  _LoginMode _mode = _LoginMode.sms;

  @override
  void initState() {
    super.initState();
    final phone = officialCloudService.state.phone;
    if (phone.isNotEmpty) _phoneController.text = phone;
    if (officialCloudService.state.token.isNotEmpty) {
      _tokenController.text = officialCloudService.state.token;
    }
    // Parent owns enabled-state for 获取验证码 / 登录. Controllers only notify
    // listeners — without this, typing a valid phone never rebuilds the parent
    // and the buttons stay disabled until an unrelated setState (e.g. mode
    // toggle) forces a rebuild. That matches the reported "switch to Token
    // then back and it works" symptom.
    _phoneController.addListener(_onFieldsChanged);
    _smsController.addListener(_onFieldsChanged);
    _tokenController.addListener(_onFieldsChanged);
    _sub = officialCloudService.stateStream.listen(_onStateChanged);
  }

  void _onFieldsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onStateChanged(OfficialCloudState state) {
    if (!mounted) return;
    if (state.signedIn && !_busy) {
      // 登录成功：回调 + 回到爱车根页（有车 bound / 无车 unbound）
      widget.onSignedIn?.call();
      if (mounted) {
        AppNavigation.returnToVehicleHome(context);
      }
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onFieldsChanged);
    _smsController.removeListener(_onFieldsChanged);
    _tokenController.removeListener(_onFieldsChanged);
    _smsCountdown.dispose();
    final sub = _sub;
    if (sub != null) unawaited(sub.cancel());
    _phoneController.dispose();
    _smsController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  // ── 短信验证码登录 ────────────────────────────────────────────────────

  String get _normalizedPhone =>
      OfficialCloudLoginValidator.compactPhone(_phoneController.text);

  bool get _validPhone =>
      OfficialCloudLoginValidator.isValidPhone(_normalizedPhone);

  bool get _validSms =>
      OfficialCloudLoginValidator.isValidSmsCode(_smsController.text.trim());

  Future<void> _requestCode() async {
    if (_smsCountdown.isActive || !_validPhone) return;
    if (!_agreed) {
      AppSnack.info(context, '请先阅读并同意用户协议与隐私政策');
      return;
    }
    try {
      await officialCloudService.requestSmsCode(_normalizedPhone);
      if (!mounted) return;
      _smsCountdown.start(isMounted: () => mounted);
      AppSnack.success(context, '验证码已发送');
    } catch (e) {
      logService.operation(
        '官云验证码发送失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (!mounted) return;
      AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
    }
  }

  Future<void> _loginWithSms() async {
    if (_busy) return;
    if (!_validPhone) {
      AppSnack.info(context, '请输入 11 位手机号');
      return;
    }
    if (!_validSms) {
      AppSnack.info(context, '请输入短信验证码');
      return;
    }
    if (!_agreed) {
      AppSnack.info(context, '请先阅读并同意用户协议与隐私政策');
      return;
    }
    setState(() => _busy = true);
    try {
      await officialCloudService.login(
        _normalizedPhone,
        _smsController.text.trim(),
      );
      if (!mounted) return;
      AppSnack.success(context, '登录成功');
      widget.onSignedIn?.call();
      if (mounted) AppNavigation.returnToVehicleHome(context);
    } catch (e) {
      logService.operation(
        '官云登录失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (!mounted) return;
      AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Token 登录 ────────────────────────────────────────────────────────

  Future<void> _pasteFromClipboard() async {
    final text = await readClipboardText();
    if (!mounted) return;
    if (text == null) {
      AppSnack.info(context, '剪贴板为空');
      return;
    }
    setState(() => _tokenController.text = text);
    AppSnack.success(context, '已从剪贴板粘贴');
  }

  Future<void> _loginWithToken() async {
    if (_busy) return;
    final raw = _tokenController.text.trim();
    if (raw.isEmpty) {
      AppSnack.info(context, '请先粘贴 Token');
      return;
    }
    if (!_agreed) {
      AppSnack.info(context, '请先阅读并同意用户协议与隐私政策');
      return;
    }
    setState(() => _busy = true);
    try {
      await officialCloudService.loginWithToken(
        raw,
        phone: officialCloudService.state.phone,
        userId: officialCloudService.state.userId,
      );
      if (!mounted) return;
      AppSnack.success(context, 'Token 登录成功');
      widget.onSignedIn?.call();
      if (mounted) AppNavigation.returnToVehicleHome(context);
    } catch (e) {
      logService.operation(
        'Token 登录失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (!mounted) return;
      AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switchMode(_LoginMode mode) {
    FocusScope.of(context).unfocus();
    setState(() => _mode = mode);
  }

  // ── 辅助 ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loading = _busy || officialCloudService.state.loading;
    return Scaffold(
      backgroundColor: VoidColors.voidDeep,
      body: VoidCanvas(
        intensity: 1.2,
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            children: [
              const _BrandHeader(),
              const SizedBox(height: 32),
              if (_mode == _LoginMode.sms)
                _SmsLoginForm(
                  phoneController: _phoneController,
                  smsController: _smsController,
                  smsCountdown: _smsCountdown.remaining,
                  loading: loading,
                  agreed: _agreed,
                  validPhone: _validPhone,
                  validSms: _validSms,
                  onRequestCode: _requestCode,
                  onLogin: _loginWithSms,
                )
              else
                _TokenLoginForm(
                  tokenController: _tokenController,
                  loading: loading,
                  onPaste: _pasteFromClipboard,
                  onLogin: _loginWithToken,
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  key: const ValueKey('login-mode-toggle'),
                  onPressed: loading
                      ? null
                      : () => _switchMode(
                          _mode == _LoginMode.sms
                              ? _LoginMode.token
                              : _LoginMode.sms,
                        ),
                  icon: LucideIcon(
                    _mode == _LoginMode.sms ? Lucide.key : Lucide.phone,
                    size: AppIconSizes.sm,
                    color: VoidColors.energy,
                  ),
                  label: Text(
                    _mode == _LoginMode.sms ? '使用 Token 登录' : '返回手机号登录',
                    style: const TextStyle(color: VoidColors.energy),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _AgreementRow(
                agreed: _agreed,
                onChanged: (v) => setState(() => _agreed = v),
              ),
              const SizedBox(height: 24),
              if (_mode == _LoginMode.token) const _TokenSafetyNote(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 品牌头部 ──────────────────────────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 28),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: VoidColors.voidPanel.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(VoidRadii.xl),
            border: Border.all(color: VoidColors.hairlineStrong),
            boxShadow: VoidGlow.energy(intensity: 0.8),
          ),
          child: const LucideIcon(
            Lucide.vehicle,
            size: 40,
            color: VoidColors.energy,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'TAILG',
          style: VoidType.hero.copyWith(
            fontSize: 36,
            letterSpacing: 8,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 8),
        Text('台铃智能 · VOID COCKPIT', style: VoidType.micro),
        const SizedBox(height: 12),
        Text(
          '登录后同步车辆，享受控车、定位、电池等服务',
          textAlign: TextAlign.center,
          style: VoidType.body,
        ),
      ],
    );
  }
}

// ── 短信登录表单 ──────────────────────────────────────────────────────────

class _SmsLoginForm extends StatefulWidget {
  const _SmsLoginForm({
    required this.phoneController,
    required this.smsController,
    required this.smsCountdown,
    required this.loading,
    required this.agreed,
    required this.validPhone,
    required this.validSms,
    required this.onRequestCode,
    required this.onLogin,
  });

  final TextEditingController phoneController;
  final TextEditingController smsController;
  final ValueListenable<int> smsCountdown;
  final bool loading;
  final bool agreed;
  final bool validPhone;
  final bool validSms;
  final VoidCallback onRequestCode;
  final VoidCallback onLogin;

  @override
  State<_SmsLoginForm> createState() => _SmsLoginFormState();
}

class _SmsLoginFormState extends State<_SmsLoginForm> {
  bool _showPhoneError = false;
  bool _showSmsError = false;

  @override
  void initState() {
    super.initState();
    _syncError();
    widget.phoneController.addListener(_onChanged);
    widget.smsController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.phoneController.removeListener(_onChanged);
    widget.smsController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(_syncError);
  }

  void _syncError() {
    _showPhoneError =
        widget.phoneController.text.isNotEmpty && !widget.validPhone;
    _showSmsError = widget.smsController.text.isNotEmpty && !widget.validSms;
  }

  @override
  Widget build(BuildContext context) {
    // Recompute from controllers on every build so parent-driven rebuilds
    // (after typing) always pass fresh validity into canRequest/canLogin.
    final validPhone = OfficialCloudLoginValidator.isValidPhone(
      OfficialCloudLoginValidator.compactPhone(widget.phoneController.text),
    );
    final validSms = OfficialCloudLoginValidator.isValidSmsCode(
      widget.smsController.text.trim(),
    );
    final canRequest = !widget.loading && validPhone;
    final canLogin = !widget.loading && validPhone && validSms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel('手机号'),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('login-phone-field'),
          controller: widget.phoneController,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: _inputDecoration(
            context,
            '请输入手机号',
            errorText: _showPhoneError ? '请输入 11 位手机号' : null,
          ),
        ),
        const SizedBox(height: 16),
        _FieldLabel('验证码'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('login-sms-field'),
                controller: widget.smsController,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: _inputDecoration(
                  context,
                  '请输入验证码',
                  errorText: _showSmsError ? '请输入短信验证码' : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: ValueListenableBuilder<int>(
                valueListenable: widget.smsCountdown,
                builder: (context, count, _) {
                  return OutlinedButton(
                    key: const ValueKey('login-request-code'),
                    onPressed: canRequest && count == 0
                        ? widget.onRequestCode
                        : null,
                    child: Text(count > 0 ? '${count}s' : '获取验证码'),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            key: const ValueKey('login-sms-submit'),
            onPressed: canLogin ? widget.onLogin : null,
            child: widget.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '登录',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Token 登录表单 ────────────────────────────────────────────────────────

class _TokenLoginForm extends StatelessWidget {
  const _TokenLoginForm({
    required this.tokenController,
    required this.loading,
    required this.onPaste,
    required this.onLogin,
  });

  final TextEditingController tokenController;
  final bool loading;
  final VoidCallback onPaste;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel('粘贴 Token'),
        const SizedBox(height: 8),
        TextField(
          controller: tokenController,
          minLines: 3,
          maxLines: 6,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            height: 1.35,
          ),
          decoration:
              _inputDecoration(
                context,
                '粘贴 Token 或 Authorization: Bearer ...',
              ).copyWith(
                suffixIcon: IconButton(
                  icon: const LucideIcon(Lucide.copy, size: AppIconSizes.sm),
                  onPressed: onPaste,
                  tooltip: '从剪贴板粘贴',
                ),
              ),
        ),
        const SizedBox(height: 10),
        Text(
          '支持直接粘贴 Authorization 值，或带 Bearer 前缀 / '
          'Authorization 头整行。登录后写入安全存储并同步车辆。',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: colors.textTertiary,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: loading ? null : onLogin,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '用 Token 登录',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}

// ── 协议勾选行 ────────────────────────────────────────────────────────────

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({required this.agreed, required this.onChanged});

  final bool agreed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: agreed,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: colors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.xs),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!agreed),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: colors.textSecondary,
                ),
                children: [
                  TextSpan(text: '我已阅读并同意'),
                  TextSpan(
                    text: '《用户协议》',
                    style: TextStyle(color: colors.primary),
                  ),
                  TextSpan(text: '和'),
                  TextSpan(
                    text: '《隐私政策》',
                    style: TextStyle(color: colors.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Token 安全提示 ────────────────────────────────────────────────────────

class _TokenSafetyNote extends StatelessWidget {
  const _TokenSafetyNote();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LucideIcon(Lucide.shield, size: 18, color: VoidColors.energyAmber),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Token 等同于账号登录凭证，请勿分享给不可信的人或页面。'
              '复制仅用于你自己的多设备调试与迁移。',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 通用组件 ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: colors.textSecondary,
      ),
    );
  }
}

InputDecoration _inputDecoration(
  BuildContext context,
  String hint, {
  String? errorText,
}) {
  final colors = AppColors.of(context);
  return InputDecoration(
    hintText: hint,
    errorText: errorText,
    hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14),
    filled: true,
    fillColor: colors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      borderSide: BorderSide(color: colors.danger, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      borderSide: BorderSide(color: colors.danger, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}
