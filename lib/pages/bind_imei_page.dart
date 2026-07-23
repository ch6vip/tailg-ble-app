import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/lucide_icon.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_void.dart';
import '../widgets/app_chrome.dart';
import '../widgets/void_canvas.dart';
import '../widgets/app_snack.dart';

/// P3-1: manual IMEI bind (`app/car/bikeBind`).
class BindImeiPage extends StatefulWidget {
  const BindImeiPage({super.key});

  @override
  State<BindImeiPage> createState() => _BindImeiPageState();
}

class _BindImeiPageState extends State<BindImeiPage> {
  final _controller = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!officialCloudService.state.signedIn) {
      AppSnack.info(context, OfficialCloudMessages.signInRequired);
      return;
    }
    setState(() => _busy = true);
    try {
      await officialCloudService.bindVehicleByImei(_controller.text);
      if (!mounted) return;
      AppSnack.success(context, '绑车成功，已刷新车辆列表');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VoidColors.voidDeep,
      body: VoidCanvas(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const AppPageHeader(title: 'IMEI 绑车'),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '对照官方手写 IMEI 绑定（bindCar1 / app/car/bikeBind）。坐垫二维码可扫出同一 IMEI 后粘贴至此。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: '设备 IMEI',
                        hintText: '请输入 15 位左右 IMEI',
                        prefixIcon: Icon(Lucide.pin),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : () => unawaited(_submit()),
                        child: Text(_busy ? '绑定中…' : '确认绑定'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
