import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/app_navigation.dart';
import '../models/official_vehicle.dart';
import '../models/vehicle_profile.dart';
import '../services/official_cloud_service.dart';
import '../services/log_service.dart';
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

  @override
  void initState() {
    super.initState();
    _cloudState = officialCloudService.state;
    _cloudSub = officialCloudService.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _cloudState = state);
      _runBackgroundTask(
        messageReadStore.syncFromCloudMessages(
          vehicleMessages: state.vehicleMessages,
          systemMessages: state.systemMessages,
        ),
        failureMessage: '消息角标同步失败',
      );
      if (!state.signedIn) {
        messageReadStore.setUnreadCount(0);
      }
    });
    // Rebuild when local vehicles change so default-vehicle dependent UI updates.
    _vehicleSub = vehicleStore.vehiclesStream.listen((_) {
      if (mounted) setState(() {});
    });
    _runBackgroundTask(_bootstrapMessageBadge(), failureMessage: '消息角标初始化失败');
  }

  Future<void> _bootstrapMessageBadge() async {
    await messageReadStore.ensureLoaded();
    if (!_cloudState.signedIn) {
      messageReadStore.setUnreadCount(0);
      return;
    }
    // Sync badge from any already-cached messages first so the UI does not
    // wait on network. Then refresh in the background.
    await messageReadStore.syncFromCloudMessages(
      vehicleMessages: officialCloudService.state.vehicleMessages,
      systemMessages: officialCloudService.state.systemMessages,
    );
    await _refreshMessageBadgeSilently();
  }

  void _runBackgroundTask(
    Future<void> future, {
    required String failureMessage,
  }) {
    unawaited(
      future.catchError((Object error) {
        logService.operation(
          failureMessage,
          detail: OfficialCloudRedactor.errorMessage(error),
          level: LogLevel.warning,
        );
      }),
    );
  }

  Future<void> _refreshMessageBadgeSilently() async {
    if (!officialCloudService.state.signedIn) return;
    try {
      await officialCloudService.refreshMessages(silent: true);
    } on Exception {
      // Badge refresh is best-effort; cached messages suffice.
    }
    if (!mounted || !officialCloudService.state.signedIn) return;
    await messageReadStore.syncFromCloudMessages(
      vehicleMessages: officialCloudService.state.vehicleMessages,
      systemMessages: officialCloudService.state.systemMessages,
    );
  }

  @override
  void dispose() {
    final cloudSub = _cloudSub;
    if (cloudSub != null) unawaited(cloudSub.cancel());
    final vehicleSub = _vehicleSub;
    if (vehicleSub != null) unawaited(vehicleSub.cancel());
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
              ValueListenableBuilder<int>(
                valueListenable: messageReadStore.unreadCount,
                builder: (context, unread, _) {
                  return _MineHeader(
                    signedIn: signedIn,
                    phone: signedIn ? _cloudState.phone : null,
                    hasUnreadMessages: signedIn && unread > 0,
                    onProfileTap: () => _handleProfileTap(signedIn),
                    onSettingsTap: () => AppSnack.info(context, '设置项在下方列表'),
                    onMessageTap: () => _openMessages(context),
                  );
                },
              ),
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

  VehicleProfile? _defaultLocalVehicle() => vehicleStore.defaultVehicle;

  void _handleProfileTap(bool signedIn) {
    if (!signedIn) {
      unawaited(
        Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const OfficialCloudPage()),
        ),
      );
      return;
    }
    AppSnack.featureUnavailable(context, '资料编辑');
  }

  void _openMessages(BuildContext context) {
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const VehicleMessagePage()),
      ),
    );
  }

  void _openGarage(BuildContext context) {
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const GaragePage()),
      ),
    );
  }

  void _openAddVehicle(BuildContext context) {
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const AddVehiclePage()),
      ),
    );
  }

  void _showUnavailable(String label) {
    AppSnack.featureUnavailable(context, label);
  }
}
