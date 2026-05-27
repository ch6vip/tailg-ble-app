import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../services/log_service.dart';

class VehicleSettingsPage extends StatefulWidget {
  const VehicleSettingsPage({super.key});

  @override
  State<VehicleSettingsPage> createState() => _VehicleSettingsPageState();
}

class _VehicleSettingsPageState extends State<VehicleSettingsPage> {
  final _log = LogService();
  bool _headlight = false;
  bool _turnSignal = false;
  bool _startupSound = true;
  bool _lockSound = true;
  bool _unlockSound = true;
  bool _powerOnSound = true;
  int _buzzerVolume = 2;
  int _shockSensitivity = 3;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _writeFcc1(List<int> data, {int retries = 2}) async {
    if (connectionManager.state != ble.ConnectionState.ready) {
      _showSnack('未连接车辆');
      return;
    }

    setState(() => _sending = true);

    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        final char = _getFcc1Char();
        if (char == null) {
          _showSnack('fcc1 特征未找到');
          break;
        }
        await char.write(data, withoutResponse: false);
        _log.operation('fcc1 写入成功', detail: data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' '));

        await Future.delayed(const Duration(milliseconds: 200));
        await _readBackState(char);

        setState(() => _sending = false);
        return;
      } catch (e) {
        if (attempt == retries) {
          _log.operation('fcc1 写入失败', detail: e.toString(), level: LogLevel.error);
          _showSnack('写入失败，请重试');
        } else {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    setState(() => _sending = false);
  }

  dynamic _getFcc1Char() {
    final device = connectionManager.device;
    if (device == null) return null;
    // Access through the discovered services cache in flutter_blue_plus
    for (final service in device.servicesList) {
      if (service.serviceUuid.toString().contains('fcc0')) {
        for (final c in service.characteristics) {
          if (c.characteristicUuid.toString().contains('fcc1')) return c;
        }
      }
    }
    return null;
  }

  Future<void> _readBackState(dynamic char) async {
    try {
      final response = await char.read();
      if (response.isEmpty) return;
      _log.operation('fcc1 读回', detail: response.map((b) => (b as int).toRadixString(16).padLeft(2, '0')).join(' '));
      _parseDeviceState(List<int>.from(response));
    } catch (e) {
      _log.operation('fcc1 读取失败', detail: e.toString(), level: LogLevel.debug);
    }
  }

  void _parseDeviceState(List<int> data) {
    if (data.length < 7 && data.length < 11) return;

    if (data.length >= 7 && data[0] == 0x00 && data[1] == 0x07) {
      setState(() {
        _headlight = (data[4] & 0x01) != 0;
        _turnSignal = (data[4] & 0x02) != 0;
      });
      _showSnack('灯光状态已刷新');
    } else if (data.length >= 11 && data[0] == 0x85) {
      setState(() {
        _powerOnSound = data[5] != 0;
        _startupSound = data[6] != 0;
        _unlockSound = data[7] != 0;
        _lockSound = data[8] != 0;
        _buzzerVolume = data[10].clamp(0, 5);
      });
      _showSnack('声音状态已刷新');
    }
  }

  List<int> _buildSoundCommand() {
    // Format: 85 06 4A 3C 02 [powerOn] [powerOff] [unlock] [lock] [01] [induction]
    return [
      0x85, 0x06, 0x4A, 0x3C, 0x02,
      _powerOnSound ? 0x01 : 0x00,
      _startupSound ? 0x01 : 0x00,
      _unlockSound ? 0x01 : 0x00,
      _lockSound ? 0x01 : 0x00,
      0x01,
      _buzzerVolume & 0xFF,
    ];
  }

  List<int> _buildLightCommand() {
    // Format: 00 07 00 02 [state1] [state2] [state3]
    int state1 = 0;
    if (_headlight) state1 |= 0x01;
    if (_turnSignal) state1 |= 0x02;
    return [0x00, 0x07, 0x00, 0x02, state1, 0x00, 0x00];
  }

  List<int> _buildSensitivityCommand() {
    // Shock sensitivity via fcc1: A7 00 00 04 10 03 [level] [level]
    // level 1-5 maps to sensitivity (1=lowest, 5=highest)
    return [0xA7, 0x00, 0x00, 0x04, 0x10, 0x03, _shockSensitivity, _shockSensitivity];
  }

  Future<void> _setSensitivity(int value) async {
    setState(() => _shockSensitivity = value);
    await _writeFcc1(_buildSensitivityCommand());
    await _saveSensitivity(value);
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
    final isConnected = connectionManager.state == ble.ConnectionState.ready;
    return Scaffold(
      appBar: AppBar(
        title: const Text('车辆设置'),
        actions: [
          if (_sending)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: ListView(
        children: [
          _SectionHeader('灯光控制'),
          SwitchListTile(
            secondary: const Icon(Icons.lightbulb_outline),
            title: const Text('前灯'),
            value: _headlight,
            onChanged: isConnected ? (v) {
              setState(() => _headlight = v);
              _writeFcc1(_buildLightCommand());
            } : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.turn_slight_right),
            title: const Text('转向灯模式'),
            subtitle: const Text('开启后转向灯常亮'),
            value: _turnSignal,
            onChanged: isConnected ? (v) {
              setState(() => _turnSignal = v);
              _writeFcc1(_buildLightCommand());
            } : null,
          ),
          const Divider(),
          _SectionHeader('声音控制'),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up),
            title: const Text('启动提示音'),
            value: _startupSound,
            onChanged: isConnected ? (v) {
              setState(() => _startupSound = v);
              _writeFcc1(_buildSoundCommand());
            } : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock_clock),
            title: const Text('上锁提示音'),
            value: _lockSound,
            onChanged: isConnected ? (v) {
              setState(() => _lockSound = v);
              _writeFcc1(_buildSoundCommand());
            } : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock_open),
            title: const Text('解锁提示音'),
            value: _unlockSound,
            onChanged: isConnected ? (v) {
              setState(() => _unlockSound = v);
              _writeFcc1(_buildSoundCommand());
            } : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.power_settings_new),
            title: const Text('通电提示音'),
            value: _powerOnSound,
            onChanged: isConnected ? (v) {
              setState(() => _powerOnSound = v);
              _writeFcc1(_buildSoundCommand());
            } : null,
          ),
          const Divider(),
          _SectionHeader('蜂鸣器音量'),
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
                    onChanged: isConnected ? (v) {
                      setState(() => _buzzerVolume = v.round());
                    } : null,
                    onChangeEnd: isConnected ? (v) {
                      _writeFcc1(_buildSoundCommand());
                    } : null,
                  ),
                ),
                const Icon(Icons.volume_up, size: 20),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader('防盗灵敏度'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 20),
                const SizedBox(width: 12),
                Text('当前等级: $_shockSensitivity',
                    style: const TextStyle(fontSize: 14)),
                const Spacer(),
                Text(_sensitivityLabel,
                    style: TextStyle(fontSize: 13, color: _sensitivityColor)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Material(
                      color: selected
                          ? _sensitivityColor.withValues(alpha: 0.2)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: isConnected ? () => _setSensitivity(level) : null,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          child: Text('$level',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                color: selected ? _sensitivityColor : Colors.grey.shade600,
                              )),
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
                Text('低', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                Text('高', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (!isConnected)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('请先连接车辆', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary)),
    );
  }
}
