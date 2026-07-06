import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart' as ble;
import 'package:tailg_ble_app/ble/constants.dart';
import 'package:tailg_ble_app/ble/qgj_protocol.dart';
import 'package:tailg_ble_app/pages/qgj_advanced_settings_page.dart';
import 'package:tailg_ble_app/pages/vehicle_settings_page.dart';
import 'package:tailg_ble_app/services/service_locator.dart';

import 'helpers/platform_mocks.dart';
import 'helpers/snack_finders.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

void main() {
  testWidgets('switch setting rows expose labeled toggle semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      setTestViewSize(tester, const Size(430, 2200));

      await tester.pumpWidget(const TestApp(home: VehicleSettingsPage()));
      await tester.pump();

      const appRemoteLabel = 'APP遥控优先，待车辆支持后开放，已关闭，该功能暂未开放';
      final appRemoteRow = find.bySemanticsLabel(appRemoteLabel);
      expect(appRemoteRow, findsOneWidget);
      expectMinTouchTargetHeight(tester, appRemoteRow);
      expect(
        tester.getSemantics(appRemoteRow),
        matchesSemantics(
          label: appRemoteLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(appRemoteLabel));
      await tester.pump();

      expect(find.text('该功能暂未开放'), findsOneWidget);
      expect(snackIcon(Icons.info_outline), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('riding mode options expose selected semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      setTestViewSize(tester, const Size(430, 2200));

      await tester.pumpWidget(const TestApp(home: VehicleSettingsPage()));
      await tester.pump();

      const rideSettingsLabel = '骑行设置，骑行模式和 ECU 功能入口';
      tester.semantics.tap(find.semantics.byLabel(rideSettingsLabel));
      await tester.pumpAndSettle();

      const standardModeLabel = '骑行模式：全速跑';
      final standardMode = find.bySemanticsLabel(standardModeLabel);
      expect(standardMode, findsOneWidget);
      expectMinTouchTargetHeight(tester, standardMode);
      expect(
        tester.getSemantics(standardMode),
        matchesSemantics(
          label: standardModeLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: false,
        ),
      );

      const ecoModeLabel = '骑行模式：超能跑';
      final ecoMode = find.bySemanticsLabel(ecoModeLabel);
      expect(ecoMode, findsOneWidget);
      expect(
        tester.getSemantics(ecoMode),
        matchesSemantics(
          label: ecoModeLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasSelectedState: true,
          isSelected: false,
          hasTapAction: false,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('disabled pending vehicle setting exposes semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      setTestViewSize(tester, const Size(430, 2200));

      await tester.pumpWidget(const TestApp(home: VehicleSettingsPage()));
      await tester.pump();

      const pendingLabel = '自动下电，车辆静止后断电时间，暂未开放，待确认';
      final pendingRow = find.bySemanticsLabel(pendingLabel);
      expect(pendingRow, findsOneWidget);
      expectMinTouchTargetHeight(tester, pendingRow);
      expect(
        tester.getSemantics(pendingRow),
        matchesSemantics(
          label: pendingLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(pendingLabel));
      await tester.pump();

      expect(find.text('该功能暂未开放'), findsOneWidget);
      expect(snackIcon(Icons.info_outline), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('navigation setting rows expose semantics and 44dp targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(const TestApp(home: VehicleSettingsPage()));
      await tester.pump();

      const soundLabel = '声音设置，车辆部分提示声音';
      final soundRow = find.bySemanticsLabel(soundLabel);
      expect(soundRow, findsOneWidget);
      expectMinTouchTargetHeight(tester, soundRow);
      expect(
        tester.getSemantics(soundRow),
        matchesSemantics(
          label: soundLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(soundLabel));
      await tester.pumpAndSettle();

      expect(find.text('声音开关'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('refresh applies sensitivity snapshot to row label', (
    tester,
  ) async {
    final fakeConnection = _ReadyQgjConnectionManager();
    final currentServices = AppServices.instance;
    AppServices.override(
      AppServices(
        connectionManager: fakeConnection,
        proximityService: currentServices.proximityService,
        autoConnectService: currentServices.autoConnectService,
        manualModeService: currentServices.manualModeService,
        locationService: currentServices.locationService,
        logService: currentServices.logService,
        vehicleStore: currentServices.vehicleStore,
        officialCloudService: currentServices.officialCloudService,
        appPreferencesService: currentServices.appPreferencesService,
        permissionService: currentServices.permissionService,
        homeTabIndex: ValueNotifier<int>(currentServices.homeTabIndex.value),
      ),
    );
    addTearDown(AppServices.reset);

    await tester.pumpWidget(const TestApp(home: VehicleSettingsPage()));
    await tester.pump();

    expect(find.bySemanticsLabel('震动灵敏度，中，车辆被触碰 报警音提示'), findsOneWidget);

    await tester.tap(find.byTooltip('刷新设置'));
    await tester.pumpAndSettle();

    expect(
      fakeConnection.requestedCommands,
      contains(QgjCommandIds.vibrateSensitivityGet),
    );
    expect(find.bySemanticsLabel('震动灵敏度，高，车辆被触碰 报警音提示'), findsOneWidget);
  });

  testWidgets('advanced settings report uses injected generated timestamp', (
    tester,
  ) async {
    final fakeConnection = _ReadyQgjConnectionManager();
    final currentServices = AppServices.instance;
    AppServices.override(
      AppServices(
        connectionManager: fakeConnection,
        proximityService: currentServices.proximityService,
        autoConnectService: currentServices.autoConnectService,
        manualModeService: currentServices.manualModeService,
        locationService: currentServices.locationService,
        logService: currentServices.logService,
        vehicleStore: currentServices.vehicleStore,
        officialCloudService: currentServices.officialCloudService,
        appPreferencesService: currentServices.appPreferencesService,
        permissionService: currentServices.permissionService,
        homeTabIndex: ValueNotifier<int>(currentServices.homeTabIndex.value),
      ),
    );
    addTearDown(AppServices.reset);
    mockClipboardWrites();
    addTearDown(clearPlatformChannelMock);

    await tester.pumpWidget(
      TestApp(
        home: QgjAdvancedSettingsPage(
          clock: () => DateTime(2026, 6, 10, 8, 45),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('刷新'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('复制结果'));
    await tester.pumpAndSettle();

    expect(
      fakeConnection.requestedCommands,
      contains(QgjCommandIds.autoLockTimeGet),
    );
    expect(clipboardWrites, hasLength(1));
    expect(
      clipboardWrites.single,
      contains('# QGJ Advanced Settings Read-only Result'),
    );
    expect(
      clipboardWrites.single,
      contains('Generated: 2026-06-10T08:45:00.000'),
    );
    expect(clipboardWrites.single, contains('Auto lock: 开启'));
    expect(clipboardWrites.single, contains('Auto lock raw seconds: 45'));
  });
}

class _ReadyQgjConnectionManager extends ble.ConnectionManager {
  final _stateController = StreamController<ble.ConnectionState>.broadcast();
  final List<int> requestedCommands = [];

  @override
  Stream<ble.ConnectionState> get stateStream => _stateController.stream;

  @override
  ble.ConnectionState get state => ble.ConnectionState.ready;

  @override
  ble.ProtocolType get protocol => ble.ProtocolType.qgj;

  @override
  ble.ProtocolType get lastKnownProtocol => ble.ProtocolType.qgj;

  @override
  RidingMode get ridingMode => RidingMode.standard;

  @override
  Future<QgjResponse?> sendQgjCommand(
    int cmdId, [
    List<int> payload = const [],
  ]) async {
    requestedCommands.add(cmdId);
    final responsePayload = switch (cmdId) {
      QgjCommandIds.lightSensorGet => [0x00],
      QgjCommandIds.soundAdjustGet => <int>[],
      QgjCommandIds.vibrateSensitivityGet => [0x55],
      QgjCommandIds.autoLockTimeGet => [0x00, 0x2D],
      QgjCommandIds.powerOnAutoLockTimeGet => [0x00, 0x3C],
      QgjCommandIds.proximityStatusGet => [0x01],
      QgjCommandIds.proximityDistanceGet => [0x02],
      QgjCommandIds.handlebarLockGet => [0x01],
      QgjCommandIds.postureDetectionGet => [0x00],
      QgjCommandIds.hidStatusGet => [QgjHidModes.openWithAutoLock],
      QgjCommandIds.safeLockGet => [0x01],
      QgjCommandIds.kickstandGet => [0x00],
      QgjCommandIds.seatSensorGet => [0x01],
      _ => null,
    };
    if (responsePayload == null) return null;
    return QgjResponse(
      cmdId: cmdId,
      payload: Uint8List.fromList(responsePayload),
      success: true,
    );
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
  }
}
