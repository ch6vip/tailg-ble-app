import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/induction_mode_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_snack.dart';

/// 感应解锁设置页（QGJ / TLink / RSSI 统一入口）。
///
/// 产品文案面向用户；协议细节仅开发可见（不展示指令码）。
class QgjSettingsPage extends StatefulWidget {
  const QgjSettingsPage({super.key});

  @override
  State<QgjSettingsPage> createState() => _QgjSettingsPageState();
}

class _QgjSettingsPageState extends State<QgjSettingsPage> {
  StreamSubscription<InductionModeSnapshot>? _sub;
  InductionModeSnapshot _snap = InductionModeSnapshot.empty;
  double _distanceDraft = InductionModeService.defaultDistanceLevel.toDouble();
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final vehicle = officialCloudService.state.selectedVehicle;
    inductionModeService.bindVehicle(
      modelType: vehicle?.modelType,
      carId: vehicle?.carId,
    );
    _snap = inductionModeService.snapshot;
    _distanceDraft =
        (_snap.distance ?? InductionModeService.defaultDistanceLevel)
            .toDouble();
    _sub = inductionModeService.snapshotStream.listen((snap) {
      if (!mounted) return;
      setState(() {
        _snap = snap;
        if (snap.distance != null) {
          _distanceDraft = snap.distance!.toDouble();
        }
      });
    });
    unawaited(inductionModeService.refresh(force: true));
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  /// 仅 QGJ / TLink 车端有真实距离档；RSSI 路径不展示滑条（避免误导）。
  bool get _showDistanceSlider =>
      _snap.stack == InductionStack.qgj || _snap.stack == InductionStack.tlink;

  int get _maxDistanceLevel => _snap.stack == InductionStack.qgj
      ? 10
      : InductionModeService.maxDistanceLevel;

  String get _helpText => switch (_snap.stack) {
    InductionStack.qgj || InductionStack.tlink =>
      '开启后，手机靠近车辆会自动解锁，离开后自动上锁。'
          '首次开启可能弹出系统蓝牙配对请求，请点允许。'
          '距离档越大，越容易触发感应。',
    InductionStack.rssi =>
      '开启后，App 会根据蓝牙信号强弱自动解防或上锁。'
          '请保持手机蓝牙已连接车辆；手动模式开启时不会自动控车。',
    InductionStack.none => '当前车辆暂不支持本地感应解锁，请使用手动控车。',
  };

  String get _statusSubtitle {
    if (!_snap.bleReady && _snap.stack != InductionStack.none) {
      return '请先连接车辆蓝牙';
    }
    if (_snap.enabled == null && _snap.stack != InductionStack.none) {
      return '尚未读取 · 可点下方刷新';
    }
    if (_snap.enabled == true) {
      if (_showDistanceSlider && _snap.distance != null) {
        return '已开启 · 距离档 ${_snap.distance}';
      }
      return '已开启 · 靠近自动解锁';
    }
    if (_snap.enabled == false) {
      return '已关闭';
    }
    return '不可用';
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_busy) return;
    if (manualModeService.enabled && enabled) {
      await manualModeService.setEnabled(false);
    }
    setState(() => _busy = true);
    final ok = await inductionModeService.setEnabled(enabled);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      AppSnack.error(context, _snap.lastError ?? '设置失败，请稍后重试');
      return;
    }
    AppSnack.success(context, enabled ? '感应解锁已开启' : '感应解锁已关闭');
  }

  Future<void> _setDistance(int level) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await inductionModeService.setDistance(level);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      AppSnack.error(context, _snap.lastError ?? '距离设置失败');
      return;
    }
    AppSnack.success(context, '感应距离已更新');
  }

  Future<void> _read() async {
    if (_busy) return;
    setState(() => _busy = true);
    await inductionModeService.refresh(force: true);
    if (!mounted) return;
    setState(() => _busy = false);
    if (_snap.lastError != null) {
      AppSnack.error(context, _snap.lastError!);
      return;
    }
    AppSnack.success(context, '状态已刷新');
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = _snap.bleReady && _snap.stack != InductionStack.none;
    final maxLevel = _maxDistanceLevel;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const AppPageHeader(title: '感应解锁'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _helpText,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (!_snap.bleReady &&
                      _snap.stack != InductionStack.none) ...[
                    const SizedBox(height: 10),
                    Text(
                      connectionManager.isProtocolLoggedIn
                          ? '蓝牙已连接，正在同步状态…'
                          : '当前未完成蓝牙协议登录，开关可能不可用。请返回爱车页连接车辆。',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
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
                    title: const Text(
                      '感应解锁',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(_statusSubtitle),
                    value: _snap.enabled ?? false,
                    onChanged: _busy || !canWrite
                        ? null
                        : (v) => unawaited(_setEnabled(v)),
                  ),
                  if (_showDistanceSlider) ...[
                    const SizedBox(height: 8),
                    Text(
                      '感应距离  ${_distanceDraft.round()}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '档位越高，越远就能触发解锁',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    Slider(
                      value: _distanceDraft.clamp(0, maxLevel.toDouble()),
                      min: 0,
                      max: maxLevel.toDouble(),
                      divisions: maxLevel > 0 ? maxLevel : null,
                      label: '${_distanceDraft.round()}',
                      onChanged: _busy || !canWrite
                          ? null
                          : (v) => setState(() => _distanceDraft = v),
                      onChangeEnd: _busy || !canWrite
                          ? null
                          : (v) => unawaited(_setDistance(v.round())),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '近',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        Text(
                          '远',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy || _snap.busy
                        ? null
                        : () => unawaited(_read()),
                    child: Text(_busy || _snap.busy ? '处理中…' : '刷新状态'),
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
