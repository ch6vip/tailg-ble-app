import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart'; // P0-6: service locator getters
import '../models/geo_coordinate.dart';
import '../models/vehicle_profile.dart';
import '../services/display_time_formatter.dart';
import '../services/log_service.dart';
import '../services/replica_feature_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_snack.dart';

class NfcKeyPage extends StatefulWidget {
  const NfcKeyPage({super.key});

  @override
  State<NfcKeyPage> createState() => _NfcKeyPageState();
}

class _NfcKeyPageState extends State<NfcKeyPage> {
  final _store = ReplicaFeatureStore();
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
              title: Text(record == null ? '添加钥匙' : '编辑钥匙'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '钥匙名称'),
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
                    decoration: const InputDecoration(labelText: '钥匙类型'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
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
    await _save(_records.where((item) => item.id != record.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'NFC钥匙',
              actions: [
                IconButton(
                  tooltip: '添加钥匙',
                  onPressed: () => _editKey(),
                  icon: const Icon(Icons.add, semanticLabel: '添加'),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const AppSectionLabel('我的钥匙'),
                  const _ReplicaNotice(
                    icon: Icons.nfc,
                    title: 'NFC钥匙服务',
                    subtitle: '可管理手机、手表和卡片钥匙；添加或删除真实钥匙请按官方授权流程完成。',
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_records.isEmpty)
                    const _EmptyReplicaCard(
                      icon: Icons.key_off_outlined,
                      title: '暂无钥匙',
                      subtitle: '添加后可在这里查看钥匙名称和类型。',
                    )
                  else
                    AppCard(
                      padding: EdgeInsets.zero,
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
    AppSnack.info(context, '电子围栏配置已保存');
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
            const AppPageHeader(title: '电子围栏'),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const AppSectionLabel('围栏设置'),
                  const _ReplicaNotice(
                    icon: Icons.location_searching,
                    title: '电子围栏服务',
                    subtitle: '设置车辆安全范围后，可用于后续位置提醒和安全守护。',
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
                              prefixIcon: Icon(Icons.explore_outlined),
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
                              prefixIcon: Icon(Icons.explore),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _radiusController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '半径（米）',
                              prefixIcon: Icon(Icons.radio_button_checked),
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
                                  icon: const Icon(Icons.my_location),
                                  label: const Text('使用最后位置'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _openMap,
                                  icon: const Icon(Icons.map_outlined),
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
                              icon: const Icon(Icons.save_outlined),
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
        title: Text(member == null ? '添加成员' : '编辑成员'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '成员名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '手机号/备注'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
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
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '分享用车',
              actions: [
                IconButton(
                  tooltip: '添加成员',
                  onPressed: () => _editMember(),
                  icon: const Icon(Icons.person_add_alt_1),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const AppSectionLabel('家庭共享'),
                  const _ReplicaNotice(
                    icon: Icons.ios_share,
                    title: '家庭共享',
                    subtitle: '可记录常用共享成员；正式授权请通过官方分享流程完成。',
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_members.isEmpty)
                    const _EmptyReplicaCard(
                      icon: Icons.group_off_outlined,
                      title: '暂无共享成员',
                      subtitle: '添加成员后可在这里查看共享联系人。',
                    )
                  else
                    AppCard(
                      padding: EdgeInsets.zero,
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
                            const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.primary,
                            ),
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
                          icon: Icons.route_outlined,
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
                                  leading: const Icon(Icons.history),
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

class QgjSoundEffectsPage extends StatefulWidget {
  const QgjSoundEffectsPage({super.key});

  @override
  State<QgjSoundEffectsPage> createState() => _QgjSoundEffectsPageState();
}

class _QgjSoundEffectsPageState extends State<QgjSoundEffectsPage> {
  String _selected = '官方默认';

  @override
  Widget build(BuildContext context) {
    const effects = ['官方默认', '活力提示', '轻提示', '静音方案'];
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: 'QGJ音效设置'),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const AppSectionLabel('音效包'),
                  const _ReplicaNotice(
                    icon: Icons.graphic_eq,
                    title: '音效方案',
                    subtitle: '可预览车辆提示音方案；写入车辆前请确认车辆支持该功能。',
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: RadioGroup<String>(
                      groupValue: _selected,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selected = value);
                        }
                      },
                      child: Column(
                        children: [
                          for (var i = 0; i < effects.length; i++) ...[
                            RadioListTile<String>(
                              title: Text(effects[i]),
                              subtitle: Text(
                                effects[i] == '官方默认'
                                    ? '保持当前车辆提示音'
                                    : '选择后用于当前页面预览',
                              ),
                              value: effects[i],
                            ),
                            if (i != effects.length - 1)
                              const Divider(
                                height: 1,
                                indent: 72,
                                color: AppColors.border,
                              ),
                          ],
                        ],
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
      leading: _CircleIcon(
        icon: record.type == '卡片'
            ? Icons.credit_card
            : record.type == '手表'
            ? Icons.watch_outlined
            : Icons.phone_android,
      ),
      title: Text(record.name),
      subtitle: Text('${record.type} · ${formatDateText(record.createdAt)}'),
      trailing: PopupMenuButton<String>(
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
      leading: const _CircleIcon(icon: Icons.person_outline),
      title: Text(member.name),
      subtitle: Text(
        member.phone.isEmpty
            ? '待邀请 · ${formatDateText(member.createdAt)}'
            : '${member.phone} · 待邀请',
      ),
      trailing: PopupMenuButton<String>(
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

  const _ReplicaNotice({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          _CircleIcon(icon: icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyLarge),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.smallText),
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

  const _EmptyReplicaCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Icon(icon, size: AppIconSizes.xl, color: AppColors.textTertiary),
          const SizedBox(height: 10),
          Text(title, style: AppTextStyles.itemTitle),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.smallText,
          ),
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

  const _CircleIcon({required this.icon, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: AppIconSizes.md),
    );
  }
}
