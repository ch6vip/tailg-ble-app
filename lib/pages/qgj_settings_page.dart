import 'dart:async';

import 'package:flutter/material.dart';

import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart';
import '../ble/qgj_protocol.dart';
import '../main.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_snack.dart';

/// P3-3 / P3-4: QGJ common settings + proximity unlock over BLE LOGIN.
class QgjSettingsPage extends StatefulWidget {
  const QgjSettingsPage({super.key});

  @override
  State<QgjSettingsPage> createState() => _QgjSettingsPageState();
}

class _QgjSettingsPageState extends State<QgjSettingsPage> {
  var _busy = false;
  bool? _proximityEnabled;
  int? _proximityDistance;

  Future<void> _readProximity() async {
    if (!connectionManager.isProtocolLoggedIn ||
        connectionManager.protocol != ble.ProtocolType.qgj) {
      AppSnack.info(context, '请先 BLE 协议登录到 QGJ 车型');
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
        if (status != null && status.success && status.payload.isNotEmpty) {
          _proximityEnabled = status.payload[0] != 0;
        }
        if (distance != null &&
            distance.success &&
            distance.payload.isNotEmpty) {
          _proximityDistance = distance.payload[0];
        }
      });
      AppSnack.success(context, '已读取感应解锁状态');
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setProximity(bool enabled) async {
    if (!connectionManager.isProtocolLoggedIn ||
        connectionManager.protocol != ble.ProtocolType.qgj) {
      AppSnack.info(context, '请先 BLE 协议登录到 QGJ 车型');
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await connectionManager.sendQgjCommand(
        QgjCommandIds.proximityStatusSet,
        buildQgjSwitchPayload(enabled),
      );
      if (!mounted) return;
      if (response?.success != true) {
        AppSnack.error(context, '写入感应解锁失败');
        return;
      }
      setState(() => _proximityEnabled = enabled);
      AppSnack.success(context, enabled ? '已开启感应解锁' : '已关闭感应解锁');
    } catch (e) {
      if (mounted) AppSnack.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final protocol = connectionManager.protocol;
    final loggedIn = connectionManager.isProtocolLoggedIn;
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
                    '对照官方 QGJ 设置页：感应解锁状态/距离通过 0x2030–0x2033 读写。',
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
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('感应解锁 / 靠近解锁'),
                    subtitle: Text(
                      _proximityEnabled == null
                          ? '未读取'
                          : (_proximityEnabled! ? '已开启' : '已关闭') +
                                (_proximityDistance == null
                                    ? ''
                                    : ' · 距离档 $_proximityDistance'),
                    ),
                    value: _proximityEnabled ?? false,
                    onChanged: _busy
                        ? null
                        : (v) => unawaited(_setProximity(v)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => unawaited(_readProximity()),
                          child: Text(_busy ? '处理中…' : '读取状态'),
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
