import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart';
import '../models/vehicle_profile.dart';
import '../services/replica_feature_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/slide_to_action.dart';
import 'garage_page.dart';
import 'location_page.dart';
import 'official_replica_pages.dart';
import 'vehicle_settings_page.dart';

const _pageBg = Color(0xFFF5F6FA);
const _kmPerPercent = 0.65;
const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(20)),
  boxShadow: [
    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
  ],
);

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<ble.ConnectionState>(
      stream: connectionManager.stateStream,
      initialData: connectionManager.state,
      builder: (context, snapshot) {
        final connState = snapshot.data ?? ble.ConnectionState.disconnected;
        return Scaffold(
          backgroundColor: _pageBg,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                bottom: AppNav.contentBottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(connState: connState),
                  const _StatusSection(),
                  const SizedBox(height: 20),
                  const _BikeImage(),
                  _StateLabel(connState: connState),
                  const SizedBox(height: 20),
                  _ControlArea(connState: connState),
                  const SizedBox(height: 20),
                  const _LocationCard(),
                  const SizedBox(height: 20),
                  const _FunctionSettingsCard(),
                  const SizedBox(height: 20),
                  const _SoundEffectsBanner(),
                  const SizedBox(height: 20),
                  const _NfcKeyCard(),
                  const SizedBox(height: 20),
                  const _RideRecordCard(),
                  const SizedBox(height: 20),
                  _RidingModeSelector(connState: connState),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final ble.ConnectionState connState;
  const _Header({required this.connState});

  @override
  Widget build(BuildContext context) {
    final statusText = switch (connState) {
      ble.ConnectionState.disconnected => '离线',
      ble.ConnectionState.connecting => '连接中',
      ble.ConnectionState.reconnecting => '重连中',
      ble.ConnectionState.connected => '已连接',
      ble.ConnectionState.ready => '在线',
    };
    final statusColor = switch (connState) {
      ble.ConnectionState.ready => Colors.green,
      ble.ConnectionState.reconnecting => Colors.orange,
      _ => Colors.grey,
    };
    final isConnecting =
        connState == ble.ConnectionState.connecting ||
        connState == ble.ConnectionState.reconnecting;

    return StreamBuilder<List<VehicleProfile>>(
      stream: vehicleStore.vehiclesStream,
      initialData: vehicleStore.vehicles,
      builder: (context, snapshot) {
        final defaultVehicle = vehicleStore.defaultVehicle;
        final deviceName = connectionManager.device?.platformName;
        final displayName =
            defaultVehicle?.displayName ??
            (deviceName != null && deviceName.isNotEmpty
                ? deviceName
                : connState == ble.ConnectionState.disconnected
                ? '未绑定车辆'
                : '当前车辆');

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GaragePage()),
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_drop_down, size: 20),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(fontSize: 12, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: connState != ble.ConnectionState.disconnected
                    ? () => connectionManager.disconnect()
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isConnecting)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          connState == ble.ConnectionState.ready
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_disabled,
                          size: 14,
                          color: statusColor,
                        ),
                      const SizedBox(width: 6),
                      Text(statusText, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BikeState?>(
      stream: connectionManager.bikeStateStream,
      builder: (context, snapshot) {
        final bike = snapshot.data;
        final battery = bike?.batteryPercent;
        final batteryColor = battery == null
            ? Colors.grey
            : battery > 60
            ? Colors.green
            : battery > 20
            ? Colors.orange
            : Colors.red;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '剩余电量',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(
                          battery == null
                              ? Icons.battery_unknown
                              : battery > 80
                              ? Icons.battery_full
                              : battery > 60
                              ? Icons.battery_5_bar
                              : battery > 40
                              ? Icons.battery_4_bar
                              : battery > 20
                              ? Icons.battery_2_bar
                              : Icons.battery_1_bar,
                          color: batteryColor,
                          size: 32,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          battery != null ? '$battery%' : '--',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '预估里程',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          battery != null
                              ? '${(battery * _kmPerPercent).round()}'
                              : '--',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'km',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BikeImage extends StatelessWidget {
  const _BikeImage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 160,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Icon(
            Icons.electric_bike,
            size: 100,
            color: Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}

class _StateLabel extends StatelessWidget {
  final ble.ConnectionState connState;
  const _StateLabel({required this.connState});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BikeState?>(
      stream: connectionManager.bikeStateStream,
      builder: (context, snapshot) {
        final bike = snapshot.data;
        final isConnected = connState == ble.ConnectionState.ready;

        String stateText;
        IconData stateIcon;
        List<Color> gradientColors;

        if (!isConnected) {
          stateText = '未连接';
          stateIcon = Icons.bluetooth_disabled;
          gradientColors = [Colors.grey.shade300, Colors.grey.shade400];
        } else if (bike == null) {
          stateText = '等待车辆状态';
          stateIcon = Icons.sync;
          gradientColors = [Colors.blue.shade200, Colors.blue.shade300];
        } else if (bike.isLocked && !bike.isPowerOn) {
          stateText = '已设防';
          stateIcon = Icons.lock_outline;
          gradientColors = [Colors.purple.shade200, Colors.blue.shade200];
        } else if (!bike.isLocked && bike.isPowerOn) {
          stateText = '已通电';
          stateIcon = Icons.power;
          gradientColors = [Colors.green.shade300, Colors.teal.shade300];
        } else if (!bike.isLocked) {
          stateText = '已解锁';
          stateIcon = Icons.lock_open;
          gradientColors = [Colors.orange.shade200, Colors.amber.shade300];
        } else {
          stateText = '已上锁';
          stateIcon = Icons.lock_outline;
          gradientColors = [Colors.purple.shade200, Colors.blue.shade200];
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(stateIcon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      stateText,
                      key: ValueKey(stateText),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '手动模式',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 4),
                  _ManualModeToggle(enabled: isConnected),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ControlArea extends StatefulWidget {
  final ble.ConnectionState connState;
  const _ControlArea({required this.connState});

  @override
  State<_ControlArea> createState() => _ControlAreaState();
}

class _ControlAreaState extends State<_ControlArea> {
  final _replicaStore = ReplicaFeatureStore();
  QuickControlConfig _quickConfig = const QuickControlConfig();
  bool _busy = false;
  String? _activeControlId;

  @override
  void initState() {
    super.initState();
    _loadQuickConfig();
  }

  Future<void> _loadQuickConfig() async {
    final config = await _replicaStore.loadQuickControlConfig();
    if (!mounted) return;
    setState(() => _quickConfig = config);
  }

  Future<void> _send(CommandCode cmd, {required String actionId}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _activeControlId = actionId;
    });
    HapticFeedback.mediumImpact();
    try {
      final success = await connectionManager.sendCommand(cmd);
      if (success) {
        unawaited(locationService.recordDefaultVehicleLocation());
      }
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cmd.label}失败'),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activeControlId = null;
        });
      }
    }
  }

  Future<void> _runQuickAction(_QuickControlSpec spec, bool enabled) async {
    if (spec.command != null) {
      if (!enabled) return;
      await _send(spec.command!, actionId: 'quick:${spec.id}');
      return;
    }
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => spec.pageBuilder!(context)),
    );
  }

  Future<void> _editQuickControls() async {
    final next = await Navigator.push<QuickControlConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => QuickControlEditPage(initialConfig: _quickConfig),
      ),
    );
    if (next == null) return;
    await _replicaStore.saveQuickControlConfig(next);
    if (!mounted) return;
    setState(() => _quickConfig = next);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.connState == ble.ConnectionState.ready && !_busy;
    return StreamBuilder<BikeState?>(
      stream: connectionManager.bikeStateStream,
      builder: (context, snapshot) {
        final bike = snapshot.data;
        final isLocked = bike?.isLocked ?? true;
        final isPowerOn = bike?.isPowerOn ?? false;
        final firstQuick = _quickControlSpec(_quickConfig.firstActionId);
        final secondQuick = _quickControlSpec(_quickConfig.secondActionId);
        final firstQuickActive = _activeControlId == 'quick:${firstQuick.id}';
        final secondQuickActive = _activeControlId == 'quick:${secondQuick.id}';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: _cardDecoration,
            child: SizedBox(
              height: 232,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 92,
                    child: Column(
                      children: [
                        Expanded(
                          child: _ControlTile(
                            icon: firstQuick.icon,
                            label: firstQuick.label,
                            enabled: firstQuick.command == null || enabled,
                            active: firstQuickActive,
                            loading: firstQuickActive,
                            onTap: () => _runQuickAction(firstQuick, enabled),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: _ControlTile(
                                  icon: secondQuick.icon,
                                  label: secondQuick.label,
                                  enabled:
                                      secondQuick.command == null || enabled,
                                  active: secondQuickActive,
                                  loading: secondQuickActive,
                                  onTap: () =>
                                      _runQuickAction(secondQuick, enabled),
                                ),
                              ),
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: _QuickEditButton(
                                  onTap: _editQuickControls,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 86,
                          child: Center(
                            child: SlideToAction(
                              label: isPowerOn ? '左滑关闭' : '右滑启动',
                              icon: isPowerOn
                                  ? Icons.power_off
                                  : Icons.power_settings_new,
                              reverseSlide: isPowerOn,
                              backgroundColor: isPowerOn
                                  ? const Color(0xFF5D4037)
                                  : const Color(0xFF424242),
                              onSlideComplete: enabled
                                  ? () => _send(
                                      isPowerOn
                                          ? CommandCode.powerOff
                                          : CommandCode.powerOn,
                                      actionId: 'slidePower',
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _ControlTile(
                                  icon: Icons.volume_up_outlined,
                                  label: '寻车',
                                  enabled: enabled,
                                  active: _activeControlId == 'fixedFind',
                                  loading: _activeControlId == 'fixedFind',
                                  onTap: () => _send(
                                    CommandCode.find,
                                    actionId: 'fixedFind',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ControlTile(
                                  icon: isLocked
                                      ? Icons.lock_open
                                      : Icons.lock_outline,
                                  label: isLocked ? '解锁' : '设防',
                                  enabled: enabled,
                                  active: _activeControlId == 'fixedLock',
                                  loading: _activeControlId == 'fixedLock',
                                  onTap: () => _send(
                                    isLocked
                                        ? CommandCode.unlock
                                        : CommandCode.lock,
                                    actionId: 'fixedLock',
                                  ),
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
          ),
        );
      },
    );
  }
}

class _QuickControlSpec {
  final String id;
  final String label;
  final IconData icon;
  final CommandCode? command;
  final WidgetBuilder? pageBuilder;

  const _QuickControlSpec({
    required this.id,
    required this.label,
    required this.icon,
    this.command,
    this.pageBuilder,
  });
}

List<_QuickControlSpec> get _quickControlSpecs => [
  _QuickControlSpec(
    id: 'soundEffects',
    label: '声音设置',
    icon: Icons.graphic_eq,
    pageBuilder: (_) => const QgjSoundEffectsPage(),
  ),
  _QuickControlSpec(
    id: 'share',
    label: '分享用车',
    icon: Icons.ios_share,
    pageBuilder: (_) => const ShareBikePage(),
  ),
  _QuickControlSpec(
    id: 'fence',
    label: '电子围栏',
    icon: Icons.location_searching,
    pageBuilder: (_) => const ElectricFencePage(),
  ),
  _QuickControlSpec(
    id: 'nfc',
    label: 'NFC钥匙',
    icon: Icons.nfc,
    pageBuilder: (_) => const NfcKeyPage(),
  ),
  _QuickControlSpec(
    id: 'rideRecord',
    label: '骑行记录',
    icon: Icons.route_outlined,
    pageBuilder: (_) => const RideRecordPage(),
  ),
  const _QuickControlSpec(
    id: 'seat',
    label: '坐垫锁',
    icon: Icons.event_seat_outlined,
    command: CommandCode.openSeat,
  ),
  const _QuickControlSpec(
    id: 'find',
    label: '寻车',
    icon: Icons.volume_up_outlined,
    command: CommandCode.find,
  ),
];

_QuickControlSpec _quickControlSpec(String id) {
  return _quickControlSpecs.firstWhere(
    (spec) => spec.id == id,
    orElse: () => _quickControlSpecs.first,
  );
}

class QuickControlEditPage extends StatefulWidget {
  final QuickControlConfig initialConfig;

  const QuickControlEditPage({super.key, required this.initialConfig});

  @override
  State<QuickControlEditPage> createState() => _QuickControlEditPageState();
}

class _QuickControlEditPageState extends State<QuickControlEditPage> {
  late String _firstActionId;
  late String _secondActionId;

  @override
  void initState() {
    super.initState();
    _firstActionId = widget.initialConfig.firstActionId;
    _secondActionId = widget.initialConfig.secondActionId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '添加快捷键',
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    QuickControlConfig(
                      firstActionId: _firstActionId,
                      secondActionId: _secondActionId,
                    ),
                  ),
                  child: const Text('保存'),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _QuickEditSection(
                    title: '快捷功能1',
                    subtitle: '点击选择快捷功能',
                    selectedId: _firstActionId,
                    specs: _quickControlSpecs
                        .where((spec) => spec.command == null)
                        .toList(growable: false),
                    onSelected: (id) => setState(() => _firstActionId = id),
                  ),
                  _QuickEditSection(
                    title: '快捷功能2',
                    subtitle: '建议放置电子坐垫锁',
                    selectedId: _secondActionId,
                    specs: _quickControlSpecs
                        .where(
                          (spec) =>
                              spec.id == 'seat' ||
                              spec.id == 'find' ||
                              spec.command == null,
                        )
                        .toList(growable: false),
                    onSelected: (id) => setState(() => _secondActionId = id),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      '* 车辆命令仅使用已验证的本地 BLE 控车命令；页面入口不会写入车辆。',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
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

class _QuickEditSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String selectedId;
  final List<_QuickControlSpec> specs;
  final ValueChanged<String> onSelected;

  const _QuickEditSection({
    required this.title,
    required this.subtitle,
    required this.selectedId,
    required this.specs,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '（$subtitle）',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: specs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemBuilder: (context, index) {
              final spec = specs[index];
              final selected = spec.id == selectedId;
              return _QuickEditOption(
                spec: spec,
                selected: selected,
                onTap: () => onSelected(spec.id),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickEditOption extends StatelessWidget {
  final _QuickControlSpec spec;
  final bool selected;
  final VoidCallback onTap;

  const _QuickEditOption({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(spec.icon, color: color, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      spec.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  right: 8,
                  bottom: 8,
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool active;
  final bool loading;
  final VoidCallback onTap;

  const _ControlTile({
    required this.icon,
    required this.label,
    required this.enabled,
    this.active = false,
    required this.loading,
    required this.onTap,
  });

  @override
  State<_ControlTile> createState() => _ControlTileState();
}

class _ControlTileState extends State<_ControlTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.enabled && !widget.loading;
    final color = widget.active
        ? AppColors.primary
        : widget.enabled
        ? AppColors.textSecondary
        : AppColors.textTertiary;
    final background = widget.active
        ? AppColors.primary.withValues(alpha: 0.12)
        : _pressed
        ? AppColors.primary.withValues(alpha: 0.08)
        : widget.enabled
        ? Colors.grey.shade100
        : const Color(0xFFF2F2F2);
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      scale: _pressed ? 0.96 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.active
                ? AppColors.primary.withValues(alpha: 0.32)
                : Colors.transparent,
            width: 1.2,
          ),
          boxShadow: widget.active
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: interactive
                ? () {
                    _setPressed(false);
                    HapticFeedback.mediumImpact();
                    widget.onTap();
                  }
                : null,
            onTapDown: interactive ? (_) => _setPressed(true) : null,
            onTapCancel: interactive ? () => _setPressed(false) : null,
            onTapUp: interactive ? (_) => _setPressed(false) : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: widget.loading
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: color,
                            ),
                          )
                        : Icon(
                            widget.icon,
                            key: ValueKey(widget.icon),
                            color: color,
                            size: widget.active ? 28 : 26,
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.1,
                      color: color,
                      fontWeight: widget.active
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickEditButton extends StatelessWidget {
  final VoidCallback onTap;

  const _QuickEditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: Icon(Icons.edit, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

class _FunctionSettingsCard extends StatelessWidget {
  const _FunctionSettingsCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: _cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '功能设置',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _FunctionShortcut(
                    icon: Icons.tune,
                    label: '车辆设置',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VehicleSettingsPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FunctionShortcut(
                    icon: Icons.location_searching,
                    label: '电子围栏',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ElectricFencePage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FunctionShortcut(
                    icon: Icons.ios_share,
                    label: '分享用车',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ShareBikePage()),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FunctionShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FunctionShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 86,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: AppColors.textSecondary),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoundEffectsBanner extends StatelessWidget {
  const _SoundEffectsBanner();

  @override
  Widget build(BuildContext context) {
    return _HomeFeatureCard(
      icon: Icons.graphic_eq,
      title: 'QGJ音效设置',
      subtitle: '复刻官方音效入口，当前不写入车辆',
      accent: const Color(0xFF00A896),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QgjSoundEffectsPage()),
      ),
    );
  }
}

class _NfcKeyCard extends StatelessWidget {
  const _NfcKeyCard();

  @override
  Widget build(BuildContext context) {
    return _HomeFeatureCard(
      icon: Icons.nfc,
      title: 'NFC钥匙',
      subtitle: '刷卡骑行新体验，本地钥匙列表',
      accent: const Color(0xFF7B61FF),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NfcKeyPage()),
      ),
    );
  }
}

class _RideRecordCard extends StatelessWidget {
  const _RideRecordCard();

  @override
  Widget build(BuildContext context) {
    return _HomeFeatureCard(
      icon: Icons.route_outlined,
      title: '今日骑行记录',
      subtitle: '查看本地控车、定位和操作记录',
      accent: const Color(0xFFFF8A00),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RideRecordPage()),
      ),
    );
  }
}

class _HomeFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _HomeFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: _cardDecoration,
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RidingModeSelector extends StatelessWidget {
  final ble.ConnectionState connState;
  const _RidingModeSelector({required this.connState});

  @override
  Widget build(BuildContext context) {
    final enabled = connState == ble.ConnectionState.ready;
    return StreamBuilder<RidingMode>(
      stream: connectionManager.ridingModeStream,
      initialData: connectionManager.ridingMode,
      builder: (context, snapshot) {
        final currentMode = snapshot.data ?? RidingMode.standard;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '骑行模式',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: RidingMode.values.map((mode) {
                    final selected = mode == currentMode;
                    final icon = switch (mode) {
                      RidingMode.eco => Icons.eco,
                      RidingMode.standard => Icons.speed,
                      RidingMode.sport => Icons.bolt,
                    };
                    final color = switch (mode) {
                      RidingMode.eco => Colors.green,
                      RidingMode.standard => Colors.blue,
                      RidingMode.sport => Colors.orange,
                    };
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Material(
                          color: selected
                              ? color.withValues(alpha: 0.15)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: enabled && !selected
                                ? () async {
                                    HapticFeedback.mediumImpact();
                                    await connectionManager.setRidingMode(mode);
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: [
                                  Icon(
                                    icon,
                                    color: selected
                                        ? color
                                        : Colors.grey.shade500,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mode.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: selected
                                          ? color
                                          : Colors.grey.shade600,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
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
        );
      },
    );
  }
}

class _ManualModeToggle extends StatefulWidget {
  final bool enabled;
  const _ManualModeToggle({required this.enabled});

  @override
  State<_ManualModeToggle> createState() => _ManualModeToggleState();
}

class _ManualModeToggleState extends State<_ManualModeToggle> {
  bool _manualMode = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled
          ? () {
              setState(() => _manualMode = !_manualMode);
              HapticFeedback.selectionClick();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: _manualMode
              ? const Color(0xFF1E88E5)
              : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(13),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: _manualMode ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LocationPage()),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '车辆位置',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
