import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/official_vehicle.dart';
import '../models/vehicle_profile.dart';
import '../services/official_cloud_service.dart';
import '../services/sensitive_value_masker.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/vehicle_stage.dart';
import 'add_vehicle_page.dart';
import 'app_preferences_pages.dart';
import 'garage_page.dart';
import 'official_cloud_page.dart';
import 'vehicle_message_page.dart';

part 'profile_page_header.dart';
part 'profile_page_garage.dart';
part 'profile_page_function.dart';
part 'profile_page_settings.dart';

const _officialInk = Color(0xFF060606);
const _officialStrong = Color(0xFF1F1F1F);
const _officialMuted = Color(0xFF807E89);
const _officialLight = Color(0xFFACABB5);
const _mineCardRadius = 10.0;

/// Official-style "我的" page.

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  StreamSubscription<OfficialCloudState>? _cloudSub;
  StreamSubscription<List<VehicleProfile>>? _vehicleSub;
  late OfficialCloudState _cloudState;
  late List<VehicleProfile> _vehicles;

  @override
  void initState() {
    super.initState();
    _cloudState = officialCloudService.state;
    _vehicles = vehicleStore.vehicles;
    _cloudSub = officialCloudService.stateStream.listen((state) {
      if (mounted) setState(() => _cloudState = state);
    });
    _vehicleSub = vehicleStore.vehiclesStream.listen((vehicles) {
      if (mounted) setState(() => _vehicles = vehicles);
    });
  }

  @override
  void dispose() {
    _cloudSub?.cancel();
    _vehicleSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _cloudState.signedIn;
    final officialVehicle = _cloudState.selectedVehicle;
    final localVehicle = _defaultLocalVehicle();

    return Scaffold(
      backgroundColor: AppColors.officialPageBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppNav.contentBottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MineHeader(
                signedIn: signedIn,
                phone: signedIn ? _cloudState.phone : null,
                onProfileTap: () => _handleProfileTap(signedIn),
                onSettingsTap: () => AppSnack.info(context, '设置项在下方列表'),
                onMessageTap: () => _openMessages(context),
              ),
              const _SocialStats(),
              const SizedBox(height: 10),
              _ShortcutPair(onUnavailable: _showUnavailable),
              const SizedBox(height: 10),
              _GaragePanel(
                officialVehicle: officialVehicle,
                localVehicle: localVehicle,
                onGarageTap: () => _openGarage(context),
                onAddVehicle: () => _openAddVehicle(context),
              ),
              const SizedBox(height: 10),
              _FunctionCenter(onUnavailable: _showUnavailable),
              const SizedBox(height: 10),
              _MineActionTile(
                icon: Icons.query_stats_outlined,
                title: '骑行统计',
                minHeight: 88,
                onTap: () => _showUnavailable('骑行统计'),
              ),
              const SizedBox(height: 10),
              _MineActionTile(
                icon: Icons.watch_outlined,
                title: '扫码手表控车',
                minHeight: 70,
                trailingHelp: true,
                onTap: () => _showUnavailable('扫码手表控车'),
              ),
              const SizedBox(height: 10),
              _SettingsSection(onUnavailable: _showUnavailable),
              const SizedBox(height: 14),
              const _LogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  VehicleProfile? _defaultLocalVehicle() {
    final defaultId = vehicleStore.defaultVehicleId;
    if (defaultId != null) {
      for (final vehicle in _vehicles) {
        if (vehicle.id == defaultId) return vehicle;
      }
    }
    return vehicleStore.defaultVehicle ??
        (_vehicles.isEmpty ? null : _vehicles.first);
  }

  void _handleProfileTap(bool signedIn) {
    if (!signedIn) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const OfficialCloudPage()),
      );
      return;
    }
    AppSnack.featureUnavailable(context, '资料编辑');
  }

  void _openMessages(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const VehicleMessagePage()),
    );
  }

  void _openGarage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const GaragePage()),
    );
  }

  void _openAddVehicle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const AddVehiclePage()),
    );
  }

  void _showUnavailable(String label) {
    AppSnack.featureUnavailable(context, label);
  }
}
