import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/firmware_ota_service.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snack.dart';
import '../widgets/cyber_page_chrome.dart';
import '../widgets/lucide_icon.dart';

/// P3-5: experimental official OTA flow:
/// query -> download -> writeOtaOrder -> writeOtaFileChunk.
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
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const CyberPageHeader(title: '固件升级 OTA'),
            const SizedBox(height: 8),
            CyberCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      SizedBox(
                        width: AppTouchTargets.min,
                        height: AppTouchTargets.min,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: CyberHomeColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: LucideIcon(
                              Lucide.download,
                              size: 20,
                              color: CyberHomeColors.primary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(child: Text('车辆固件', style: cyberItemTitleStyle)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '检查官方固件版本并通过蓝牙更新车辆中控。升级期间请保持车辆通电和手机靠近车辆。',
                    style: cyberBodyStyle,
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: _progress.fraction.clamp(0, 1),
                      backgroundColor: CyberHomeColors.controlStrong,
                      color: CyberHomeColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_progress.phase.name} · ${_progress.message}',
                    style: cyberCaptionStyle,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: cyberFilledButtonStyle(),
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
    );
  }
}
