import 'dart:async';

import 'package:flutter/material.dart';
import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart';
import '../services/vehicle_settings_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';

class VehicleSettingsPage extends StatefulWidget {
  const VehicleSettingsPage({super.key});

  @override
  State<VehicleSettingsPage> createState() => _VehicleSettingsPageState();
}

class _VehicleSettingsPageState extends State<VehicleSettingsPage> {
  late final VehicleSettingsService _settingsService;
  bool _lightSensor = false;
  bool _startSound = true;
  bool _stopSound = true;
  bool _lockSound = true;
  bool _unlockSound = true;
  bool _speedSound = true;
  int _shockSensitivityLevel = 3;
  RidingMode _ridingMode = RidingMode.standard;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _settingsService = VehicleSettingsService(
      connectionManager: connectionManager,
    );
    _ridingMode = connectionManager.ridingMode;
  }

  Future<void> _refreshSettings() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final snapshot = await _settingsService.refresh();
      if (snapshot == null) {
        _showSnack('未读取到可识别的设置状态');
      } else {
        _applySnapshot(snapshot);
        _showSnack('设置状态已刷新');
      }
    } on VehicleSettingsException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('设置读取失败');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _applySnapshot(VehicleSettingsSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _lightSensor = snapshot.lightSensor ?? _lightSensor;
      _startSound = snapshot.startSound ?? _startSound;
      _stopSound = snapshot.stopSound ?? _stopSound;
      _lockSound = snapshot.lockSound ?? _lockSound;
      _unlockSound = snapshot.unlockSound ?? _unlockSound;
      _speedSound = snapshot.speedSound ?? _speedSound;
      if (snapshot.sensitivityValue != null) {
        _shockSensitivityLevel = sensitivityValueToLevel(
          snapshot.sensitivityValue!,
        );
      }
    });
  }

  Future<void> _setLightSensor(bool enabled) {
    return _runSetting(
      operation: () => _settingsService.writeLightSensor(enabled),
      fallback: () => _lightSensor = enabled,
      successMessage: enabled ? '光感已开启' : '光感已关闭',
    );
  }

  Future<void> _setSound({
    bool? startSound,
    bool? stopSound,
    bool? lockSound,
    bool? unlockSound,
    bool? speedSound,
  }) {
    return _runSetting(
      operation: () => _settingsService.writeSound(
        startSound: startSound,
        stopSound: stopSound,
        lockSound: lockSound,
        unlockSound: unlockSound,
        speedSound: speedSound,
      ),
      fallback: () {
        _startSound = startSound ?? _startSound;
        _stopSound = stopSound ?? _stopSound;
        _lockSound = lockSound ?? _lockSound;
        _unlockSound = unlockSound ?? _unlockSound;
        _speedSound = speedSound ?? _speedSound;
      },
      successMessage: '声音设置已更新',
    );
  }

  Future<void> _setSensitivity(int level) {
    return _runSetting(
      operation: () => _settingsService.writeSensitivityLevel(level),
      fallback: () => _shockSensitivityLevel = level,
      successMessage: '震动灵敏度已切换为 ${_sensitivityLabelForLevel(level)}',
    );
  }

  Future<void> _runSetting({
    required Future<VehicleSettingsSnapshot?> Function() operation,
    required VoidCallback fallback,
    required String successMessage,
  }) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final snapshot = await operation();
      if (snapshot != null) {
        _applySnapshot(snapshot);
      } else if (mounted) {
        setState(fallback);
      }
      _showSnack(successMessage);
    } on VehicleSettingsException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('设置失败');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _setRidingMode(RidingMode mode) async {
    if (_sending || mode == _ridingMode) return;
    setState(() => _sending = true);
    final success = await connectionManager.setRidingMode(mode);
    if (success) {
      setState(() => _ridingMode = connectionManager.ridingMode);
      unawaited(locationService.recordDefaultVehicleLocation());
      _showSnack('骑行模式已切换为 ${connectionManager.ridingMode.label}');
    } else {
      _showSnack('骑行模式切换失败');
    }
    if (mounted) setState(() => _sending = false);
  }

  String get _sensitivityLabel =>
      _sensitivityLabelForLevel(_shockSensitivityLevel);

  String _sensitivityLabelForLevel(int level) {
    return switch (level) {
      1 => '关闭',
      2 => '低',
      3 => '中',
      _ => '高',
    };
  }

  Color get _sensitivityColor => switch (_shockSensitivityLevel) {
    1 => Colors.grey,
    2 => Colors.lightGreen,
    3 => Colors.orange,
    _ => Colors.red,
  };

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ble.ConnectionState>(
      stream: connectionManager.stateStream,
      initialData: connectionManager.state,
      builder: (context, snapshot) {
        final connState = snapshot.data ?? ble.ConnectionState.disconnected;
        final isConnected = connState == ble.ConnectionState.ready;
        final canSend = isConnected && !_sending;
        return Scaffold(
          backgroundColor: AppColors.pageBg,
          body: SafeArea(
            child: Column(
              children: [
                AppPageHeader(
                  title: '车辆设置',
                  actions: [
                    if (_sending)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: '刷新设置',
                        onPressed: isConnected ? _refreshSettings : null,
                        icon: const Icon(Icons.refresh),
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
                      const AppSectionLabel('灯光功能'),
                      SwitchListTile(
                        secondary: const Icon(Icons.wb_twilight_outlined),
                        title: const Text('光感开关'),
                        subtitle: const Text('官方 QGJ 命令 0x2410 / 0x2411'),
                        value: _lightSensor,
                        onChanged: canSend ? _setLightSensor : null,
                      ),
                      const Divider(),
                      const AppSectionLabel('声音控制'),
                      _SoundSwitchTile(
                        icon: Icons.play_circle_outline,
                        title: '启动提示音',
                        value: _startSound,
                        enabled: canSend,
                        onChanged: (value) => _setSound(startSound: value),
                      ),
                      _SoundSwitchTile(
                        icon: Icons.stop_circle_outlined,
                        title: '熄火提示音',
                        value: _stopSound,
                        enabled: canSend,
                        onChanged: (value) => _setSound(stopSound: value),
                      ),
                      _SoundSwitchTile(
                        icon: Icons.lock_clock,
                        title: '上锁提示音',
                        value: _lockSound,
                        enabled: canSend,
                        onChanged: (value) => _setSound(lockSound: value),
                      ),
                      _SoundSwitchTile(
                        icon: Icons.lock_open,
                        title: '解锁提示音',
                        value: _unlockSound,
                        enabled: canSend,
                        onChanged: (value) => _setSound(unlockSound: value),
                      ),
                      _SoundSwitchTile(
                        icon: Icons.speed,
                        title: '速度提示音',
                        value: _speedSound,
                        enabled: canSend,
                        onChanged: (value) => _setSound(speedSound: value),
                      ),
                      const Divider(),
                      const AppSectionLabel('骑行参数'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: RidingMode.values.map((mode) {
                            final selected = mode == _ridingMode;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: Material(
                                  color: selected
                                      ? AppColors.primary.withValues(
                                          alpha: 0.14,
                                        )
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: canSend
                                        ? () => _setRidingMode(mode)
                                        : null,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      height: 46,
                                      alignment: Alignment.center,
                                      child: Text(
                                        mode.label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: selected
                                              ? AppColors.primary
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const AppSectionLabel('防盗灵敏度'),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '当前: $_sensitivityLabel',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const Spacer(),
                            Text(
                              '值 ${sensitivityLevelToValue(_shockSensitivityLevel)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: _sensitivityColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: List.generate(4, (i) {
                            final level = i + 1;
                            final selected = level == _shockSensitivityLevel;
                            final label = _sensitivityLabelForLevel(level);
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: Material(
                                  color: selected
                                      ? _sensitivityColor.withValues(alpha: 0.2)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    onTap: canSend
                                        ? () => _setSensitivity(level)
                                        : null,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      height: 46,
                                      alignment: Alignment.center,
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: selected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: selected
                                              ? _sensitivityColor
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
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
  }
}

class _SoundSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SoundSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: const Text('官方 QGJ 声音调节命令'),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}
