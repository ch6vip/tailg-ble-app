import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/clipboard_text.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../services/sensitive_value_masker.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_snack.dart';

/// Copy the current official session token, or paste a token to sign in
/// without SMS (device transfer / multi-client sharing).
class CloudTokenPage extends StatefulWidget {
  const CloudTokenPage({super.key});

  @override
  State<CloudTokenPage> createState() => _CloudTokenPageState();
}

class _CloudTokenPageState extends State<CloudTokenPage> {
  final _controller = TextEditingController();
  StreamSubscription<OfficialCloudState>? _sub;
  OfficialCloudState _state = officialCloudService.state;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _state = officialCloudService.state;
    if (_state.token.isNotEmpty) {
      _controller.text = _state.token;
    }
    _sub = officialCloudService.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
    });
  }

  @override
  void dispose() {
    final sub = _sub;
    if (sub != null) unawaited(sub.cancel());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyCurrentToken() async {
    final token = _state.token.trim();
    if (token.isEmpty) {
      AppSnack.info(context, '当前未登录，没有可复制的 Token');
      return;
    }
    await writeClipboardText(token);
    if (!mounted) return;
    AppSnack.success(context, 'Token 已复制到剪贴板');
  }

  Future<void> _pasteFromClipboard() async {
    final text = await readClipboardText();
    if (!mounted) return;
    if (text == null) {
      AppSnack.info(context, '剪贴板为空');
      return;
    }
    setState(() => _controller.text = text);
    AppSnack.success(context, '已从剪贴板粘贴');
  }

  Future<void> _loginWithToken() async {
    if (_busy) return;
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      AppSnack.info(context, '请先粘贴 Token');
      return;
    }
    setState(() => _busy = true);
    try {
      await officialCloudService.loginWithToken(
        raw,
        phone: _state.phone,
        userId: _state.userId,
      );
      if (!mounted) return;
      AppSnack.success(context, 'Token 登录成功，车辆已同步');
    } catch (e) {
      logService.operation(
        'Token 登录失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
      if (!mounted) return;
      final message = OfficialCloudRedactor.errorMessage(e);
      AppSnack.error(context, message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _maskToken(String token) =>
      SensitiveValueMasker.compact(token, emptyValue: '未登录');

  @override
  Widget build(BuildContext context) {
    final signedIn = _state.signedIn;
    final loading = _busy || _state.loading;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppNav.contentBottomPadding),
          children: [
            const AppPageHeader(title: '云端 Token'),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('当前会话', style: AppTextStyles.subtitle),
                  const SizedBox(height: 8),
                  Text(
                    signedIn
                        ? '已登录 · ${_maskToken(_state.token)}'
                        : '未登录 · 可粘贴 Token 直接进入官方会话',
                    style: AppTextStyles.smallText,
                  ),
                  if (_state.phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '手机号 ${SensitiveValueMasker.phone(_state.phone)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: signedIn && !loading
                              ? _copyCurrentToken
                              : null,
                          icon: const Icon(Icons.copy, size: AppIconSizes.sm),
                          label: const Text('复制 Token'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: loading ? null : _pasteFromClipboard,
                          icon: const Icon(
                            Icons.content_paste,
                            size: AppIconSizes.sm,
                          ),
                          label: const Text('粘贴'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('粘贴 Token 登录', style: AppTextStyles.subtitle),
                  const SizedBox(height: 4),
                  const Text(
                    '支持直接粘贴 Authorization 值，或带 Bearer 前缀 / Authorization 头整行。'
                    '登录后会写入安全存储并同步车辆。',
                    style: AppTextStyles.smallText,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    minLines: 3,
                    maxLines: 6,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      hintText: '粘贴 Token 或 Authorization: Bearer ...',
                      hintStyle: const TextStyle(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: loading ? null : _loginWithToken,
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(signedIn ? '用此 Token 重新登录' : '用 Token 登录'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const AppCard(
              child: Text(
                'Token 等同于账号登录凭证，请勿分享给不可信的人或页面。'
                '复制仅用于你自己的多设备调试与迁移。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
