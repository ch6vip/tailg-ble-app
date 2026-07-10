import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_snack.dart';

class CloudTokenPage extends StatefulWidget {
  const CloudTokenPage({super.key});

  @override
  State<CloudTokenPage> createState() => _CloudTokenPageState();
}

class _CloudTokenPageState extends State<CloudTokenPage> {
  final _controller = TextEditingController();
  String? _savedToken;
  static const _prefKey = 'cloud_token';

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_prefKey);
    if (!mounted) return;
    setState(() {
      _savedToken = savedToken;
      if (savedToken != null) _controller.text = savedToken;
    });
  }

  Future<void> _saveToken() async {
    final token = _controller.text.trim();
    if (token.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, token);
    if (!mounted) return;
    setState(() => _savedToken = token);
    AppSnack.success(context, 'Token 已保存');
  }

  Future<void> _copyToken() async {
    final token = _savedToken;
    if (token == null || token.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    AppSnack.success(context, '已复制到剪贴板');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(title: '云端 Token'),
            const SizedBox(height: 20),
            if (_savedToken != null)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '已保存 Token',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _savedToken!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.copy,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                          onPressed: _copyToken,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: AppTouchTargets.min,
                            minHeight: AppTouchTargets.min,
                          ),
                          tooltip: '复制',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '共享 Token',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '输入 Web 端的 Token 可直接使用',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: '粘贴 Token...',
                      hintStyle: const TextStyle(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saveToken,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text('保存'),
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
