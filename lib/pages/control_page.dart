import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../ble/connection_manager.dart' as ble;
import '../ble/constants.dart';
import '../models/geo_coordinate.dart';
import '../models/official_vehicle.dart';
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
import '../widgets/app_pressable.dart';
import '../widgets/app_snack.dart';
import '../widgets/vehicle_stage.dart';
import '../widgets/control_card.dart';
import 'add_vehicle_page.dart';
import 'battery_details_page.dart';
import 'control_page_hero.dart';
import 'garage_page.dart';
import 'location_page.dart';
import 'official_cloud_page.dart';
import 'official_replica_pages.dart';
import 'vehicle_message_page.dart';
import 'vehicle_settings_page.dart';

part 'control_page_service_cards.dart';
part 'control_page_unbound_home.dart';
part 'control_page_home_overview.dart';
part 'control_page_vehicle_overview.dart';
part 'control_page_mode_widgets.dart';

// P0-2: 改为运行时读取，让暗色模式生效。Sprint 3 Token 重建后改用 ThemeExtension。
Color _pageBg(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.of(context).pageBg
    : AppColors.officialPageBg;
const _kmPerPercent = 0.65;

// 控车确认超时与轮询间隔
const _controlConfirmTimeout = Duration(seconds: 8);
const _controlConfirmPollDelay = Duration(milliseconds: 800);
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
      backgroundColor: _pageBg(context),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
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
  // P0-4: 移除合并流，改用 ValueNotifier 驱动 showUnboundHome，
  // 三个子区域各自 StreamBuilder 精准订阅，避免整页重建。
  StreamSubscription<ble.ConnectionState>? _subConn;
  StreamSubscription<List<VehicleProfile>>? _subVehicles;
  StreamSubscription<OfficialCloudState>? _subCloud;
  late final ValueNotifier<bool> _showUnboundHome;
  late final ValueNotifier<bool> _connectionLostHint;
  bool _disposed = false; // P0-3: dispose 竞态保护

  @override
  void initState() {
    super.initState();
    _showUnboundHome = ValueNotifier<bool>(_computeShowUnboundHome());
    _connectionLostHint = ValueNotifier<bool>(_computeConnectionLostHint());
    _subConn = connectionManager.stateStream.listen((_) {
      if (_disposed) return;
      _updateDerived();
    });
    _subVehicles = vehicleStore.vehiclesStream.listen((_) {
      if (_disposed) return;
      _updateDerived();
    });
    _subCloud = officialCloudService.stateStream.listen((_) {
      if (_disposed) return;
      _updateDerived();
    });
  }

  bool _computeShowUnboundHome() {
    final hasLocalVehicle =
        vehicleStore.vehicles.isNotEmpty || vehicleStore.defaultVehicle != null;
    final cloudState = officialCloudService.state;
    final hasCloudVehicle =
        cloudState.signedIn && cloudState.selectedVehicle != null;
    final hasTransientDevice =
        connectionManager.device != null ||
        connectionManager.state != ble.ConnectionState.disconnected;
    return !hasLocalVehicle && !hasCloudVehicle && !hasTransientDevice;
  }

  bool _computeConnectionLostHint() {
    return connectionManager.device != null &&
        vehicleStore.vehicles.isEmpty &&
        !officialCloudService.state.signedIn;
  }

  void _updateDerived() {
    final nextShow = _computeShowUnboundHome();
    final nextLost = _computeConnectionLostHint();
    if (_showUnboundHome.value != nextShow) _showUnboundHome.value = nextShow;
    if (_connectionLostHint.value != nextLost) {
      _connectionLostHint.value = nextLost;
    }
  }

  @override
  void dispose() {
    // P0-3: 先置标志，再同步取消，防止回调向已关闭的流发射。
    _disposed = true;
    _subConn?.cancel();
    _subVehicles?.cancel();
    _subCloud?.cancel();
    _subConn = null;
    _subVehicles = null;
    _subCloud = null;
    _showUnboundHome.dispose();
    _connectionLostHint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _showUnboundHome,
      builder: (context, showUnboundHome, _) {
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
          child: showUnboundHome
              ? ValueListenableBuilder<bool>(
                  // P0-4: _UnboundVehicleHome 只依赖 connectionLostHint
                  valueListenable: _connectionLostHint,
                  builder: (context, lost, _) =>
                      _UnboundVehicleHome(connectionLost: lost),
                )
              : Column(
                  key: const ValueKey('bound-home'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // P0-4: _HomeTopSection 独立订阅 connState，
                    // vehicles/cloud 流变化时不重建
                    StreamBuilder<ble.ConnectionState>(
                      stream: connectionManager.stateStream,
                      initialData: connectionManager.state,
                      builder: (context, snap) =>
                          _HomeTopSection(connState: snap.data!),
                    ),
                    const SizedBox(height: 14),
                    const _HomeQuickSection(),
                    const SizedBox(height: 20),
                  ],
                ),
        );
      },
    );
  }
}
