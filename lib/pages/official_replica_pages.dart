import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart'; // P0-6: service locator getters
import '../models/geo_coordinate.dart';
import '../models/vehicle_profile.dart';
import '../services/ble_nfc_service.dart';
import '../services/display_time_formatter.dart';
import '../services/log_service.dart';
import '../services/replica_feature_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/lucide_icon.dart';

const _replicaCardDecoration = BoxDecoration(
  color: CyberHomeColors.card,
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.tile)),
  border: Border.fromBorderSide(BorderSide(color: CyberHomeColors.line)),
);

const _replicaPageTitle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w700,
  color: CyberHomeColors.ink,
);

const _replicaItemTitle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: CyberHomeColors.ink,
);

const _replicaBodyText = TextStyle(
  fontSize: 13,
  height: 1.45,
  color: CyberHomeColors.inkMuted,
);

const _replicaCaptionText = TextStyle(
  fontSize: 12,
  color: CyberHomeColors.inkFaint,
);

final _replicaFilledButtonStyle = FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(48),
  backgroundColor: CyberHomeColors.primary,
  foregroundColor: CyberHomeColors.white,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.tile),
  ),
);

InputDecoration _replicaInputDecoration(String label) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.tile),
    borderSide: const BorderSide(color: CyberHomeColors.lineStrong),
  );
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: CyberHomeColors.cardMuted,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: CyberHomeColors.primary),
    ),
  );
}

class _ReplicaPageHeader extends StatelessWidget {
  const _ReplicaPageHeader({
    required this.title,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          _ReplicaHeaderAction(
            icon: Lucide.arrowLeft,
            label: '返回',
            filled: true,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _replicaPageTitle,
            ),
          ),
          _ReplicaHeaderAction(
            icon: actionIcon,
            label: actionLabel,
            onTap: onAction,
          ),
        ],
      ),
    );
  }
}

class _ReplicaHeaderAction extends StatelessWidget {
  const _ReplicaHeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: AppPressable(
        onTap: onTap,
        semanticsLabel: label,
        semanticsButton: true,
        child: SizedBox(
          width: AppTouchTargets.min,
          height: AppTouchTargets.min,
          child: Center(
            child: Container(
              width: filled ? AppTouchTargets.min : 36,
              height: filled ? AppTouchTargets.min : 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filled
                    ? CyberHomeColors.card
                    : CyberHomeColors.transparent,
                shape: BoxShape.circle,
                boxShadow: filled ? AppShadows.cyberActionShadow : const [],
              ),
              child: LucideIcon(
                icon,
                size: 20,
                color: CyberHomeColors.inkSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplicaSectionLabel extends StatelessWidget {
  const _ReplicaSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: CyberHomeColors.inkMuted,
      ),
    );
  }
}

class NfcKeyPage extends StatefulWidget {
  const NfcKeyPage({super.key});

  @override
  State<NfcKeyPage> createState() => _NfcKeyPageState();
}

class _NfcKeyPageState extends State<NfcKeyPage> {
  final _store = ReplicaFeatureStore();
  late final BleNfcService _bleNfc = BleNfcService(
    connectionManager: connectionManager,
  );
  List<NfcKeyRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final records = await _store.loadNfcKeys();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _save(List<NfcKeyRecord> records) async {
    await _store.saveNfcKeys(records);
    if (!mounted) return;
    setState(() => _records = records);
  }

  Future<void> _editKey({NfcKeyRecord? record}) async {
    final nameController = TextEditingController(text: record?.name ?? '');
    var type = record?.type ?? '手机';
    final result = await showDialog<NfcKeyRecord>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: CyberHomeColors.card,
              surfaceTintColor: CyberHomeColors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              titleTextStyle: _replicaItemTitle.copyWith(fontSize: 18),
              title: Text(record == null ? '添加钥匙' : '编辑钥匙'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: _replicaInputDecoration('钥匙名称'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const ['手机', '手表', '卡片']
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => type = value);
                      }
                    },
                    decoration: _replicaInputDecoration('钥匙类型'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: CyberHomeColors.inkMuted,
                  ),
                  child: const Text('取消'),
                ),
                FilledButton(
                  style: _replicaFilledButtonStyle,
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(
                      context,
                      record == null
                          ? _store.createNfcKey(name: name, type: type)
                          : record.copyWith(name: name, type: type),
                    );
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    if (!mounted) return;
    if (result == null) return;

    // P3-6: when standard LOGIN, also push official BLE NFC frames.
    if (record == null && _bleNfc.canWriteOfficialNfc) {
      final ok = type == '卡片'
          ? await _bleNfc.addCard('01')
          : await _bleNfc.addUserKey(keyType: type == '手表' ? 2 : 1, type: '1');
      if (!mounted) return;
      if (ok) {
        AppSnack.success(context, '已向车辆发送官方 NFC 写钥匙指令');
      } else {
        AppSnack.info(context, '官方 NFC 写入失败，仅保存本地列表');
      }
    } else if (record == null && !_bleNfc.canWriteOfficialNfc) {
      AppSnack.info(context, '未 standard LOGIN：仅本地列表（不会写车）');
    }

    final next = [..._records];
    final index = next.indexWhere((item) => item.id == result.id);
    if (index >= 0) {
      next[index] = result;
    } else {
      next.add(result);
    }
    await _save(next);
  }

  Future<void> _deleteKey(NfcKeyRecord record) async {
    if (_bleNfc.canWriteOfficialNfc) {
      final ok = await _bleNfc.delNfc('01');
      if (mounted) {
        AppSnack.info(context, ok ? '已发送官方删钥匙指令' : '官方删钥匙失败，仅移除本地列表');
      }
    }
    await _save(_records.where((item) => item.id != record.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final canBle = _bleNfc.canWriteOfficialNfc;
    return Scaffold(
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _ReplicaPageHeader(
              title: 'NFC钥匙',
              actionIcon: Lucide.plus,
              actionLabel: '添加钥匙',
              onAction: () => _editKey(),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  const _ReplicaSectionLabel('官方 / 本地'),
                  const SizedBox(height: 8),
                  _ReplicaNotice(
                    icon: Lucide.nfc,
                    margin: EdgeInsets.zero,
                    title: canBle ? '官方 BLE NFC 可用' : '官方 NFC 待 LOGIN',
                    subtitle: canBle
                        ? '当前 standard 协议已 LOGIN：添加/删除将下发官方 writeData 帧（TailgBleConfig NFC 头），并同步本地列表。'
                        : '未 standard LOGIN 时仅维护本地列表，不会写车。请先 BLE 连接并完成协议登录。',
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          color: CyberHomeColors.primary,
                        ),
                      ),
                    )
                  else if (_records.isEmpty)
                    const _EmptyReplicaCard(
                      icon: Lucide.keyOff,
                      margin: EdgeInsets.zero,
                      title: '暂无钥匙',
                      subtitle: '添加后可在这里查看钥匙名称和类型。',
                    )
                  else
                    Container(
                      decoration: _replicaCardDecoration,
                      child: Column(
                        children: [
                          for (var i = 0; i < _records.length; i++) ...[
                            _NfcKeyTile(
                              record: _records[i],
                              onEdit: () => _editKey(record: _records[i]),
                              onDelete: () => _deleteKey(_records[i]),
                            ),
                            if (i != _records.length - 1)
                              const Divider(
                                height: 1,
                                indent: 68,
                                color: CyberHomeColors.line,
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

class ElectricFencePage extends StatefulWidget {
  const ElectricFencePage({super.key});

  @override
  State<ElectricFencePage> createState() => _ElectricFencePageState();
}

class _ElectricFencePageState extends State<ElectricFencePage> {
  final _store = ReplicaFeatureStore();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '500');
  bool _enabled = false;
  bool _loading = true;
  VehicleLocation? _lastLocation;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await vehicleStore.init();
    final config = await _store.loadFenceConfig();
    final lastLocation = vehicleStore.defaultVehicle?.lastLocation;
    final latitude = config?.latitude ?? lastLocation?.latitude;
    final longitude = config?.longitude ?? lastLocation?.longitude;
    if (!mounted) return;
    setState(() {
      _lastLocation = lastLocation;
      _enabled = config?.enabled ?? false;
      _latController.text = latitude?.toStringAsFixed(6) ?? '';
      _lngController.text = longitude?.toStringAsFixed(6) ?? '';
      _radiusController.text = (config?.radiusMeters ?? 500).toString();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final latitude = double.tryParse(_latController.text.trim());
    final longitude = double.tryParse(_lngController.text.trim());
    final radius = int.tryParse(_radiusController.text.trim()) ?? 500;
    if (latitude == null || longitude == null) {
      AppSnack.info(context, '请输入有效坐标');
      return;
    }
    if (radius < 100 || radius > 10000) {
      AppSnack.info(context, '半径建议设置在 100-10000 米');
      return;
    }
    await _store.saveFenceConfig(
      _store.createFenceConfig(
        enabled: _enabled,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radius,
      ),
    );
    if (!mounted) return;
    AppSnack.info(context, '已保存为本地草稿（未同步官方围栏）');
  }

  Future<void> _openMap() async {
    final latitude = double.tryParse(_latController.text.trim());
    final longitude = double.tryParse(_lngController.text.trim());
    if (latitude == null || longitude == null) {
      AppSnack.info(context, '请输入有效坐标');
      return;
    }
    final uri = googleMapsSearchUri(latitude, longitude);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      AppSnack.info(context, '无法打开地图');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '本地草稿围栏'),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const AppSectionLabel('本地草稿（非官方）'),
                  const _ReplicaNotice(
                    icon: Lucide.locationSearching,
                    title: '非官方云围栏',
                    subtitle: '此页只写本地草稿，不会同步官方电子围栏。正式围栏请用定位页「电子围栏」云端能力。',
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('启用围栏'),
                            subtitle: const Text('开启后保存当前围栏设置'),
                            value: _enabled,
                            onChanged: (value) =>
                                setState(() => _enabled = value),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '中心纬度',
                              prefixIcon: Icon(Lucide.explore),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _lngController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '中心经度',
                              prefixIcon: Icon(Lucide.explore),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _radiusController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '半径（米）',
                              prefixIcon: Icon(Lucide.circleDot),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _lastLocation == null
                                      ? null
                                      : () {
                                          final lastLocation = _lastLocation;
                                          if (lastLocation == null) return;
                                          _latController.text = lastLocation
                                              .latitude
                                              .toStringAsFixed(6);
                                          _lngController.text = lastLocation
                                              .longitude
                                              .toStringAsFixed(6);
                                        },
                                  icon: const Icon(Lucide.locate),
                                  label: const Text('使用最后位置'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _openMap,
                                  icon: const Icon(Lucide.map),
                                  label: const Text('打开地图'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _save,
                              icon: const Icon(Lucide.save),
                              label: const Text('保存围栏'),
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
  }
}

class ShareBikePage extends StatefulWidget {
  const ShareBikePage({super.key});

  @override
  State<ShareBikePage> createState() => _ShareBikePageState();
}

class _ShareBikePageState extends State<ShareBikePage> {
  final _store = ReplicaFeatureStore();
  List<ShareMemberRecord> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final members = await _store.loadShareMembers();
    if (!mounted) return;
    setState(() {
      _members = members;
      _loading = false;
    });
  }

  Future<void> _save(List<ShareMemberRecord> members) async {
    await _store.saveShareMembers(members);
    if (!mounted) return;
    setState(() => _members = members);
  }

  Future<void> _editMember({ShareMemberRecord? member}) async {
    final nameController = TextEditingController(text: member?.name ?? '');
    final phoneController = TextEditingController(text: member?.phone ?? '');
    final result = await showDialog<ShareMemberRecord>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberHomeColors.card,
        surfaceTintColor: CyberHomeColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
        ),
        titleTextStyle: _replicaItemTitle.copyWith(fontSize: 18),
        title: Text(member == null ? '添加成员' : '编辑成员'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: _replicaInputDecoration('成员名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: _replicaInputDecoration('手机号/备注'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: CyberHomeColors.inkMuted,
            ),
            child: const Text('取消'),
          ),
          FilledButton(
            style: _replicaFilledButtonStyle,
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(
                context,
                member == null
                    ? _store.createShareMember(
                        name: name,
                        phone: phoneController.text.trim(),
                      )
                    : member.copyWith(
                        name: name,
                        phone: phoneController.text.trim(),
                      ),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    nameController.dispose();
    phoneController.dispose();
    if (!mounted) return;
    if (result == null) return;
    final next = [..._members];
    final index = next.indexWhere((item) => item.id == result.id);
    if (index >= 0) {
      next[index] = result;
    } else {
      next.add(result);
    }
    await _save(next);
  }

  Future<void> _deleteMember(ShareMemberRecord member) async {
    await _save(_members.where((item) => item.id != member.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _ReplicaPageHeader(
              title: '分享用车',
              actionIcon: Lucide.userPlus,
              actionLabel: '添加成员',
              onAction: () => _editMember(),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  const _ReplicaSectionLabel('家庭共享（本地演示）'),
                  const SizedBox(height: 8),
                  const _ReplicaNotice(
                    icon: Lucide.share,
                    margin: EdgeInsets.zero,
                    title: '本地演示 · 非官方家庭共享',
                    subtitle: '仅本机记录联系人草稿，不会调用官方家庭共享 API。正式分享请使用官方 App 授权流程。',
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          color: CyberHomeColors.primary,
                        ),
                      ),
                    )
                  else if (_members.isEmpty)
                    const _EmptyReplicaCard(
                      icon: Lucide.groupOff,
                      margin: EdgeInsets.zero,
                      title: '暂无共享成员',
                      subtitle: '添加成员后可在这里查看共享联系人。',
                    )
                  else
                    Container(
                      decoration: _replicaCardDecoration,
                      child: Column(
                        children: [
                          for (var i = 0; i < _members.length; i++) ...[
                            _ShareMemberTile(
                              member: _members[i],
                              onEdit: () => _editMember(member: _members[i]),
                              onDelete: () => _deleteMember(_members[i]),
                            ),
                            if (i != _members.length - 1)
                              const Divider(
                                height: 1,
                                indent: 68,
                                color: CyberHomeColors.line,
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

class RideRecordPage extends StatelessWidget {
  static const _recentLogLimit = 12;

  const RideRecordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = _recentOperationLogs();
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: StreamBuilder<List<VehicleProfile>>(
          stream: vehicleStore.vehiclesStream,
          initialData: vehicleStore.vehicles,
          builder: (context, snapshot) {
            final vehicle = vehicleStore.defaultVehicle;
            final location = vehicle?.lastLocation;
            final cloudState = officialCloudService.state;
            final cloudVehicle = cloudState.signedIn
                ? cloudState.selectedVehicle
                : null;
            final displayName =
                vehicle?.displayName ?? cloudVehicle?.displayName ?? '未绑定';
            return Column(
              children: [
                const AppPageHeader(title: '今日骑行记录'),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      const AppSectionLabel('今日概览'),
                      AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: _MetricBlock(
                                label: '默认车辆',
                                value: displayName,
                              ),
                            ),
                            Expanded(
                              child: _MetricBlock(
                                label: '本次日志',
                                value: logs.length.toString(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppCard(
                        child: Row(
                          children: [
                            const Icon(Lucide.mapPin, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                location == null
                                    ? '暂无最后位置记录'
                                    : '${location.coordinateText} · ${formatDateMinuteText(location.recordedAt)}',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const AppSectionLabel('最近操作'),
                      if (logs.isEmpty)
                        const _EmptyReplicaCard(
                          icon: Lucide.route,
                          title: '暂无骑行记录',
                          subtitle: '控车、定位、诊断等本地事件会出现在这里。',
                        )
                      else
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (var i = 0; i < logs.length; i++) ...[
                                ListTile(
                                  leading: const Icon(Lucide.history),
                                  title: Text(logs[i].message),
                                  subtitle: Text(_logSubtitle(logs[i])),
                                ),
                                if (i != logs.length - 1)
                                  const Divider(
                                    height: 1,
                                    indent: 72,
                                    color: AppColors.border,
                                  ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<LogEntry> _recentOperationLogs() {
    final logs = logService.byCategory(LogCategory.operation);
    final firstIncluded = logs.length > _recentLogLimit
        ? logs.length - _recentLogLimit
        : 0;
    final entries = <LogEntry>[];
    for (var i = logs.length - 1; i >= firstIncluded; i--) {
      entries.add(logs[i]);
    }
    return entries;
  }

  String _logSubtitle(LogEntry entry) {
    final detail = entry.detail;
    return [
      formatDateMinuteText(entry.time),
      if (detail != null) detail,
    ].join('  ');
  }
}

class _NfcKeyTile extends StatelessWidget {
  final NfcKeyRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NfcKeyTile({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 68,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: _CircleIcon(
        icon: record.type == '卡片'
            ? Lucide.creditCard
            : record.type == '手表'
            ? Lucide.watch
            : Lucide.smartphone,
      ),
      title: Text(record.name),
      titleTextStyle: _replicaItemTitle,
      subtitle: Text('${record.type} · ${formatDateText(record.createdAt)}'),
      subtitleTextStyle: _replicaCaptionText,
      trailing: PopupMenuButton<String>(
        tooltip: '钥匙操作',
        color: CyberHomeColors.card,
        surfaceTintColor: CyberHomeColors.transparent,
        icon: const LucideIcon(Lucide.more, color: CyberHomeColors.inkMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
        ),
        onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('重命名')),
          PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }
}

class _ShareMemberTile extends StatelessWidget {
  final ShareMemberRecord member;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ShareMemberTile({
    required this.member,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 68,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: const _CircleIcon(icon: Lucide.mine),
      title: Text(member.name),
      titleTextStyle: _replicaItemTitle,
      subtitle: Text(
        member.phone.isEmpty
            ? '待邀请 · ${formatDateText(member.createdAt)}'
            : '${member.phone} · 待邀请',
      ),
      subtitleTextStyle: _replicaCaptionText,
      trailing: PopupMenuButton<String>(
        tooltip: '成员操作',
        color: CyberHomeColors.card,
        surfaceTintColor: CyberHomeColors.transparent,
        icon: const LucideIcon(Lucide.more, color: CyberHomeColors.inkMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
        ),
        onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('编辑')),
          PopupMenuItem(value: 'delete', child: Text('移除')),
        ],
      ),
    );
  }
}

class _ReplicaNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final EdgeInsetsGeometry margin;

  const _ReplicaNotice({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpacing.screenX),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyberHomeColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: CyberHomeColors.line),
      ),
      child: Row(
        children: [
          _CircleIcon(icon: icon, color: CyberHomeColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _replicaItemTitle),
                const SizedBox(height: 4),
                Text(subtitle, style: _replicaBodyText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReplicaCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final EdgeInsetsGeometry margin;

  const _EmptyReplicaCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpacing.screenX),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(20),
      decoration: _replicaCardDecoration,
      child: Column(
        children: [
          LucideIcon(
            icon,
            size: AppIconSizes.xl,
            color: CyberHomeColors.inkFaint,
          ),
          const SizedBox(height: 10),
          Text(title, style: _replicaItemTitle),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: _replicaBodyText),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.smallText),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.subPageTitle,
        ),
      ],
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _CircleIcon({required this.icon, this.color = CyberHomeColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: LucideIcon(icon, color: color, size: AppIconSizes.md),
    );
  }
}
