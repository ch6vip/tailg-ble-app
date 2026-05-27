import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _headlight = false;
  bool _turnSignal = false;
  bool _startupSound = true;
  bool _lockSound = true;
  bool _unlockSound = true;
  bool _powerOnSound = true;
  int _buzzerVolume = 2;
  int _shockSensitivity = 3;
  RidingMode _ridingMode = RidingMode.standard;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _settingsService = VehicleSettingsService(
      connectionManager: connectionManager,
    );
    _ridingMode = connectionManager.ridingMode;
    _loadSensitivity();
  }

  Future<void> _loadSensitivity() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shockSensitivity = prefs.getInt('shock_sensitivity') ?? 3;
    });
  }

  Future<void> _saveSensitivity(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('shock_sensitivity', value);
  }

  Future<void> _refreshSettings() async {
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
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _applySnapshot(VehicleSettingsSnapshot snapshot) {
    setState(() {
      _headlight = snapshot.headlight ?? _headlight;
      _turnSignal = snapshot.turnSignal ?? _turnSignal;
      _powerOnSound = snapshot.powerOnSound ?? _powerOnSound;
      _startupSound = snapshot.startupSound ?? _startupSound;
      _unlockSound = snapshot.unlockSound ?? _unlockSound;
      _lockSound = snapshot.lockSound ?? _lockSound;
      _buzzerVolume = snapshot.buzzerVolume ?? _buzzerVolume;
    });
  }

  Future<void> _setSensitivity(int value) async {
    setState(() => _shockSensitivity = value);
    await _writeSetting(
      () => _settingsService.writeSensitivity(value),
      successMessage: '防盗灵敏度已设置为 $value',
    );
    await _saveSensitivity(_shockSensitivity);
  }

  Future<void> _writeLightSetting() {
    return _writeSetting(
      () => _settingsService.writeLight(
        headlight: _headlight,
        turnSignal: _turnSignal,
      ),
      successMessage: '灯光设置已写入',
    );
  }

  Future<void> _writeSoundSetting() {
    return _writeSetting(
      () => _settingsService.writeSound(
        powerOnSound: _powerOnSound,
        startupSound: _startupSound,
        unlockSound: _unlockSound,
        lockSound: _lockSound,
        buzzerVolume: _buzzerVolume,
      ),
      successMessage: '声音设置已写入',
    );
  }

  Future<void> _writeSetting(
    Future<VehicleSettingsSnapshot?> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _sending = true);
    try {
      final snapshot = await action();
      if (snapshot != null) _applySnapshot(snapshot);
      _showSnack(successMessage);
    } on VehicleSettingsException catch (e) {
      _showSnack(e.message);
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

  String get _sensitivityLabel => switch (_shockSensitivity) {
    1 => '最低',
    2 => '较低',
    3 => '中等',
    4 => '较高',
    _ => '最高',
  };

  Color get _sensitivityColor => switch (_shockSensitivity) {
    1 => Colors.green,
    2 => Colors.lightGreen,
    3 => Colors.orange,
    4 => Colors.deepOrange,
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
                      const AppSectionLabel('灯光控制'),
                      SwitchListTile(
                        secondary: const Icon(Icons.lightbulb_outline),
                        title: const Text('前灯'),
                        value: _headlight,
                        onChanged: isConnected
                            ? (v) {
                                setState(() => _headlight = v);
                                _writeLightSetting();
                              }
                            : null,
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.turn_slight_right),
                        title: const Text('转向灯模式'),
                        subtitle: const Text('开启后转向灯常亮'),
                        value: _turnSignal,
                        onChanged: isConnected
                            ? (v) {
                                setState(() => _turnSignal = v);
                                _writeLightSetting();
                              }
                            : null,
                      ),
                      const Divider(),
                      const AppSectionLabel('声音控制'),
                      SwitchListTile(
                        secondary: const Icon(Icons.volume_up),
                        title: const Text('启动提示音'),
                        value: _startupSound,
                        onChanged: isConnected
                            ? (v) {
                                setState(() => _startupSound = v);
                                _writeSoundSetting();
                              }
                            : null,
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.lock_clock),
                        title: const Text('上锁提示音'),
                        value: _lockSound,
                        onChanged: isConnected
                            ? (v) {
                                setState(() => _lockSound = v);
                                _writeSoundSetting();
                              }
                            : null,
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.lock_open),
                        title: const Text('解锁提示音'),
                        value: _unlockSound,
                        onChanged: isConnected
                            ? (v) {
                                setState(() => _unlockSound = v);
                                _writeSoundSetting();
                              }
                            : null,
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.power_settings_new),
                        title: const Text('通电提示音'),
                        value: _powerOnSound,
                        onChanged: isConnected
                            ? (v) {
                                setState(() => _powerOnSound = v);
                                _writeSoundSetting();
                              }
                            : null,
                      ),
                      const Divider(),
                      const AppSectionLabel('蜂鸣器音量'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.volume_mute, size: 20),
                            Expanded(
                              child: Slider(
                                value: _buzzerVolume.toDouble(),
                                min: 0,
                                max: 5,
                                divisions: 5,
                                label: '$_buzzerVolume',
                                onChanged: isConnected
                                    ? (v) {
                                        setState(
                                          () => _buzzerVolume = v.round(),
                                        );
                                      }
                                    : null,
                                onChangeEnd: isConnected
                                    ? (v) {
                                        _writeSoundSetting();
                                      }
                                    : null,
                              ),
                            ),
                            const Icon(Icons.volume_up, size: 20),
                          ],
                        ),
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
                                    onTap: isConnected
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
                              '当前等级: $_shockSensitivity',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const Spacer(),
                            Text(
                              _sensitivityLabel,
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
                          children: List.generate(5, (i) {
                            final level = i + 1;
                            final selected = level == _shockSensitivity;
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
                                    onTap: isConnected
                                        ? () => _setSensitivity(level)
                                        : null,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$level',
                                        style: TextStyle(
                                          fontSize: 16,
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '低',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            Text(
                              '高',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
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
  }
}
