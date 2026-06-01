import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';

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
    setState(() {
      _savedToken = prefs.getString(_prefKey);
      if (_savedToken != null) _controller.text = _savedToken!;
    });
  }

  Future<void> _saveToken() async {
    final token = _controller.text.trim();
    if (token.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, token);
    setState(() => _savedToken = token);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token 已保存'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _copyToken() {
    final token = _savedToken ?? connectionManager.token;
    if (token == null || token.isEmpty) return;
    Clipboard.setData(ClipboardData(text: token));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
    );
  }

  void _useCurrentToken() {
    final token = connectionManager.token;
    if (token != null && token.isNotEmpty) {
      _controller.text = token;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentToken = connectionManager.token;
    final isConnected = connectionManager.state == ble.ConnectionState.ready;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(title: '云端 Token'),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '当前连接 Token',
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
                          isConnected && currentToken != null
                              ? currentToken
                              : '未连接',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: isConnected
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isConnected && currentToken != null)
                        IconButton(
                          icon: Icon(
                            Icons.copy,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                          onPressed: _copyToken,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
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
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (isConnected)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _useCurrentToken,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('使用当前'),
                          ),
                        ),
                      if (isConnected) const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saveToken,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('保存'),
                        ),
                      ),
                    ],
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
