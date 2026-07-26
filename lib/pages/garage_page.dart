import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/official_vehicle.dart';
import '../models/vehicle_profile.dart';
import '../services/app_navigation.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/lucide_icon.dart';
import '../widgets/vehicle_stage.dart';
import 'add_vehicle_page.dart';
import 'login_page.dart';

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

  void _openLogin() {
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      ),
    );
  }

  Future<void> _selectCloudVehicle(OfficialVehicle vehicle) async {
    unawaited(HapticFeedback.selectionClick());
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
      backgroundColor: CyberHomeColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _GarageHeader(
              showBack: !widget.embedded,
              showSync: signedIn,
              syncing: _syncing,
              onSync: _syncCloudVehicles,
              onAdd: signedIn ? _openAddVehicle : _openLogin,
            ),
            Expanded(
              child: !signedIn && !hasLocal
                  ? _UnsignedEmptyGarage(onLogin: _openLogin)
                  : signedIn && !hasCloud && !hasLocal
                  ? _SignedEmptyGarage(
                      loading: _cloudState.loading || _syncing,
                      onSync: _syncCloudVehicles,
                      onAddVehicle: _openAddVehicle,
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
                            ),
                            const SizedBox(height: 16),
                          ],
                        ] else ...[
                          _LoginPromptCard(onLogin: _openLogin),
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

class _GarageHeader extends StatelessWidget {
  const _GarageHeader({
    required this.showBack,
    required this.showSync,
    required this.syncing,
    required this.onSync,
    required this.onAdd,
  });

  final bool showBack;
  final bool showSync;
  final bool syncing;
  final VoidCallback onSync;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    Widget action({
      required Key key,
      required String label,
      required Widget icon,
      required VoidCallback? onTap,
    }) {
      return Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: AppPressable(
          key: key,
          onTap: onTap,
          enabled: onTap != null,
          semanticsLabel: label,
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
            child: icon,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(showBack ? 12 : 20, 10, 20, 8),
      child: Row(
        children: [
          if (showBack) ...[
            action(
              key: const ValueKey('garage-back'),
              label: '返回',
              onTap: () => Navigator.of(context).pop(),
              icon: const LucideIcon(
                Lucide.arrowLeft,
                size: 20,
                color: CyberHomeColors.inkSecondary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Text(
              '我的车库',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: CyberHomeColors.ink,
              ),
            ),
          ),
          if (showSync) ...[
            action(
              key: const ValueKey('garage-sync'),
              label: '同步车辆',
              onTap: syncing ? null : onSync,
              icon: syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CyberHomeColors.primary,
                      ),
                    )
                  : const LucideIcon(
                      Lucide.refresh,
                      size: 20,
                      color: CyberHomeColors.primary,
                    ),
            ),
            const SizedBox(width: 8),
          ],
          action(
            key: const ValueKey('garage-add'),
            label: '添加车辆',
            onTap: onAdd,
            icon: const LucideIcon(
              Lucide.plusCircle,
              size: 20,
              color: CyberHomeColors.primary,
            ),
          ),
        ],
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
        color: CyberHomeColors.inkMuted,
      ),
    );
  }
}

const _garageCardDecoration = BoxDecoration(
  color: CyberHomeColors.card,
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.tile)),
  border: Border.fromBorderSide(BorderSide(color: CyberHomeColors.line)),
);

const _garageTitleStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: CyberHomeColors.ink,
);

const _garageBodyStyle = TextStyle(
  fontSize: 13,
  height: 1.45,
  color: CyberHomeColors.inkMuted,
);

const _garageMenuTextStyle = TextStyle(color: CyberHomeColors.ink);

final _garageFilledButtonStyle = FilledButton.styleFrom(
  minimumSize: const Size(120, 48),
  backgroundColor: CyberHomeColors.primary,
  foregroundColor: CyberHomeColors.white,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.tile),
  ),
);

final _garageOutlinedButtonStyle = OutlinedButton.styleFrom(
  minimumSize: const Size(120, 48),
  foregroundColor: CyberHomeColors.primary,
  side: const BorderSide(color: CyberHomeColors.lineStrong),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.tile),
  ),
);

class _GarageEmptyVisual extends StatelessWidget {
  const _GarageEmptyVisual({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: CyberHomeColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: LucideIcon(
            icon,
            size: AppIconSizes.lg,
            color: CyberHomeColors.primary,
          ),
        ),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: _garageTitleStyle),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center, style: _garageBodyStyle),
      ],
    );
  }
}

class _GarageStatus extends StatelessWidget {
  const _GarageStatus({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? CyberHomeColors.success : CyberHomeColors.inkFaint;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _UnsignedEmptyGarage extends StatelessWidget {
  const _UnsignedEmptyGarage({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GarageEmptyVisual(
              icon: Lucide.vehicle,
              title: '登录后查看账号车辆',
              subtitle: '登录官方账号后会同步已绑定车辆到车库。',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: _garageFilledButtonStyle,
              onPressed: onLogin,
              icon: const LucideIcon(Lucide.login, size: AppIconSizes.md),
              label: const Text('登录账号'),
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
  });

  final bool loading;
  final VoidCallback onSync;
  final VoidCallback onAddVehicle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GarageEmptyVisual(
              icon: Lucide.garage,
              title: '账号下暂无车辆',
              subtitle: loading ? '正在同步账号车辆…' : '可同步账号车辆，或通过官方流程添加绑定。',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: _garageFilledButtonStyle,
              onPressed: loading ? null : onSync,
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const LucideIcon(Lucide.refresh, size: AppIconSizes.md),
              label: Text(loading ? '同步中…' : '同步车辆'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: _garageOutlinedButtonStyle,
              onPressed: onAddVehicle,
              icon: const LucideIcon(Lucide.plusCircle, size: AppIconSizes.md),
              label: const Text('添加车辆'),
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
  });

  final bool loading;
  final VoidCallback onSync;
  final VoidCallback onAddVehicle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _garageCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('账号下暂无车辆', style: _garageTitleStyle),
          const SizedBox(height: 6),
          Text(
            loading ? '正在同步账号车辆…' : '同步账号车辆，或前往添加车辆完成绑定。',
            style: _garageBodyStyle,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                style: _garageFilledButtonStyle,
                onPressed: loading ? null : onSync,
                child: Text(loading ? '同步中…' : '同步'),
              ),
              OutlinedButton(
                style: _garageOutlinedButtonStyle,
                onPressed: onAddVehicle,
                child: const Text('添加'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoginPromptCard extends StatelessWidget {
  const _LoginPromptCard({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _garageCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('登录账号同步车辆', style: _garageTitleStyle),
          const SizedBox(height: 6),
          const Text('当前仅显示本地存档。登录后可查看账号下已绑定车辆。', style: _garageBodyStyle),
          const SizedBox(height: 12),
          FilledButton(
            style: _garageFilledButtonStyle,
            onPressed: onLogin,
            child: const Text('登录账号'),
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
        decoration: _garageCardDecoration.copyWith(
          border: isSelected
              ? Border.all(color: CyberHomeColors.primary, width: 1.5)
              : const Border.fromBorderSide(
                  BorderSide(color: CyberHomeColors.line),
                ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              child: Container(
                width: 100,
                height: 70,
                color: CyberHomeColors.control,
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: CyberHomeColors.ink,
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
                            color: CyberHomeColors.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: const Text(
                            '使用中',
                            style: TextStyle(
                              fontSize: 11,
                              color: CyberHomeColors.primary,
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
                      color: CyberHomeColors.controlStrong,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: batteryFactor > 0 ? batteryFactor : 0.72,
                        child: Container(color: CyberHomeColors.success),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _GarageStatus(
                        label: vehicle.online ? '在线' : '离线',
                        active: vehicle.online,
                      ),
                      const Spacer(),
                      _MiniActionButton(
                        icon: Lucide.mapPin,
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
                        icon: Lucide.sensors,
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
      decoration: _garageCardDecoration.copyWith(
        border: isDefault
            ? Border.all(color: CyberHomeColors.primary, width: 1.5)
            : const Border.fromBorderSide(
                BorderSide(color: CyberHomeColors.line),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.tile),
                child: Container(
                  width: 100,
                  height: 70,
                  color: CyberHomeColors.control,
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
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: CyberHomeColors.ink,
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
                              color: CyberHomeColors.primarySoft,
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                            child: const Text(
                              '默认',
                              style: TextStyle(
                                fontSize: 11,
                                color: CyberHomeColors.primary,
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
                        color: CyberHomeColors.controlStrong,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.72,
                          child: Container(color: CyberHomeColors.success),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const _GarageStatus(label: '本地', active: true),
                        const Spacer(),
                        _MiniActionButton(
                          icon: Lucide.mapPin,
                          label: '定位',
                          onTap: () => homeTabIndex.value = 0,
                        ),
                        const SizedBox(width: 12),
                        _MiniActionButton(
                          icon: Lucide.sensors,
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
                color: CyberHomeColors.card,
                icon: const LucideIcon(
                  Lucide.more,
                  color: CyberHomeColors.inkMuted,
                ),
                onSelected: (value) => _handleAction(context, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('编辑名称', style: _garageMenuTextStyle),
                  ),
                  if (!isDefault)
                    const PopupMenuItem(
                      value: 'default',
                      child: Text('设为默认', style: _garageMenuTextStyle),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('删除车辆', style: _garageMenuTextStyle),
                  ),
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
        backgroundColor: CyberHomeColors.card,
        surfaceTintColor: CyberHomeColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
        ),
        title: const Text(
          '编辑车辆名称',
          style: TextStyle(
            color: CyberHomeColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          style: const TextStyle(color: CyberHomeColors.ink),
          decoration: InputDecoration(
            hintText: '输入车辆名称',
            hintStyle: const TextStyle(color: CyberHomeColors.inkFaint),
            filled: true,
            fillColor: CyberHomeColors.cardMuted,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.tile),
              borderSide: const BorderSide(color: CyberHomeColors.lineStrong),
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: CyberHomeColors.inkMuted,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: CyberHomeColors.primary,
              foregroundColor: CyberHomeColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
            ),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (!mounted) return;
    if (name != null) await vehicleStore.rename(vehicle.id, name);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberHomeColors.card,
        surfaceTintColor: CyberHomeColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
        ),
        title: const Text(
          '删除车辆',
          style: TextStyle(
            color: CyberHomeColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '确定删除 ${vehicle.displayName}？',
          style: const TextStyle(color: CyberHomeColors.inkMuted),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: CyberHomeColors.inkMuted,
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: CyberHomeColors.danger,
              foregroundColor: CyberHomeColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
            ),
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
              LucideIcon(icon, size: 15, color: CyberHomeColors.primary),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CyberHomeColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
