import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/induction_mode_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/lucide_icon.dart';

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
          '请保持手机蓝牙已连接车辆；Android 后台运行时会显示常驻通知。'
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
      final vehicleManaged =
          _snap.stack == InductionStack.qgj ||
          _snap.stack == InductionStack.tlink;
      if (vehicleManaged && _snap.enabled == null) {
        AppSnack.info(context, '请先连接车辆蓝牙并读取感应状态');
        return;
      }
      if (vehicleManaged && _snap.enabled == true && !_snap.bleReady) {
        AppSnack.info(context, '请先连接车辆蓝牙，确认关闭感应后再切换手动模式');
        return;
      }
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
      if (_snap.lastError != null) {
        AppSnack.info(context, _snap.lastError!);
      } else {
        AppSnack.success(context, '已切换为手动模式');
      }
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

    if (_snap.stack == InductionStack.rssi) {
      final notification = await permissionService
          .requestNotificationPermission();
      if (!mounted) return;
      if (!notification.granted) {
        AppSnack.info(context, notification.message ?? '后台感应需要通知权限');
        return;
      }
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
    if (_snap.lastError != null) {
      AppSnack.info(context, _snap.lastError!);
    } else if (_snap.bondIncomplete) {
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

  ButtonStyle _segmentStyle() {
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
            ? CyberHomeColors.white
            : CyberHomeColors.inkMuted;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? CyberHomeColors.primary
            : CyberHomeColors.control;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        return BorderSide(
          color: states.contains(WidgetState.selected)
              ? CyberHomeColors.primary
              : CyberHomeColors.line,
        );
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xs),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = _snap.bleReady && _supportsInduction;
    final maxLevel = _maxDistanceLevel;
    final selection = _unlockSelection;
    final anyBusy = _busy || _snap.busy;

    return Scaffold(
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _InductionHeader(
              busy: anyBusy,
              onRefresh: () => unawaited(_read()),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  const _SectionLabel('当前能力'),
                  _CapabilityCard(
                    stack: _snap.stack,
                    helpText: _helpText,
                    statusLine: _unlockStatusLine,
                    bondIncomplete: _snap.bondIncomplete,
                  ),
                  if (!_snap.bleReady && _supportsInduction) ...[
                    const SizedBox(height: 10),
                    _ConnectionNotice(
                      protocolLoggedIn: connectionManager.isProtocolLoggedIn,
                    ),
                  ],
                  const SizedBox(height: 22),
                  const _SectionLabel('解锁模式'),
                  Container(
                    key: const ValueKey('induction-mode-card'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CyberHomeColors.card,
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                      border: Border.all(color: CyberHomeColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<bool>(
                          emptySelectionAllowed: true,
                          segments: [
                            ButtonSegment(
                              value: true,
                              icon: const LucideIcon(Lucide.sensors, size: 16),
                              label: const Text('感应'),
                              enabled: _supportsInduction,
                            ),
                            const ButtonSegment(
                              value: false,
                              icon: LucideIcon(Lucide.pointer, size: 16),
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
                                  unawaited(
                                    _selectUnlockMode(induction: next.first),
                                  );
                                },
                          style: _segmentStyle(),
                        ),
                        if (_showDistanceSlider && selection == true) ...[
                          const SizedBox(height: 18),
                          const Divider(height: 1, color: CyberHomeColors.line),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  '感应距离',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: CyberHomeColors.ink,
                                  ),
                                ),
                              ),
                              _DistanceBadge(level: _distanceDraft.round()),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '档位越高，越远就能触发解锁',
                            style: TextStyle(
                              fontSize: 12,
                              color: CyberHomeColors.inkFaint,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Semantics(
                            label: '感应距离，档位 ${_distanceDraft.round()}',
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: CyberHomeColors.primary,
                                inactiveTrackColor:
                                    CyberHomeColors.controlStrong,
                                thumbColor: CyberHomeColors.primary,
                                overlayColor: CyberHomeColors.primary
                                    .withValues(alpha: 0.12),
                                valueIndicatorColor: CyberHomeColors.ink,
                                valueIndicatorTextStyle: const TextStyle(
                                  color: CyberHomeColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: Slider(
                                value: _distanceDraft.clamp(
                                  0,
                                  maxLevel.toDouble(),
                                ),
                                min: 0,
                                max: maxLevel.toDouble(),
                                divisions: maxLevel > 0 ? maxLevel : null,
                                label: '${_distanceDraft.round()}',
                                onChanged: anyBusy || !canWrite
                                    ? null
                                    : (value) => setState(
                                        () => _distanceDraft = value,
                                      ),
                                onChangeEnd: anyBusy || !canWrite
                                    ? null
                                    : (value) => unawaited(
                                        _setDistance(value.round()),
                                      ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '近',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: CyberHomeColors.inkFaint,
                                  ),
                                ),
                                Text(
                                  '远',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: CyberHomeColors.inkFaint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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

class _InductionHeader extends StatelessWidget {
  const _InductionHeader({required this.busy, required this.onRefresh});

  final bool busy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          AppPressable(
            key: const ValueKey('induction-settings-back'),
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
                color: CyberHomeColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '感应解锁',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: CyberHomeColors.ink,
              ),
            ),
          ),
          Tooltip(
            message: '刷新状态',
            excludeFromSemantics: true,
            child: AppPressable(
              key: const ValueKey('induction-settings-refresh'),
              onTap: onRefresh,
              enabled: !busy,
              semanticsLabel: '刷新状态',
              semanticsButton: true,
              semanticsEnabled: !busy,
              child: SizedBox(
                width: AppTouchTargets.min,
                height: AppTouchTargets.min,
                child: Center(
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: CyberHomeColors.primary,
                          ),
                        )
                      : const LucideIcon(
                          Lucide.refresh,
                          size: 20,
                          color: CyberHomeColors.inkSecondary,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 9),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: CyberHomeColors.inkMuted,
        ),
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.stack,
    required this.helpText,
    required this.statusLine,
    required this.bondIncomplete,
  });

  final InductionStack stack;
  final String helpText;
  final String statusLine;
  final bool bondIncomplete;

  @override
  Widget build(BuildContext context) {
    final title = switch (stack) {
      InductionStack.qgj || InductionStack.tlink => '车辆感应',
      InductionStack.rssi => '蓝牙信号感应',
      InductionStack.none => '手动控车',
    };
    final icon = switch (stack) {
      InductionStack.qgj || InductionStack.tlink => Lucide.sensors,
      InductionStack.rssi => Lucide.bluetooth,
      InductionStack.none => Lucide.pointer,
    };
    return Container(
      key: const ValueKey('induction-capability-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyberHomeColors.card,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: CyberHomeColors.line),
        boxShadow: AppShadows.cyberCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: CyberHomeColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: LucideIcon(
                  icon,
                  size: 21,
                  color: CyberHomeColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: CyberHomeColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusLine,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: bondIncomplete
                            ? CyberHomeColors.warning
                            : CyberHomeColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: CyberHomeColors.line),
          const SizedBox(height: 12),
          Text(
            helpText,
            style: const TextStyle(
              fontSize: 12,
              height: 1.55,
              color: CyberHomeColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionNotice extends StatelessWidget {
  const _ConnectionNotice({required this.protocolLoggedIn});

  final bool protocolLoggedIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CyberHomeColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(
          color: CyberHomeColors.warning.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LucideIcon(
            Lucide.alertCircle,
            size: 18,
            color: CyberHomeColors.warning,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              protocolLoggedIn ? '蓝牙已连接，正在同步状态…' : '当前未完成蓝牙协议登录，请返回爱车页连接车辆。',
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: CyberHomeColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 42),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CyberHomeColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '档位 $level',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: CyberHomeColors.primary,
        ),
      ),
    );
  }
}
