import 'dart:async';

import 'package:flutter/material.dart';
import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart';
import '../services/vehicle_settings_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import 'qgj_advanced_settings_page.dart';

class VehicleSettingsPage extends StatefulWidget {
  const VehicleSettingsPage({super.key});

  @override
  State<VehicleSettingsPage> createState() => _VehicleSettingsPageState();
}

class _VehicleSettingsPageState extends State<VehicleSettingsPage> {
  late final _VehicleSettingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _VehicleSettingsController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _showResult(await _controller.refresh());
  }

  Future<void> _openSensitivitySheet(bool canSend) async {
    final level = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '震动灵敏度',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ...List.generate(4, (index) {
                      final value = index + 1;
                      final selected = value == _controller.sensitivityLevel;
                      return Padding(
                        padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
                        child: Material(
                          color: selected
                              ? _controller.sensitivityColor.withValues(
                                  alpha: 0.12,
                                )
                              : AppColors.pageBg,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: canSend && !_controller.sending
                                ? () => Navigator.pop(context, value)
                                : null,
                            child: SizedBox(
                              height: 54,
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  Radio<int>(
                                    value: value,
                                    groupValue: _controller.sensitivityLevel,
                                    onChanged: canSend && !_controller.sending
                                        ? (v) => Navigator.pop(context, v)
                                        : null,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _controller.sensitivityLabelFor(value),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: selected
                                            ? _controller.sensitivityColor
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    Icon(
                                      Icons.check_circle,
                                      color: _controller.sensitivityColor,
                                      size: 20,
                                    ),
                                  const SizedBox(width: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (level == null || !mounted) return;
    _showResult(await _controller.setSensitivity(level));
  }

  void _showResult(_SettingsActionResult result) {
    if (!mounted || result.message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? null : Colors.red.shade400,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ble.ConnectionState>(
      stream: connectionManager.stateStream,
      initialData: connectionManager.state,
      builder: (context, snapshot) {
        final connState = snapshot.data ?? ble.ConnectionState.disconnected;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final canSend =
                connState == ble.ConnectionState.ready && !_controller.sending;
            return Scaffold(
              backgroundColor: AppColors.pageBg,
              body: SafeArea(
                child: Column(
                  children: [
                    AppPageHeader(
                      title: '车辆设置',
                      actions: [_RefreshAction(_controller, _refresh, canSend)],
                    ),
                    ConnectionStatusBanner(
                      state: connState,
                      onScanTap: () => openScanTab(context),
                    ),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          const AppSectionLabel('蓝牙通讯'),
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: _SwitchSettingRow(
                              icon: Icons.phone_android,
                              title: 'APP遥控优先',
                              subtitle: '官方入口已对齐，写入命令待确认',
                              value: false,
                              onChanged: null,
                            ),
                          ),
                          const AppSectionLabel('功能设置'),
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                _NavSettingRow(
                                  icon: Icons.vibration,
                                  title: '震动灵敏度',
                                  subtitle: '车辆被触碰 报警音提示',
                                  trailingText: _controller.sensitivityLabel,
                                  onTap: () => _openSensitivitySheet(canSend),
                                ),
                                const _InsetDivider(),
                                _NavSettingRow(
                                  icon: Icons.volume_up_outlined,
                                  title: '声音设置',
                                  subtitle: '车辆部分提示声音',
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _QgjSoundSettingsPage(
                                        controller: _controller,
                                      ),
                                    ),
                                  ),
                                ),
                                const _InsetDivider(),
                                _NavSettingRow(
                                  icon: Icons.tips_and_updates_outlined,
                                  title: '车辆功能管理',
                                  subtitle: '感应大灯、坐垫感应等功能',
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _QgjFunctionSettingsPage(
                                        controller: _controller,
                                      ),
                                    ),
                                  ),
                                ),
                                const _InsetDivider(),
                                _NavSettingRow(
                                  icon: Icons.speed,
                                  title: '骑行设置',
                                  subtitle: '骑行模式和 ECU 功能入口',
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _QgjRideSettingsPage(
                                        controller: _controller,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const AppSectionLabel('待确认能力'),
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                _NavSettingRow(
                                  icon: Icons.manage_search,
                                  title: '高级设置只读',
                                  subtitle: '自动锁车、HID、龙头锁等官方 GET 状态',
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const QgjAdvancedSettingsPage(),
                                    ),
                                  ),
                                ),
                                const _InsetDivider(),
                                const _DisabledInfoRow(
                                  icon: Icons.timer_outlined,
                                  title: '自动下电',
                                  subtitle: '车辆静止后断电时间，命令待确认',
                                ),
                                const _InsetDivider(),
                                _DisabledInfoRow(
                                  icon: Icons.lock_clock,
                                  title: '自动锁车',
                                  subtitle: '已支持只读刷新，写入暂未开放',
                                ),
                                const _InsetDivider(),
                                const _DisabledInfoRow(
                                  icon: Icons.key_outlined,
                                  title: '密码解锁',
                                  subtitle: '官方有入口，当前暂不写入车辆',
                                ),
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
          },
        );
      },
    );
  }
}

class _QgjSoundSettingsPage extends StatelessWidget {
  final _VehicleSettingsController controller;

  const _QgjSoundSettingsPage({required this.controller});

  Future<void> _setSound(
    BuildContext context, {
    bool? startSound,
    bool? stopSound,
    bool? lockSound,
    bool? unlockSound,
  }) async {
    final result = await controller.setSound(
      startSound: startSound,
      stopSound: stopSound,
      lockSound: lockSound,
      unlockSound: unlockSound,
    );
    if (!context.mounted) return;
    _showSnack(context, result);
  }

  Future<void> _refresh(BuildContext context) async {
    final result = await controller.refresh();
    if (!context.mounted) return;
    _showSnack(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ble.ConnectionState>(
      stream: connectionManager.stateStream,
      initialData: connectionManager.state,
      builder: (context, snapshot) {
        final connState = snapshot.data ?? ble.ConnectionState.disconnected;
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final canSend =
                connState == ble.ConnectionState.ready && !controller.sending;
            return Scaffold(
              backgroundColor: AppColors.pageBg,
              body: SafeArea(
                child: Column(
                  children: [
                    AppPageHeader(
                      title: '声音设置',
                      actions: [
                        _RefreshAction(
                          controller,
                          () => _refresh(context),
                          canSend,
                        ),
                      ],
                    ),
                    ConnectionStatusBanner(
                      state: connState,
                      onScanTap: () => openScanTab(context),
                    ),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          const AppSectionLabel('报警提示'),
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: _SwitchSettingRow(
                              icon: Icons.notifications_active_outlined,
                              title: '防盗报警音',
                              subtitle: '车辆报警提示音，写入命令待确认',
                              value: true,
                              onChanged: null,
                            ),
                          ),
                          const AppSectionLabel('声音开关'),
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                _SwitchSettingRow(
                                  icon: Icons.power_settings_new,
                                  title: '上电',
                                  value: controller.startSound,
                                  onChanged: canSend
                                      ? (value) => _setSound(
                                          context,
                                          startSound: value,
                                        )
                                      : null,
                                ),
                                const _InsetDivider(),
                                _SwitchSettingRow(
                                  icon: Icons.power_off,
                                  title: '下电',
                                  value: controller.stopSound,
                                  onChanged: canSend
                                      ? (value) =>
                                            _setSound(context, stopSound: value)
                                      : null,
                                ),
                                const _InsetDivider(),
                                _SwitchSettingRow(
                                  icon: Icons.lock_outline,
                                  title: '上锁',
                                  value: controller.lockSound,
                                  onChanged: canSend
                                      ? (value) =>
                                            _setSound(context, lockSound: value)
                                      : null,
                                ),
                                const _InsetDivider(),
                                _SwitchSettingRow(
                                  icon: Icons.lock_open,
                                  title: '解锁',
                                  value: controller.unlockSound,
                                  onChanged: canSend
                                      ? (value) => _setSound(
                                          context,
                                          unlockSound: value,
                                        )
                                      : null,
                                ),
                                const _InsetDivider(),
                                _SwitchSettingRow(
                                  icon: Icons.volume_up,
                                  title: '全部声音',
                                  subtitle: '设置上/下电、上锁、解锁',
                                  value: controller.allMainSoundsEnabled,
                                  onChanged: canSend
                                      ? (value) => _setSound(
                                          context,
                                          startSound: value,
                                          stopSound: value,
                                          lockSound: value,
                                          unlockSound: value,
                                        )
                                      : null,
                                ),
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
          },
        );
      },
    );
  }
}

class _QgjFunctionSettingsPage extends StatelessWidget {
  final _VehicleSettingsController controller;

  const _QgjFunctionSettingsPage({required this.controller});

  Future<void> _setLight(BuildContext context, bool enabled) async {
    final result = await controller.setLightSensor(enabled);
    if (!context.mounted) return;
    _showSnack(context, result);
  }

  Future<void> _refresh(BuildContext context) async {
    final result = await controller.refresh();
    if (!context.mounted) return;
    _showSnack(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ble.ConnectionState>(
      stream: connectionManager.stateStream,
      initialData: connectionManager.state,
      builder: (context, snapshot) {
        final connState = snapshot.data ?? ble.ConnectionState.disconnected;
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final canSend =
                connState == ble.ConnectionState.ready && !controller.sending;
            return Scaffold(
              backgroundColor: AppColors.pageBg,
              body: SafeArea(
                child: Column(
                  children: [
                    AppPageHeader(
                      title: '车辆功能管理',
                      actions: [
                        _RefreshAction(
                          controller,
                          () => _refresh(context),
                          canSend,
                        ),
                      ],
                    ),
                    ConnectionStatusBanner(
                      state: connState,
                      onScanTap: () => openScanTab(context),
                    ),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          const AppSectionLabel('功能开关'),
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                _SwitchSettingRow(
                                  icon: Icons.wb_twilight_outlined,
                                  title: '感应大灯',
                                  subtitle: '官方 QGJ 命令 0x2410 / 0x2411',
                                  value: controller.lightSensor,
                                  onChanged: canSend
                                      ? (value) => _setLight(context, value)
                                      : null,
                                ),
                                const _InsetDivider(),
                                const _SwitchSettingRow(
                                  icon: Icons.lock_person_outlined,
                                  title: '电子龙头锁',
                                  subtitle: '命令待确认，暂不写入车辆',
                                  value: false,
                                  onChanged: null,
                                ),
                                _InsetDivider(),
                                const _SwitchSettingRow(
                                  icon: Icons.sensor_occupied_outlined,
                                  title: '电子边撑感应',
                                  subtitle: '命令待确认，暂不写入车辆',
                                  value: false,
                                  onChanged: null,
                                ),
                                _InsetDivider(),
                                const _SwitchSettingRow(
                                  icon: Icons.event_seat_outlined,
                                  title: '坐垫感应',
                                  subtitle: '命令待确认，暂不写入车辆',
                                  value: false,
                                  onChanged: null,
                                ),
                                _InsetDivider(),
                                const _SwitchSettingRow(
                                  icon: Icons.warning_amber_outlined,
                                  title: '侧翻检测',
                                  subtitle: '命令待确认，暂不写入车辆',
                                  value: false,
                                  onChanged: null,
                                ),
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
          },
        );
      },
    );
  }
}

class _QgjRideSettingsPage extends StatelessWidget {
  final _VehicleSettingsController controller;

  const _QgjRideSettingsPage({required this.controller});

  Future<void> _setMode(BuildContext context, RidingMode mode) async {
    final result = await controller.setRidingMode(mode);
    if (!context.mounted) return;
    _showSnack(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ble.ConnectionState>(
      stream: connectionManager.stateStream,
      initialData: connectionManager.state,
      builder: (context, snapshot) {
        final connState = snapshot.data ?? ble.ConnectionState.disconnected;
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final canSend =
                connState == ble.ConnectionState.ready && !controller.sending;
            return Scaffold(
              backgroundColor: AppColors.pageBg,
              body: SafeArea(
                child: Column(
                  children: [
                    const AppPageHeader(title: '骑行设置'),
                    ConnectionStatusBanner(
                      state: connState,
                      onScanTap: () => openScanTab(context),
                    ),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          const AppSectionLabel('当前可用'),
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '骑行模式',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: RidingMode.values.map((mode) {
                                    final selected =
                                        mode == controller.ridingMode;
                                    final color = switch (mode) {
                                      RidingMode.eco => AppColors.success,
                                      RidingMode.standard => AppColors.info,
                                      RidingMode.sport => AppColors.warning,
                                    };
                                    return Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        child: Material(
                                          color: selected
                                              ? color.withValues(alpha: 0.14)
                                              : AppColors.pageBg,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            onTap: canSend && !selected
                                                ? () => _setMode(context, mode)
                                                : null,
                                            child: SizedBox(
                                              height: 46,
                                              child: Center(
                                                child: Text(
                                                  mode.label,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: selected
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: selected
                                                        ? color
                                                        : AppColors
                                                              .textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const AppSectionLabel('官方 ECU 功能'),
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: const [
                                _DisabledInfoRow(
                                  icon: Icons.battery_2_bar,
                                  title: '低电量骑行模式',
                                  subtitle: '电量低于 20% 时半速行驶，命令待确认',
                                ),
                                _InsetDivider(),
                                _DisabledInfoRow(
                                  icon: Icons.security_outlined,
                                  title: '车辆稳定性系统 (ESP+TCS)',
                                  subtitle: '湿滑路面保持稳定，命令待确认',
                                ),
                                _InsetDivider(),
                                _DisabledInfoRow(
                                  icon: Icons.trending_down,
                                  title: '起步降流',
                                  subtitle: '降低起步电流，命令待确认',
                                ),
                                _InsetDivider(),
                                _DisabledInfoRow(
                                  icon: Icons.speed,
                                  title: '定速巡航',
                                  subtitle: '长按行车电脑键保持速度，命令待确认',
                                ),
                                _InsetDivider(),
                                _DisabledInfoRow(
                                  icon: Icons.rocket_launch_outlined,
                                  title: '氮气加速',
                                  subtitle: '官方入口存在，当前暂不写入车辆',
                                ),
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
          },
        );
      },
    );
  }
}

class _VehicleSettingsController extends ChangeNotifier {
  late final VehicleSettingsService _settingsService;

  bool lightSensor = false;
  bool startSound = true;
  bool stopSound = true;
  bool lockSound = true;
  bool unlockSound = true;
  bool speedSound = true;
  int sensitivityLevel = 3;
  RidingMode ridingMode = connectionManager.ridingMode;
  bool sending = false;

  _VehicleSettingsController() {
    _settingsService = VehicleSettingsService(
      connectionManager: connectionManager,
    );
  }

  bool get allMainSoundsEnabled =>
      startSound && stopSound && lockSound && unlockSound;

  String get sensitivityLabel => sensitivityLabelFor(sensitivityLevel);

  Color get sensitivityColor => switch (sensitivityLevel) {
    1 => AppColors.textTertiary,
    2 => AppColors.success,
    3 => AppColors.warning,
    _ => AppColors.danger,
  };

  String sensitivityLabelFor(int level) {
    return switch (level) {
      1 => '关闭',
      2 => '低',
      3 => '中',
      _ => '高',
    };
  }

  Future<_SettingsActionResult> refresh() async {
    if (sending) return const _SettingsActionResult.success('');
    _setSending(true);
    try {
      final snapshot = await _settingsService.refresh();
      if (snapshot == null) {
        return const _SettingsActionResult.failure('未读取到可识别的设置状态');
      }
      _applySnapshot(snapshot);
      return const _SettingsActionResult.success('设置状态已刷新');
    } on VehicleSettingsException catch (e) {
      return _SettingsActionResult.failure(e.message);
    } catch (_) {
      return const _SettingsActionResult.failure('设置读取失败');
    } finally {
      _setSending(false);
    }
  }

  Future<_SettingsActionResult> setLightSensor(bool enabled) {
    return _runSetting(
      operation: () => _settingsService.writeLightSensor(enabled),
      fallback: () => lightSensor = enabled,
      successMessage: enabled ? '感应大灯已开启' : '感应大灯已关闭',
    );
  }

  Future<_SettingsActionResult> setSound({
    bool? startSound,
    bool? stopSound,
    bool? lockSound,
    bool? unlockSound,
  }) {
    return _runSetting(
      operation: () => _settingsService.writeSound(
        startSound: startSound,
        stopSound: stopSound,
        lockSound: lockSound,
        unlockSound: unlockSound,
      ),
      fallback: () {
        this.startSound = startSound ?? this.startSound;
        this.stopSound = stopSound ?? this.stopSound;
        this.lockSound = lockSound ?? this.lockSound;
        this.unlockSound = unlockSound ?? this.unlockSound;
      },
      successMessage: '声音设置已更新',
    );
  }

  Future<_SettingsActionResult> setSensitivity(int level) {
    return _runSetting(
      operation: () => _settingsService.writeSensitivityLevel(level),
      fallback: () => sensitivityLevel = level,
      successMessage: '震动灵敏度已切换为 ${sensitivityLabelFor(level)}',
    );
  }

  Future<_SettingsActionResult> setRidingMode(RidingMode mode) async {
    if (sending || mode == ridingMode) {
      return const _SettingsActionResult.success('');
    }
    _setSending(true);
    try {
      final success = await connectionManager.setRidingMode(mode);
      if (!success) {
        return const _SettingsActionResult.failure('骑行模式切换失败');
      }
      ridingMode = connectionManager.ridingMode;
      unawaited(locationService.recordDefaultVehicleLocation());
      notifyListeners();
      return _SettingsActionResult.success('骑行模式已切换为 ${ridingMode.label}');
    } finally {
      _setSending(false);
    }
  }

  Future<_SettingsActionResult> _runSetting({
    required Future<VehicleSettingsSnapshot?> Function() operation,
    required VoidCallback fallback,
    required String successMessage,
  }) async {
    if (sending) return const _SettingsActionResult.success('');
    _setSending(true);
    try {
      final snapshot = await operation();
      if (snapshot != null) {
        _applySnapshot(snapshot);
      } else {
        fallback();
        notifyListeners();
      }
      return _SettingsActionResult.success(successMessage);
    } on VehicleSettingsException catch (e) {
      return _SettingsActionResult.failure(e.message);
    } catch (_) {
      return const _SettingsActionResult.failure('设置失败');
    } finally {
      _setSending(false);
    }
  }

  void _applySnapshot(VehicleSettingsSnapshot snapshot) {
    lightSensor = snapshot.lightSensor ?? lightSensor;
    startSound = snapshot.startSound ?? startSound;
    stopSound = snapshot.stopSound ?? stopSound;
    lockSound = snapshot.lockSound ?? lockSound;
    unlockSound = snapshot.unlockSound ?? unlockSound;
    speedSound = snapshot.speedSound ?? speedSound;
    if (snapshot.sensitivityValue != null) {
      sensitivityLevel = sensitivityValueToLevel(snapshot.sensitivityValue!);
    }
    notifyListeners();
  }

  void _setSending(bool value) {
    if (sending == value) return;
    sending = value;
    notifyListeners();
  }
}

class _SettingsActionResult {
  final bool success;
  final String message;

  const _SettingsActionResult._(this.success, this.message);
  const _SettingsActionResult.success(String message) : this._(true, message);
  const _SettingsActionResult.failure(String message) : this._(false, message);
}

class _RefreshAction extends StatelessWidget {
  final _VehicleSettingsController controller;
  final VoidCallback onRefresh;
  final bool enabled;

  const _RefreshAction(this.controller, this.onRefresh, this.enabled);

  @override
  Widget build(BuildContext context) {
    if (controller.sending) {
      return const Padding(
        padding: EdgeInsets.only(right: 8),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      tooltip: '刷新设置',
      onPressed: enabled ? onRefresh : null,
      icon: const Icon(Icons.refresh),
    );
  }
}

class _NavSettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingText;
  final VoidCallback? onTap;

  const _NavSettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              _RowIcon(icon, enabled: enabled),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingText != null) ...[
                Text(
                  trailingText!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchSettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchSettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      child: Row(
        children: [
          _RowIcon(icon, enabled: enabled),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _DisabledInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DisabledInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          _RowIcon(icon, enabled: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '待确认',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  final IconData icon;
  final bool enabled;

  const _RowIcon(this.icon, {required this.enabled});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.primary : AppColors.textTertiary;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _InsetDivider extends StatelessWidget {
  const _InsetDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      color: AppColors.border,
    );
  }
}

void _showSnack(BuildContext context, _SettingsActionResult result) {
  if (!context.mounted || result.message.isEmpty) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(result.message),
      backgroundColor: result.success ? null : Colors.red.shade400,
      duration: const Duration(seconds: 2),
    ),
  );
}
