import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/vehicle_profile.dart';
import '../services/vehicle_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/status_badge.dart';
import '../widgets/vehicle_stage.dart';

class GaragePage extends StatelessWidget {
  /// When hosted as a bottom-nav tab there is no route to pop back to, so the
  /// header back button is hidden. Pushed instances keep the default back arrow.
  final bool embedded;

  const GaragePage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final store = VehicleStore();
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '我的车库',
              showBack: !embedded,
              actions: [
                IconButton(
                  tooltip: '添加车辆',
                  onPressed: () => _openScan(context),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    semanticLabel: '添加车辆',
                  ),
                ),
              ],
            ),
            Expanded(
              child: StreamBuilder<List<VehicleProfile>>(
                stream: store.vehiclesStream,
                initialData: store.vehicles,
                builder: (context, snapshot) {
                  final vehicles = snapshot.data ?? const <VehicleProfile>[];
                  if (vehicles.isEmpty) {
                    return _EmptyGarage(onScan: () => _openScan(context));
                  }
                  final defaultVehicleId =
                      store.defaultVehicleId ?? store.defaultVehicle?.id;
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      return RepaintBoundary(
                        child: _VehicleCard(
                          vehicle: vehicle,
                          isDefault: vehicle.id == defaultVehicleId,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openScan(BuildContext context) {
    openScanTab(context);
  }
}

class _EmptyGarage extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyGarage({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppEmptyState(
            icon: Icons.electric_bike_outlined,
            title: '还没有绑定车辆',
            subtitle: '扫描附近蓝牙设备，连接成功后会自动加入车库。',
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 0),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(
              Icons.bluetooth_searching,
              size: AppIconSizes.md,
              semanticLabel: '扫描蓝牙',
            ),
            label: const Text('扫描绑定'),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final VehicleProfile vehicle;
  final bool isDefault;
  const _VehicleCard({required this.vehicle, required this.isDefault});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.elevation1,
        // v8: the current (default) vehicle gets a teal outline so it reads as
        // the active card at a glance.
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
          // v8: vehicle illustration + title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle mini SVG
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                            style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('默认', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // v8: SOC bar
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
                    // v8: status badge + action buttons
                    Row(children: [
                      const StatusBadge(type: StatusBadgeType.ble, compact: true),
                      const Spacer(),
                      _MiniActionButton(
                        icon: Icons.location_on_outlined,
                        label: '定位',
                        onTap: () {
                          homeTabIndex.value = 1;
                        },
                      ),
                      const SizedBox(width: 12),
                      _MiniActionButton(
                        icon: Icons.sensors_rounded,
                        label: '控车',
                        onTap: () {
                          homeTabIndex.value = 0;
                        },
                      ),
                    ]),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '车辆操作',
                onSelected: (value) => _handleAction(context, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'rename', child: Text('编辑名称')),
                  const PopupMenuItem(
                    value: 'qgj_credentials',
                    child: Text('QGJ登录参数'),
                  ),
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
      await _showRenameDialog(context);
    } else if (value == 'qgj_credentials') {
      await _showQgjCredentialsDialog(context);
    } else if (value == 'default') {
      await VehicleStore().setDefault(vehicle.id);
      proximityService.setTargetDevice(vehicle.id);
      applyVehicleBleCredentials(VehicleStore().defaultVehicle);
    } else if (value == 'delete') {
      await _confirmDelete(context);
    }
  }

  Future<void> _showQgjCredentialsDialog(BuildContext context) async {
    final passwordController = TextEditingController(
      text: vehicle.qgjLoginPassword?.toString() ?? '',
    );
    final userIdController = TextEditingController(
      text: vehicle.qgjUserId?.toString() ?? '',
    );

    final result = await showDialog<_QgjCredentialEdit>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QGJ登录参数'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '官方 ECU 登录使用车辆密码和账号 UID。留空则使用默认 0。',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '车辆密码',
                hintText: '默认 0',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: userIdController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '用户 UID',
                hintText: '默认 0',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const _QgjCredentialEdit.clear()),
            child: const Text('清空'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final password = _parseUint32(passwordController.text);
              final userId = _parseUint32(userIdController.text);
              if (password == null &&
                  passwordController.text.trim().isNotEmpty) {
                return;
              }
              if (userId == null && userIdController.text.trim().isNotEmpty) {
                return;
              }
              Navigator.pop(
                context,
                _QgjCredentialEdit(password: password, userId: userId),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    userIdController.dispose();
    if (result == null) return;

    await VehicleStore().updateQgjCredentials(
      id: vehicle.id,
      password: result.password,
      userId: result.userId,
      clear: result.clear,
    );
    if (VehicleStore().defaultVehicle?.id == vehicle.id) {
      applyVehicleBleCredentials(VehicleStore().defaultVehicle);
    }
  }

  int? _parseUint32(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0 || parsed > 0xFFFFFFFF) return null;
    return parsed;
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
    if (name != null) {
      await VehicleStore().rename(vehicle.id, name);
    }
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
    if (confirmed == true) {
      await VehicleStore().remove(vehicle.id);
      final defaultVehicle = VehicleStore().defaultVehicle;
      if (defaultVehicle != null) {
        proximityService.setTargetDevice(defaultVehicle.id);
        applyVehicleBleCredentials(defaultVehicle);
      }
    }
  }
}

class _QgjCredentialEdit {
  final int? password;
  final int? userId;
  final bool clear;

  const _QgjCredentialEdit({this.password, this.userId}) : clear = false;
  const _QgjCredentialEdit.clear()
    : password = null,
      userId = null,
      clear = true;
}

/// v8 mini action button for garage cards: locate / control.
class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
      ]),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}
