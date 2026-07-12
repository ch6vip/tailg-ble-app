import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/official_vehicle.dart';
import '../models/vehicle_profile.dart';
import '../services/app_navigation.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/status_badge.dart';
import '../widgets/vehicle_stage.dart';
import 'add_vehicle_page.dart';
import 'login_page.dart';
import 'official_cloud_page.dart';

/// Garage lists official cloud vehicles when signed in, and optional local
/// archives under a secondary section. Local-only rename/delete stay available
/// only on local cards.
class GaragePage extends StatefulWidget {
  final bool embedded;
  const GaragePage({super.key, this.embedded = false});

  @override
  State<GaragePage> createState() => _GaragePageState();
}

class _GaragePageState extends State<GaragePage> {
  StreamSubscription<OfficialCloudState>? _cloudSub;
  StreamSubscription<List<VehicleProfile>>? _vehicleSub;
  late OfficialCloudState _cloudState;
  late List<VehicleProfile> _localVehicles;
  var _syncing = false;

  @override
  void initState() {
    super.initState();
    _cloudState = officialCloudService.state;
    _localVehicles = vehicleStore.vehicles;
    _cloudSub = officialCloudService.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _cloudState = state);
    });
    _vehicleSub = vehicleStore.vehiclesStream.listen((vehicles) {
      if (!mounted) return;
      setState(() => _localVehicles = vehicles);
    });
  }

  @override
  void dispose() {
    final cloudSub = _cloudSub;
    if (cloudSub != null) unawaited(cloudSub.cancel());
    final vehicleSub = _vehicleSub;
    if (vehicleSub != null) unawaited(vehicleSub.cancel());
    super.dispose();
  }

  Future<void> _syncCloudVehicles() async {
    if (!_cloudState.signedIn || _syncing) return;
    setState(() => _syncing = true);
    try {
      await officialCloudService.refreshVehicles(force: true);
      if (!mounted) return;
      AppSnack.success(context, '车辆列表已同步');
    } catch (e) {
      if (!mounted) return;
      final message = OfficialCloudRedactor.errorMessage(e);
      AppSnack.error(context, message);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _openAddVehicle() {
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const AddVehiclePage()),
      ),
    );
  }

  void _openOfficialCloud() {
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const OfficialCloudPage()),
      ),
    );
  }

  void _openLogin() {
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      ),
    );
  }

  Future<void> _selectCloudVehicle(OfficialVehicle vehicle) async {
    HapticFeedback.selectionClick();
    await officialCloudService.selectVehicle(vehicle);
    if (!mounted) return;
    AppNavigation.returnToVehicleHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _cloudState.signedIn;
    final cloudVehicles = _cloudState.vehicles;
    final selectedKey = _cloudState.selectedVehicle?.key;
    final localVehicles = _localVehicles;
    final hasCloud = cloudVehicles.isNotEmpty;
    final hasLocal = localVehicles.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '我的车库',
              showBack: !widget.embedded,
              actions: [
                if (signedIn)
                  IconButton(
                    tooltip: '同步车辆',
                    onPressed: _syncing ? null : _syncCloudVehicles,
                    icon: _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, semanticLabel: '同步车辆'),
                  ),
                IconButton(
                  tooltip: '添加车辆',
                  onPressed: signedIn ? _openAddVehicle : _openLogin,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    semanticLabel: '添加车辆',
                  ),
                ),
              ],
            ),
            Expanded(
              child: !signedIn && !hasLocal
                  ? _UnsignedEmptyGarage(
                      onLogin: _openLogin,
                      onOfficialCloud: _openOfficialCloud,
                    )
                  : signedIn && !hasCloud && !hasLocal
                  ? _SignedEmptyGarage(
                      loading: _cloudState.loading || _syncing,
                      onSync: _syncCloudVehicles,
                      onAddVehicle: _openAddVehicle,
                      onOfficialCloud: _openOfficialCloud,
                    )
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        if (signedIn) ...[
                          if (hasCloud) ...[
                            const _SectionLabel('账号车辆'),
                            const SizedBox(height: 8),
                            for (final vehicle in cloudVehicles)
                              _CloudVehicleCard(
                                vehicle: vehicle,
                                isSelected: vehicle.key == selectedKey,
                                onSelect: () => _selectCloudVehicle(vehicle),
                              ),
                          ] else ...[
                            _SignedEmptyInline(
                              loading: _cloudState.loading || _syncing,
                              onSync: _syncCloudVehicles,
                              onAddVehicle: _openAddVehicle,
                              onOfficialCloud: _openOfficialCloud,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ] else ...[
                          _LoginPromptCard(
                            onLogin: _openLogin,
                            onOfficialCloud: _openOfficialCloud,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (hasLocal) ...[
                          if (signedIn || hasCloud) const SizedBox(height: 8),
                          const _SectionLabel('本地存档'),
                          const SizedBox(height: 8),
                          for (final vehicle in localVehicles)
                            _LocalVehicleCard(
                              vehicle: vehicle,
                              isDefault:
                                  vehicle.id == vehicleStore.defaultVehicleId ||
                                  vehicle.id == vehicleStore.defaultVehicle?.id,
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textTertiary,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _UnsignedEmptyGarage extends StatelessWidget {
  const _UnsignedEmptyGarage({
    required this.onLogin,
    required this.onOfficialCloud,
  });

  final VoidCallback onLogin;
  final VoidCallback onOfficialCloud;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppEmptyState(
              icon: Icons.electric_bike_outlined,
              title: '登录后查看账号车辆',
              subtitle: '登录官方账号后会同步已绑定车辆到车库。',
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login, size: AppIconSizes.md),
              label: const Text('登录账号'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onOfficialCloud,
              child: const Text('打开官方云账号页'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedEmptyGarage extends StatelessWidget {
  const _SignedEmptyGarage({
    required this.loading,
    required this.onSync,
    required this.onAddVehicle,
    required this.onOfficialCloud,
  });

  final bool loading;
  final VoidCallback onSync;
  final VoidCallback onAddVehicle;
  final VoidCallback onOfficialCloud;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppEmptyState(
              icon: Icons.garage_outlined,
              title: '账号下暂无车辆',
              subtitle: loading ? '正在同步账号车辆…' : '可同步账号车辆，或通过官方流程添加绑定。',
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: loading ? null : onSync,
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, size: AppIconSizes.md),
              label: Text(loading ? '同步中…' : '同步车辆'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onAddVehicle,
              icon: const Icon(Icons.add_circle_outline, size: AppIconSizes.md),
              label: const Text('添加车辆'),
            ),
            TextButton(
              onPressed: onOfficialCloud,
              child: const Text('打开官方云账号页'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedEmptyInline extends StatelessWidget {
  const _SignedEmptyInline({
    required this.loading,
    required this.onSync,
    required this.onAddVehicle,
    required this.onOfficialCloud,
  });

  final bool loading;
  final VoidCallback onSync;
  final VoidCallback onAddVehicle;
  final VoidCallback onOfficialCloud;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: AppShadows.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('账号下暂无车辆', style: AppTextStyles.subtitle),
          const SizedBox(height: 6),
          Text(
            loading ? '正在同步账号车辆…' : '同步账号车辆，或前往官方云查看绑定状态。',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: loading ? null : onSync,
                child: Text(loading ? '同步中…' : '同步'),
              ),
              OutlinedButton(onPressed: onAddVehicle, child: const Text('添加')),
              TextButton(onPressed: onOfficialCloud, child: const Text('官方云')),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoginPromptCard extends StatelessWidget {
  const _LoginPromptCard({
    required this.onLogin,
    required this.onOfficialCloud,
  });

  final VoidCallback onLogin;
  final VoidCallback onOfficialCloud;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: AppShadows.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('登录账号同步车辆', style: AppTextStyles.subtitle),
          const SizedBox(height: 6),
          const Text(
            '当前仅显示本地存档。登录后可查看账号下已绑定车辆。',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(onPressed: onLogin, child: const Text('登录账号')),
              const SizedBox(width: 8),
              TextButton(onPressed: onOfficialCloud, child: const Text('官方云')),
            ],
          ),
        ],
      ),
    );
  }
}

class _CloudVehicleCard extends StatelessWidget {
  const _CloudVehicleCard({
    required this.vehicle,
    required this.isSelected,
    required this.onSelect,
  });

  final OfficialVehicle vehicle;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final battery = vehicle.electricQuantity;
    final batteryFactor = battery == null
        ? 0.0
        : (battery.clamp(0, 100) / 100.0);
    return AppPressable(
      onTap: onSelect,
      haptic: false,
      semanticsLabel: '${vehicle.displayName}${isSelected ? '，当前选中' : '，点击选择'}',
      semanticsButton: true,
      semanticsEnabled: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: AppShadows.elevation1,
          border: isSelected
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.55),
                  width: 1.5,
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: Container(
                width: 100,
                height: 70,
                color: AppColors.pageBgTop,
                child: CustomPaint(
                  painter: VehicleStagePainter(
                    batteryLevel: batteryFactor > 0 ? batteryFactor : 0.7,
                  ),
                  size: const Size(100, 70),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          vehicle.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.subtitle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: const Text(
                            '使用中',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Container(
                      height: 4,
                      width: 120,
                      color: AppColors.surfaceContainerHigh,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: batteryFactor > 0 ? batteryFactor : 0.72,
                        child: Container(color: AppColors.energyGreen),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      StatusBadge(
                        type: vehicle.online
                            ? StatusBadgeType.online
                            : StatusBadgeType.offline,
                        compact: true,
                      ),
                      const Spacer(),
                      _MiniActionButton(
                        icon: Icons.location_on_outlined,
                        label: '定位',
                        onTap: () {
                          final nav = Navigator.of(
                            context,
                            rootNavigator: true,
                          );
                          nav.popUntil((route) => route.isFirst);
                          homeTabIndex.value = 0;
                        },
                      ),
                      const SizedBox(width: 12),
                      _MiniActionButton(
                        icon: Icons.sensors_rounded,
                        label: '控车',
                        onTap: onSelect,
                      ),
                    ],
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

class _LocalVehicleCard extends StatefulWidget {
  final VehicleProfile vehicle;
  final bool isDefault;
  const _LocalVehicleCard({required this.vehicle, required this.isDefault});

  @override
  State<_LocalVehicleCard> createState() => _LocalVehicleCardState();
}

class _LocalVehicleCardState extends State<_LocalVehicleCard> {
  VehicleProfile get vehicle => widget.vehicle;
  bool get isDefault => widget.isDefault;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: AppShadows.elevation1,
        border: isDefault
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.55),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: Container(
                  width: 100,
                  height: 70,
                  color: AppColors.pageBgTop,
                  child: CustomPaint(
                    painter: VehicleStagePainter(batteryLevel: 0.7),
                    size: const Size(100, 70),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            vehicle.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.subtitle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            child: const Text(
                              '默认',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                        height: 4,
                        width: 120,
                        color: AppColors.surfaceContainerHigh,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.72,
                          child: Container(color: AppColors.energyGreen),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const StatusBadge(
                          type: StatusBadgeType.connected,
                          compact: true,
                        ),
                        const Spacer(),
                        _MiniActionButton(
                          icon: Icons.location_on_outlined,
                          label: '定位',
                          onTap: () => homeTabIndex.value = 0,
                        ),
                        const SizedBox(width: 12),
                        _MiniActionButton(
                          icon: Icons.sensors_rounded,
                          label: '控车',
                          onTap: () => homeTabIndex.value = 1,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '车辆操作',
                onSelected: (value) => _handleAction(context, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'rename', child: Text('编辑名称')),
                  if (!isDefault)
                    const PopupMenuItem(value: 'default', child: Text('设为默认')),
                  const PopupMenuItem(value: 'delete', child: Text('删除车辆')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String value) async {
    if (value == 'rename') {
      if (!mounted) return;
      await _showRenameDialog(context);
    } else if (value == 'default') {
      await vehicleStore.setDefault(vehicle.id);
    } else if (value == 'delete') {
      if (!mounted) return;
      await _confirmDelete(context);
    }
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final controller = TextEditingController(text: vehicle.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑车辆名称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(hintText: '输入车辆名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return;
    if (name != null) await vehicleStore.rename(vehicle.id, name);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除车辆'),
        content: Text('确定删除 ${vehicle.displayName}？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await vehicleStore.remove(vehicle.id);
    }
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return AppPressable(
      onTap: onTap,
      enabled: enabled,
      haptic: false,
      semanticsLabel: label,
      semanticsButton: true,
      semanticsEnabled: enabled,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AppTouchTargets.min,
          minHeight: AppTouchTargets.min,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.primary),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
