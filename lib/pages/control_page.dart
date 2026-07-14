import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/command_types.dart';
import '../models/geo_coordinate.dart';
import '../models/official_vehicle.dart';
import '../models/vehicle_profile.dart';
import '../services/control_channel_resolver.dart';
import '../services/control_command_executor.dart';
import '../services/control_command_policy.dart';
import '../services/control_home_mode.dart';
import '../services/display_time_formatter.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../services/vehicle_location_resolver.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/cloud_vehicle_gate.dart';
import '../widgets/vehicle_stage.dart';
import '../widgets/vehicle_switch_sheet.dart';
import '../widgets/control_card.dart';
import 'add_vehicle_page.dart';
import 'battery_details_page.dart';
import 'control_page_hero.dart';
import 'location_page.dart';
import 'login_page.dart';
import 'official_cloud_page.dart';
import 'vehicle_message_page.dart';
import 'vehicle_settings_page.dart';

part 'control_page_service_cards.dart';
part 'control_page_service_card_widgets.dart';
part 'control_page_unbound_home.dart';
part 'control_page_home_overview.dart';

// P0-2: 改为运行时读取，让暗色模式生效。Sprint 3 Token 重建后改用 ThemeExtension。
Color _pageBg(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.of(context).pageBg
    : AppColors.officialPageBg;
const _kmPerPercent = 0.65;

// 控车确认超时与轮询间隔
const _controlConfirmTimeout = Duration(seconds: 8);
const _controlConfirmPollDelay = Duration(milliseconds: 800);
// Align with official DoubleClickUtils.isControlChangeCarFastDoubleClick (DIFF=1000):
// power / find / lock / seat share one debounce window.
const _controlCommandDebounce = Duration(milliseconds: 1000);
// Official often posts Lottie (event 112) then delays ~1s before mqttPublish.
// Cloud-only uses a shorter delay: feedback first, then HTTP.
const _controlCommandSendDelay = Duration(milliseconds: 500);
int? _normalizePercent(int? value) {
  if (value == null) return null;
  return value.clamp(0, 100);
}

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage>
    with AutomaticKeepAliveClientMixin, RouteAware {
  @override
  bool get wantKeepAlive => true;

  RouteObserver<ModalRoute<void>>? _routeObserver;
  bool _routeSubscribed = false;
  StreamSubscription<OfficialCloudState>? _cloudSub;
  StreamSubscription<List<VehicleProfile>>? _vehicleSub;
  bool _signedIn = false;
  bool _hasLocalVehicle = false;

  /// Pull-to-refresh: re-sync cloud vehicle data when signed in, otherwise just
  /// settle briefly so the indicator animation feels intentional.
  Future<void> _handleRefresh() async {
    if (officialCloudService.state.signedIn) {
      try {
        await officialCloudService.refreshVehicles(force: true);
      } catch (e) {
        logService.operation('首页下拉刷新失败', detail: '$e', level: LogLevel.warning);
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  void initState() {
    super.initState();
    _signedIn = officialCloudService.state.signedIn;
    _hasLocalVehicle =
        vehicleStore.vehicles.isNotEmpty || vehicleStore.defaultVehicle != null;
    _cloudSub = officialCloudService.stateStream.listen((state) {
      if (!mounted) return;
      final next = state.signedIn;
      if (next != _signedIn) setState(() => _signedIn = next);
    });
    _vehicleSub = vehicleStore.vehiclesStream.listen((vehicles) {
      if (!mounted) return;
      final next = vehicles.isNotEmpty || vehicleStore.defaultVehicle != null;
      if (next != _hasLocalVehicle) setState(() => _hasLocalVehicle = next);
    });
    _refreshOnVisible();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is! PageRoute) return;
    if (_routeSubscribed && identical(_routeObserver, appRouteObserver)) {
      return;
    }
    _routeObserver?.unsubscribe(this);
    _routeObserver = appRouteObserver;
    _routeObserver!.subscribe(this, route);
    _routeSubscribed = true;
  }

  @override
  void dispose() {
    final cloudSub = _cloudSub;
    if (cloudSub != null) unawaited(cloudSub.cancel());
    final vehicleSub = _vehicleSub;
    if (vehicleSub != null) unawaited(vehicleSub.cancel());
    _routeObserver?.unsubscribe(this);
    _routeObserver = null;
    _routeSubscribed = false;
    super.dispose();
  }

  @override
  void didPopNext() {
    // Returning from a pushed sub-page (battery / location / settings / …).
    _refreshOnVisible();
  }

  void _refreshOnVisible() {
    if (!officialCloudService.state.signedIn) return;
    unawaited(_refreshVehiclesSilently());
  }

  Future<void> _refreshVehiclesSilently() async {
    try {
      await officialCloudService.refreshVehicles(silent: true, force: true);
    } catch (e) {
      logService.operation(
        '控车页可见时官方车辆刷新失败',
        detail: e.toString(),
        level: LogLevel.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_signedIn && !_hasLocalVehicle) return const LoginPage();
    return Scaffold(
      backgroundColor: _pageBg(context),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppNav.contentBottomPadding),
          child: const _HomeBody(),
        ),
      ),
    );
  }
}

class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  StreamSubscription<List<VehicleProfile>>? _subVehicles;
  StreamSubscription<OfficialCloudState>? _subCloud;
  late final ValueNotifier<ControlHomeMode> _homeMode;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _homeMode = ValueNotifier<ControlHomeMode>(_computeHomeMode());
    _subVehicles = vehicleStore.vehiclesStream.listen((_) {
      if (_disposed) return;
      _updateDerived();
    });
    _subCloud = officialCloudService.stateStream.listen((_) {
      if (_disposed) return;
      _updateDerived();
    });
  }

  ControlHomeMode _computeHomeMode() {
    final hasLocalVehicle =
        vehicleStore.vehicles.isNotEmpty || vehicleStore.defaultVehicle != null;
    final cloudState = officialCloudService.state;
    final hasCloudVehicle = cloudState.selectedVehicle != null;
    return ControlHomeModeResolver.resolve(
      signedIn: cloudState.signedIn,
      hasLocalVehicle: hasLocalVehicle,
      hasCloudVehicle: hasCloudVehicle,
      cloudLoading: cloudState.loading,
    );
  }

  void _updateDerived() {
    final next = _computeHomeMode();
    if (_homeMode.value != next) _homeMode.value = next;
  }

  @override
  void dispose() {
    _disposed = true;
    final vehiclesSub = _subVehicles;
    if (vehiclesSub != null) unawaited(vehiclesSub.cancel());
    final cloudSub = _subCloud;
    if (cloudSub != null) unawaited(cloudSub.cancel());
    _subVehicles = null;
    _subCloud = null;
    _homeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ControlHomeMode>(
      valueListenable: _homeMode,
      builder: (context, mode, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: AppMotion.entranceCurve,
          switchOutCurve: AppMotion.exitCurve,
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: AppMotion.entranceCurve,
              reverseCurve: AppMotion.exitCurve,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.018),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
          child: switch (mode) {
            ControlHomeMode.bound => Column(
              key: const ValueKey('bound-home'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _HomeTopSection(),
                SizedBox(height: 14),
                _HomeQuickSection(),
                SizedBox(height: 20),
              ],
            ),
            ControlHomeMode.loading => const _ControlHomeLoading(
              key: ValueKey('control-home-loading'),
            ),
            ControlHomeMode.unbound => const _UnboundVehicleHome(
              key: ValueKey('unbound-home'),
            ),
            ControlHomeMode.needLogin => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

class _ControlHomeLoading extends StatelessWidget {
  const _ControlHomeLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.55,
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
