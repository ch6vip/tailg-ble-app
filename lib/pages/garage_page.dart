import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/vehicle_profile.dart';
import '../services/vehicle_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';

const _textPrimary = Color(0xFF1A1A2E);
const _textTertiary = Color(0xFF999999);

class GaragePage extends StatelessWidget {
  const GaragePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '我的车库',
              actions: [
                IconButton(
                  tooltip: '添加车辆',
                  onPressed: () => _openScan(context),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            Expanded(
              child: StreamBuilder<List<VehicleProfile>>(
                stream: VehicleStore().vehiclesStream,
                initialData: VehicleStore().vehicles,
                builder: (context, snapshot) {
                  final vehicles = snapshot.data ?? const <VehicleProfile>[];
                  if (vehicles.isEmpty) {
                    return _EmptyGarage(onScan: () => _openScan(context));
                  }
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      return _VehicleCard(
                        vehicle: vehicle,
                        isDefault:
                            vehicle.id == VehicleStore().defaultVehicleId ||
                            VehicleStore().defaultVehicle?.id == vehicle.id,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.electric_bike_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 14),
            const Text(
              '还没有绑定车辆',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '扫描附近蓝牙设备，连接成功后会自动加入车库。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textTertiary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.bluetooth_searching, size: 18),
              label: const Text('扫描绑定'),
            ),
          ],
        ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.electric_bike, color: AppColors.primary),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '默认',
                              style: TextStyle(fontSize: 11, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      vehicle.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textTertiary,
                        fontFamily: 'monospace',
                      ),
                    ),
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
          const SizedBox(height: 14),
          Row(
            children: [
              _InfoPill(icon: Icons.swap_horiz, label: vehicle.protocol.label),
              const SizedBox(width: 8),
              if (vehicle.protocol == VehicleProtocol.qgj ||
                  vehicle.hasQgjCredentials) ...[
                _InfoPill(
                  icon: Icons.key_outlined,
                  label: vehicle.hasQgjCredentials ? '自定义登录' : '默认登录',
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _InfoPill(
                  icon: Icons.schedule,
                  label: vehicle.lastConnectedAt == null
                      ? '未记录连接'
                      : '上次 ${_formatDate(vehicle.lastConnectedAt!)}',
                ),
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
              style: TextStyle(fontSize: 13, color: _textTertiary),
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

  String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.month}/${value.day} ${two(value.hour)}:${two(value.minute)}';
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

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _textTertiary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
