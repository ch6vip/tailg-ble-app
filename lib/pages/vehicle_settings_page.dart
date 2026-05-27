import 'package:flutter/material.dart';
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
  bool _sending = false;

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
