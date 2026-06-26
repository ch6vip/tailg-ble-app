import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart';
import '../models/vehicle_profile.dart';
import '../services/control_channel_resolver.dart';
import '../services/control_command_confirmation.dart';
import '../services/control_command_executor.dart';
import '../services/control_command_policy.dart';
import '../services/control_command_result.dart';
import '../services/log_service.dart';
import '../services/official_cloud_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../widgets/status_badge.dart';
import '../widgets/vehicle_stage.dart';
import '../widgets/control_card.dart';
import 'control_page_hero.dart';
import 'battery_details_page.dart';
import 'diagnostic_page.dart';
import 'garage_page.dart';
import 'location_page.dart';
import 'log_page.dart';
import 'official_cloud_page.dart';
import 'official_replica_pages.dart';
import 'ota_precheck_page.dart';
import 'vehicle_message_page.dart';
import 'vehicle_settings_page.dart';

part 'control_page_service_cards.dart';
part 'control_page_unbound_home.dart';
part 'control_page_home_overview.dart';
part 'control_page_vehicle_overview.dart';
part 'control_page_mode_widgets.dart';

const _pageBg = AppColors.pageBg;
const _kmPerPercent = 0.65;
const _phoneControlRadius = 16.0;
const _officialPressedBg = Color(0xFFE5E5E5);

// 控车确认超时与轮询间隔
const _controlConfirmTimeout = Duration(seconds: 8);
const _controlConfirmPollDelay = Duration(milliseconds: 800);
// M3: elevated card without border, soft dual-layer shadow
const _cardDecoration = BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
  boxShadow: AppShadows.elevation1,
);

int? _normalizePercent(int? value) {
  if (value == null) return null;
  return value.clamp(0, 100).toInt();
}

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
  Widget build(BuildContext context) {
    super.build(context);
    // 静态外壳只构建一次；仅随数据变化的内容下沉到 [_HomeBody]，
    // 避免每次连接态/车辆/云态事件都重建 Scaffold/RefreshIndicator/滚动容器。
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: const _HomeBody(),
          ),
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
  late final Stream<List<dynamic>> _combinedStream;
  StreamSubscription<dynamic>? _subConn;
  StreamSubscription<dynamic>? _subVehicles;
  StreamSubscription<dynamic>? _subCloud;
  StreamController<List<dynamic>>? _controller;

  @override
  void initState() {
    super.initState();
    _combinedStream = _createCombinedStream();
  }

  Stream<List<dynamic>> _createCombinedStream() {
    final controller = StreamController<List<dynamic>>.broadcast();
    var latestConn = connectionManager.state;
    var latestVehicles = vehicleStore.vehicles;
    var latestCloud = officialCloudService.state;

    void emit() {
      if (!controller.isClosed) {
        controller.add([latestConn, latestVehicles, latestCloud]);
      }
    }

    // Emit initial values
    scheduleMicrotask(emit);

    _subConn = connectionManager.stateStream.listen((s) {
      latestConn = s;
      emit();
    });
    _subVehicles = vehicleStore.vehiclesStream.listen((v) {
      latestVehicles = v;
      emit();
    });
    _subCloud = officialCloudService.stateStream.listen((c) {
      latestCloud = c;
      emit();
    });

    _controller = controller;
    controller.onCancel = _cancelSubscriptions;

    return controller.stream;
  }

  Future<void> _cancelSubscriptions() async {
    await _subConn?.cancel();
    await _subVehicles?.cancel();
    await _subCloud?.cancel();
    _subConn = null;
    _subVehicles = null;
    _subCloud = null;
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
      stream: _combinedStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final connState = snapshot.data![0] as ble.ConnectionState;
        final vehicles = snapshot.data![1] as List<VehicleProfile>;
        final cloudState = snapshot.data![2] as OfficialCloudState;
        final hasLocalVehicle =
            vehicles.isNotEmpty || vehicleStore.defaultVehicle != null;
        final hasCloudVehicle =
            cloudState.signedIn && cloudState.selectedVehicle != null;
        final hasTransientDevice =
            connectionManager.device != null ||
            connState != ble.ConnectionState.disconnected;
        final showUnboundHome =
            !hasLocalVehicle && !hasCloudVehicle && !hasTransientDevice;
        // If the BLE device was previously seen but vehicles aren't showing,
        // it's likely a connectivity issue rather than a genuine first-launch.
        final connectionLostHint =
            connectionManager.device != null &&
            !hasLocalVehicle &&
            !hasCloudVehicle;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
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
          child: showUnboundHome
              ? _UnboundVehicleHome(connectionLost: connectionLostHint)
              : Column(
                  key: const ValueKey('bound-home'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HomeTopSection(connState: connState),
                    const SizedBox(height: 14),
                    const _HomeQuickSection(),
                    const SizedBox(height: 14),
                    _RidingModeSelector(connState: connState),
                    const SizedBox(height: 20),
                  ],
                ),
        );
      },
    );
  }
}

// ── (old _ControlArea, _ControlAreaViewModel, _ControlAreaState removed —
//     control logic migrated into _HomeTopSection in control_page_home_overview.dart) ──
// ── (old _ControlArea, _ControlAreaViewModel, _ControlAreaState removed —
//     control logic migrated into _HomeTopSection in control_page_home_overview.dart) ──
