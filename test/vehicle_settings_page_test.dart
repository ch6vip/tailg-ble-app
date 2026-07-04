import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/vehicle_settings_page.dart';

import 'helpers/snack_finders.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';

void main() {
  testWidgets('switch setting rows expose labeled toggle semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      tester.view.physicalSize = const Size(430, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const TestApp(home: VehicleSettingsPage()));
      await tester.pump();

      const appRemoteLabel = 'APP遥控优先，官方入口已对齐，写入命令待确认，已关闭，命令待真机验证，暂不开放写入';
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

      expect(find.text('命令待真机验证，暂不开放写入'), findsOneWidget);
      expect(snackIcon(Icons.info_outline), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('riding mode options expose selected semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      tester.view.physicalSize = const Size(430, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
      tester.view.physicalSize = const Size(430, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const TestApp(home: VehicleSettingsPage()));
      await tester.pump();

      const pendingLabel = '自动下电，车辆静止后断电时间，命令待确认，待确认';
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

      expect(find.text('命令待真机验证，暂不开放写入'), findsOneWidget);
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
}
