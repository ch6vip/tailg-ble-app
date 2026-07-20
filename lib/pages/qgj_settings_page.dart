import 'dart:async';

import 'package:flutter/material.dart';

import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart';
import '../ble/qgj_protocol.dart';
import '../main.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_snack.dart';

/// P3-3 / P3-4: QGJ common settings + proximity unlock over BLE LOGIN.
///
/// Official path (`EVBikeQgjSettingFragment` / ControlFragment QGJ mode):
/// - status get/set: `0x2030` / `0x2031` (OpCode OPEN=1 / CLOSE=0)
/// - distance get/set: `0x2032` / `0x2033` (UInt8 level)
/// - optional HID: `0x2140` Open/Close when pairing proximity
class QgjSettingsPage extends StatefulWidget {
  const QgjSettingsPage({super.key});

  @override
  State<QgjSettingsPage> createState() => _QgjSettingsPageState();
}

class _QgjSettingsPageState extends State<QgjSettingsPage> {
  static const _maxDistanceLevel = 10;

  var _busy = false;
  bool? _proximityEnabled;
  int? _proximityDistance;
  double _distanceDraft = 5;

  @override
  void initState() {
    super.initState();
    if (connectionManager.isProtocolLoggedIn &&
        connectionManager.protocol == ble.ProtocolType.qgj) {
      unawaited(_readProximity(silent: true));
    }
  }

  bool get _qgjReady =>
      connectionManager.isProtocolLoggedIn &&
      connectionManager.protocol == ble.ProtocolType.qgj;

  Future<void> _readProximity({bool silent = false}) async {
    if (!_qgjReady) {
      if (!silent && mounted) {
        AppSnack.info(context, '请先 BLE 协议登录到 QGJ 车型');
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final status = await connectionManager.sendQgjCommand(
        QgjCommandIds.proximityStatusGet,
      );
      final distance = await connectionManager.sendQgjCommand(
        QgjCommandIds.proximityDistanceGet,
      );
      if (!mounted) return;
      setState(() {
        final enabled = status != null && status.success
            ? parseQgjProximityEnabled(status.payload)
            : null;
        final level = distance != null && distance.success
            ? parseQgjProximityDistance(distance.payload)
            : null;
        if (enabled != null) _proximityEnabled = enabled;
        if (level != null) {
          _proximityDistance = level.clamp(0, _maxDistanceLevel);
          _distanceDraft = _proximityDistance!.toDouble();
        }
      });
      if (!silent) AppSnack.success(context, '已读取感应解锁状态');
    } catch (e) {
      if (!silent && mounted) {
        AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setProximity(bool enabled) async {
    if (!_qgjReady) {
      AppSnack.info(context, '请先 BLE 协议登录到 QGJ 车型');
      return;
    }
    setState(() => _busy = true);
    try {
      // Official ControlFragment QGJ path also toggles HID when enabling.
      if (enabled) {
        await connectionManager.sendQgjCommand(
          QgjCommandIds.hidStatusSet,
          buildQgjHidPayload(QgjHidModes.open),
        );
      }
      final response = await connectionManager.sendQgjCommand(
        QgjCommandIds.proximityStatusSet,
        buildQgjProximityStatusPayload(enabled),
      );
      if (!enabled) {
        await connectionManager.sendQgjCommand(
          QgjCommandIds.hidStatusSet,
          buildQgjHidPayload(QgjHidModes.close),
        );
      }
      if (!mounted) return;
      if (response?.success != true) {
        AppSnack.error(context, '写入感应解锁失败');
        return;
      }
      setState(() => _proximityEnabled = enabled);
      AppSnack.success(context, enabled ? '感应解锁已开启（配对成功）' : '感应解锁已关闭（配对移除）');
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setDistance(int level) async {
    if (!_qgjReady) {
      AppSnack.info(context, '请先 BLE 协议登录到 QGJ 车型');
      return;
    }
    final value = level.clamp(0, _maxDistanceLevel);
    setState(() => _busy = true);
    try {
      final response = await connectionManager.sendQgjCommand(
        QgjCommandIds.proximityDistanceSet,
        buildQgjProximityDistancePayload(value),
      );
      if (!mounted) return;
      if (response?.success != true) {
        AppSnack.error(context, '写入感应距离失败');
        return;
      }
      setState(() {
        _proximityDistance = value;
        _distanceDraft = value.toDouble();
      });
      AppSnack.success(context, '感应距离已设为 $value');
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, OfficialCloudRedactor.errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final protocol = connectionManager.protocol;
    final loggedIn = connectionManager.isProtocolLoggedIn;
    final distanceLabel = _proximityDistance?.toString() ?? '未读取';
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const AppPageHeader(title: 'QGJ 设置'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '协议: ${protocol.name} · LOGIN: ${loggedIn ? "是" : "否"}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '对照官方 QGJ：感应开关 0x2031（OPEN=1/CLOSE=0），'
                    '距离档 0x2033；开启时同步 HID(0x2140)。'
                    '真正靠近解锁由车端 ECU 完成，App 只负责配置。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('感应解锁 / 靠近解锁'),
                    subtitle: Text(
                      _proximityEnabled == null
                          ? '未读取 · 需 BLE LOGIN'
                          : '${_proximityEnabled! ? '已开启' : '已关闭'} · 距离档 $distanceLabel',
                    ),
                    value: _proximityEnabled ?? false,
                    onChanged: _busy || !_qgjReady
                        ? null
                        : (v) => unawaited(_setProximity(v)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '感应距离档 ${_distanceDraft.round()}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Slider(
                    value: _distanceDraft.clamp(
                      0,
                      _maxDistanceLevel.toDouble(),
                    ),
                    min: 0,
                    max: _maxDistanceLevel.toDouble(),
                    divisions: _maxDistanceLevel,
                    label: '${_distanceDraft.round()}',
                    onChanged: _busy || !_qgjReady
                        ? null
                        : (v) => setState(() => _distanceDraft = v),
                    onChangeEnd: _busy || !_qgjReady
                        ? null
                        : (v) => unawaited(_setDistance(v.round())),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton(
                    onPressed: _busy ? null : () => unawaited(_readProximity()),
                    child: Text(_busy ? '处理中…' : '读取状态'),
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
