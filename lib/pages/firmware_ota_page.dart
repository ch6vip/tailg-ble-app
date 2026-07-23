import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/firmware_ota_service.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_void.dart';
import '../widgets/app_chrome.dart';
import '../widgets/void_canvas.dart';
import '../widgets/app_snack.dart';

/// P3-5: experimental official OTA flow (query -> download -> BLE chunks).
class FirmwareOtaPage extends StatefulWidget {
  const FirmwareOtaPage({super.key});

  @override
  State<FirmwareOtaPage> createState() => _FirmwareOtaPageState();
}

class _FirmwareOtaPageState extends State<FirmwareOtaPage> {
  late final FirmwareOtaService _ota = FirmwareOtaService(
    cloud: officialCloudService,
    connectionManager: connectionManager,
  );
  StreamSubscription<FirmwareOtaProgress>? _sub;
  FirmwareOtaProgress _progress = const FirmwareOtaProgress(
    phase: FirmwareOtaPhase.idle,
    fraction: 0,
    message: '待命',
  );
  var _running = false;

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  Future<void> _start() async {
    if (_running) return;
    setState(() {
      _running = true;
      _progress = const FirmwareOtaProgress(
        phase: FirmwareOtaPhase.querying,
        fraction: 0,
        message: '启动…',
      );
    });
    await _sub?.cancel();
    _sub = _ota.run().listen(
      (p) {
        if (!mounted) return;
        setState(() => _progress = p);
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _running = false);
        if (_progress.phase == FirmwareOtaPhase.completed) {
          AppSnack.success(context, _progress.message);
        } else if (_progress.phase == FirmwareOtaPhase.failed) {
          AppSnack.error(context, _progress.message);
        }
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _running = false;
          _progress = FirmwareOtaProgress(
            phase: FirmwareOtaPhase.failed,
            fraction: _progress.fraction,
            message: OfficialCloudRedactor.errorMessage(e),
          );
        });
        AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
      },
    );
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
              const AppPageHeader(title: '固件升级 OTA'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '官方 OTA 流',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. POST app/firmVersionInfo/getFirmVersion\n'
                      '2. 下载官方固件包（完整性校验待完成）\n'
                      '3. BLE LOGIN 后 writeOtaOrder(7000) + writeOtaFile(7001) 分片\n'
                      '4. 等待中控校验/重启',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _progress.fraction.clamp(0, 1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_progress.phase.name} · ${_progress.message}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _running ? null : () => unawaited(_start()),
                        child: Text(_running ? '进行中…' : '检查并升级'),
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
