import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/lucide_icon.dart';

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
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const _BindImeiHeader(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CyberHomeColors.card,
                borderRadius: BorderRadius.circular(AppRadii.tile),
                border: Border.all(color: CyberHomeColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '对照官方手写 IMEI 绑定（bindCar1 / app/car/bikeBind）。坐垫二维码可扫出同一 IMEI 后粘贴至此。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: CyberHomeColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: '设备 IMEI',
                      hintText: '请输入 15 位左右 IMEI',
                      filled: true,
                      fillColor: CyberHomeColors.cardMuted,
                      prefixIcon: const LucideIcon(
                        Lucide.pin,
                        color: CyberHomeColors.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                        borderSide: const BorderSide(
                          color: CyberHomeColors.lineStrong,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: CyberHomeColors.primary,
                        foregroundColor: CyberHomeColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.tile),
                        ),
                      ),
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
    );
  }
}

class _BindImeiHeader extends StatelessWidget {
  const _BindImeiHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
      child: Row(
        children: [
          AppPressable(
            key: const ValueKey('bind-imei-back'),
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
              'IMEI 绑车',
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
