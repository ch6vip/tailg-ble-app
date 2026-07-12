import 'package:flutter/material.dart';

import '../main.dart';
import '../models/official_vehicle.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import 'app_snack.dart';

Future<void> showVehicleSwitchSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _VehicleSwitchSheet(),
  );
}

class _VehicleSwitchSheet extends StatefulWidget {
  const _VehicleSwitchSheet();

  @override
  State<_VehicleSwitchSheet> createState() => _VehicleSwitchSheetState();
}

class _VehicleSwitchSheetState extends State<_VehicleSwitchSheet> {
  String? _selectingKey;

  @override
  Widget build(BuildContext context) {
    final state = officialCloudService.state;
    final vehicles = state.vehicles;
    final selectedKey = state.selectedVehicle?.key;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '切换车辆',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.55,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                return _VehicleTile(
                  vehicle: vehicle,
                  selected: vehicle.key == selectedKey,
                  selecting: vehicle.key == _selectingKey,
                  onTap: _selectingKey == null
                      ? () => _onSelect(vehicle)
                      : null,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _onSelect(OfficialVehicle vehicle) async {
    if (_selectingKey != null) return;
    setState(() => _selectingKey = vehicle.key);
    try {
      await officialCloudService.selectVehicle(vehicle);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _selectingKey = null);
      AppSnack.error(context, OfficialCloudRedactor.errorMessage(error));
    }
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.vehicle,
    required this.selected,
    required this.selecting,
    required this.onTap,
  });

  final OfficialVehicle vehicle;
  final bool selected;
  final bool selecting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: selected ? AppColors.primary.withValues(alpha: 0.06) : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(vehicle),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (selecting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (selected)
              const Icon(
                Icons.check_circle,
                size: 20,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }

  String _subtitle(OfficialVehicle v) {
    final parts = <String>[];
    if (v.online) {
      parts.add('在线');
    } else {
      parts.add('离线');
    }
    final battery = v.electricQuantity;
    if (battery != null && battery > 0) {
      parts.add('$battery%');
    }
    return parts.join(' · ');
  }
}
