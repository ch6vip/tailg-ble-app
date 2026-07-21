import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/induction_mode_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_snack.dart';

/// 感应解锁设置页（QGJ / TLink / RSSI 统一入口）。
///
/// 产品文案面向用户；协议细节不展示。
/// 解锁模式（感应 / 手动）开关在此页，不在爱车主页合卡。
class InductionSettingsPage extends StatefulWidget {
  const InductionSettingsPage({super.key});

  @override
  State<InductionSettingsPage> createState() => _InductionSettingsPageState();
}

/// Backward-compatible alias used by older navigation sites.
@Deprecated('Use InductionSettingsPage')
typedef QgjSettingsPage = InductionSettingsPage;

class _InductionSettingsPageState extends State<InductionSettingsPage> {
  StreamSubscription<InductionModeSnapshot>? _sub;
  StreamSubscription<bool>? _manualSub;
  InductionModeSnapshot _snap = InductionModeSnapshot.empty;
  double _distanceDraft = InductionModeService.defaultDistanceLevel.toDouble();
  var _busy = false;
  var _manualMode = false;

  @override
  void initState() {
    super.initState();
    final vehicle = officialCloudService.state.selectedVehicle;
    inductionModeService.bindVehicle(
      modelType: vehicle?.modelType,
      carId: vehicle?.carId,
      vehicleRaw: vehicle?.raw,
    );
    _snap = inductionModeService.snapshot;
    _manualMode = manualModeService.enabled;
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
    _manualSub = manualModeService.enabledStream.listen((enabled) {
      if (!mounted) return;
      setState(() => _manualMode = enabled);
    });
    unawaited(
      manualModeService.init().then((_) {
        if (!mounted) return;
        setState(() => _manualMode = manualModeService.enabled);
      }),
    );
    unawaited(inductionModeService.refresh(force: true));
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(_manualSub?.cancel());
    super.dispose();
  }

  bool get _supportsInduction => _snap.stack != InductionStack.none;

  /// true = induction, false = manual, null = unknown / reading.
  bool? get _unlockSelection {
    if (_manualMode) return false;
    if (!_supportsInduction) return false;
    return _snap.unlockSelection;
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
          '请保持手机蓝牙已连接车辆；切到后台时会暂停轮询以省电。'
          '手动模式开启时不会自动控车。',
    InductionStack.none => '当前车辆暂不支持本地感应解锁，请使用手动控车。',
  };

  String get _unlockStatusLine {
    if (!_supportsInduction) {
      return _snap.bleReady ? '当前车型仅支持手动控车' : '连接蓝牙后识别车型';
    }
    final selection = _unlockSelection;
    if (selection == null) {
      return _snap.bleReady ? '正在读取解锁模式…' : '连接蓝牙后可开启感应';
    }
    if (selection == false) {
      return '手动控车 · 已关闭自动连接与感应';
    }
    if (!_snap.bleReady) return '开启感应前请先连接车辆蓝牙';
    if (_snap.bondIncomplete) {
      return '感应已开 · 请允许系统蓝牙配对';
    }
    final dist = _snap.distance == null ? '' : ' · 距离档 ${_snap.distance}';
    return '靠近自动解防，离开自动上锁$dist';
  }

  Future<void> _selectUnlockMode({required bool induction}) async {
    if (_busy || _snap.busy) return;

    if (!induction) {
      if (_manualMode && _snap.enabled != true) return;
      setState(() => _busy = true);
      if (_snap.enabled == true) {
        final closed = await inductionModeService.setEnabled(false);
        if (!mounted) return;
        if (!closed) {
          setState(() => _busy = false);
          AppSnack.error(context, _snap.lastError ?? '关闭感应失败');
          return;
        }
      }
      await manualModeService.setEnabled(true);
      if (!mounted) return;
      setState(() {
        _manualMode = true;
        _busy = false;
      });
      AppSnack.success(context, '已切换为手动模式');
      return;
    }

    if (!_supportsInduction) {
      AppSnack.info(context, _snap.bleReady ? '当前车型不支持感应解锁' : '连接蓝牙后识别车型');
      return;
    }
    if (!_snap.bleReady) {
      AppSnack.info(context, '请先连接车辆蓝牙后再开启感应');
      return;
    }
    if (_snap.enabled == true && !_manualMode) {
      if (_snap.bondIncomplete) {
        AppSnack.info(context, '请在系统弹窗中允许蓝牙配对，否则靠近解锁可能无效');
      }
      return;
    }

    setState(() => _busy = true);
    final ok = await inductionModeService.setEnabled(
      true,
      clearManualMode: true,
    );
    if (!mounted) return;
    setState(() {
      _manualMode = manualModeService.enabled;
      _busy = false;
    });
    if (!ok) {
      AppSnack.error(context, _snap.lastError ?? '开启感应失败');
      return;
    }
    if (_snap.bondIncomplete) {
      AppSnack.info(context, _snap.lastError ?? '感应已开启，请允许系统蓝牙配对');
    } else {
      AppSnack.success(context, '感应解锁已开启');
    }
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

  ButtonStyle _segmentStyle(AppColorsData colors) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 8),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? Colors.white
            : colors.textSecondary;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? colors.primary
            : colors.surfaceContainerHigh;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        return BorderSide(
          color: states.contains(WidgetState.selected)
              ? colors.primary
              : colors.outlineVariant,
        );
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final canWrite = _snap.bleReady && _supportsInduction;
    final maxLevel = _maxDistanceLevel;
    final selection = _unlockSelection;
    final anyBusy = _busy || _snap.busy;

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
                  if (!_snap.bleReady && _supportsInduction) ...[
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
                  Text(
                    '解锁模式',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _unlockStatusLine,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: _snap.bondIncomplete
                          ? colors.warning
                          : colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    emptySelectionAllowed: true,
                    segments: [
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.sensors, size: 16),
                        label: const Text('感应'),
                        enabled: _supportsInduction,
                      ),
                      const ButtonSegment(
                        value: false,
                        icon: Icon(Icons.touch_app_outlined, size: 16),
                        label: Text('手动'),
                      ),
                    ],
                    selected: {
                      if (selection != null) selection,
                      if (selection == null && !_supportsInduction) false,
                    },
                    showSelectedIcon: false,
                    expandedInsets: EdgeInsets.zero,
                    onSelectionChanged: anyBusy
                        ? null
                        : (next) {
                            if (next.isEmpty) return;
                            unawaited(_selectUnlockMode(induction: next.first));
                          },
                    style: _segmentStyle(colors),
                  ),
                  if (_showDistanceSlider && selection == true) ...[
                    const SizedBox(height: 16),
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
                      onChanged: anyBusy || !canWrite
                          ? null
                          : (v) => setState(() => _distanceDraft = v),
                      onChangeEnd: anyBusy || !canWrite
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
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: anyBusy ? null : () => unawaited(_read()),
                    child: Text(anyBusy ? '处理中…' : '刷新状态'),
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
