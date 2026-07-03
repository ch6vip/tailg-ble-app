import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/snack_finders.dart';
import 'helpers/test_app.dart';

void main() {
  Future<void> pumpBoundHome(
    WidgetTester tester, {
    Size? size,
    String name = '测试车辆',
  }) async {
    SharedPreferences.setMockInitialValues({});
    app.proximityService.resetForTest();
    app.manualModeService.resetForTest();
    VehicleStore().resetForTest();
    await VehicleStore().init();
    await VehicleStore().upsert(
      id: 'AA:BB:CC:DD:EE:FF',
      name: name,
      protocol: VehicleProtocol.auto,
      makeDefault: true,
    );

    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    await tester.pumpWidget(const TestApp(home: ControlPage()));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('bound control home builds without throwing', (tester) async {
    await pumpBoundHome(tester);

    expect(tester.takeException(), isNull);
    // Official replica: lower area follows fragment_control.xml entries.
    expect(find.text('车辆定位'), findsOneWidget);
    expect(find.text('历史轨迹'), findsOneWidget);
    expect(find.text('功能设置'), findsOneWidget);
    expect(find.text('NFC钥匙'), findsOneWidget);
  });

  testWidgets('bound control home stays stable on a narrow surface', (
    tester,
  ) async {
    await pumpBoundHome(
      tester,
      size: const Size(320, 2600),
      name: '这是一辆名称特别长的测试车辆用于验证首页不会溢出',
    );

    expect(tester.takeException(), isNull);
    expect(find.text('车辆定位'), findsOneWidget);
    expect(find.bySemanticsLabel('可添加GPS'), findsOneWidget);
  });

  testWidgets('super dashboard placeholder shows info snack', (tester) async {
    await pumpBoundHome(tester, size: const Size(430, 2200));

    await tester.tap(find.text('超级仪表'));
    await tester.pump();

    expect(find.text('超级仪表功能开发中'), findsOneWidget);
    expect(snackIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('proximity control toggles ProximityService, not manual mode', (
    tester,
  ) async {
    await pumpBoundHome(tester, size: const Size(430, 2200));

    expect(app.proximityService.enabled, isFalse);
    expect(app.manualModeService.enabled, isFalse);

    final enabledEvent = app.proximityService.enabledStream.firstWhere(
      (value) => value,
    );

    await tester.tap(find.text('感应解锁'));
    await tester.pump();
    await enabledEvent;
    await tester.pump();

    expect(app.proximityService.enabled, isTrue);
    expect(app.manualModeService.enabled, isFalse);
  });

  testWidgets('official manual mode control keeps a 44dp touch target', (
    tester,
  ) async {
    await pumpBoundHome(tester, size: const Size(430, 2200));

    final manualModePill = find.byTooltip('开启手动模式：禁用感应解锁/自动连接');
    expect(manualModePill, findsOneWidget);
    expect(tester.getSize(manualModePill).height, greaterThanOrEqualTo(44));
    expect(
      find.descendant(of: manualModePill, matching: find.byType(AppPressable)),
      findsOneWidget,
    );

    final enabledEvent = app.manualModeService.enabledStream.firstWhere(
      (value) => value,
    );

    await tester.tap(manualModePill);
    await tester.pump();
    await enabledEvent;
    await tester.pump();

    expect(app.manualModeService.enabled, isTrue);
  });

  testWidgets('manual mode toggle exposes semantics action', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpBoundHome(tester, size: const Size(430, 2200));

      final manualModeToggle = find.bySemanticsLabel('手动模式');
      expect(manualModeToggle, findsOneWidget);
      expect(
        tester.getSemantics(manualModeToggle),
        matchesSemantics(
          label: '手动模式',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasToggledState: true,
          isToggled: false,
        ),
      );

      final enabledEvent = app.manualModeService.enabledStream.firstWhere(
        (value) => value,
      );

      tester.semantics.tap(find.semantics.byLabel('手动模式'));
      await tester.pump();
      await enabledEvent;
      await tester.pump();

      expect(app.manualModeService.enabled, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('official settings entries use AppPressable feedback', (
    tester,
  ) async {
    await pumpBoundHome(tester, size: const Size(430, 2200));

    for (final label in ['车辆设置', '电子围栏', '分享用车']) {
      final option = find.ancestor(
        of: find.text(label),
        matching: find.byType(AppPressable),
      );
      expect(option, findsOneWidget);
      expect(tester.getSize(option).height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('official lower entries expose semantics actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpBoundHome(tester, size: const Size(430, 2200));

      for (final label in ['历史轨迹', '可添加GPS', 'NFC钥匙']) {
        final action = find.bySemanticsLabel(label);
        expect(action, findsOneWidget);
        expect(
          tester.getSemantics(action),
          matchesSemantics(
            label: label,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
      }

      final vehicleSetting = find.bySemanticsLabel('车辆设置');
      expect(vehicleSetting, findsOneWidget);
      expect(
        tester.getSemantics(vehicleSetting),
        matchesSemantics(
          label: '车辆设置',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('official control tip has no extra channel row', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpBoundHome(tester, size: const Size(430, 2200));

      expect(find.textContaining('控车通道'), findsNothing);
      expect(find.text('手动模式'), findsNothing);

      final manualModeAction = find.bySemanticsLabel('手动模式');
      expect(manualModeAction, findsOneWidget);
      expect(tester.getSize(manualModeAction).height, greaterThanOrEqualTo(44));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('all functions sheet close exposes semantics and 44dp target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpBoundHome(tester, size: const Size(430, 2200));

      await tester.tap(find.text('更多功能'));
      await tester.pumpAndSettle();

      expect(find.text('全部功能'), findsOneWidget);
      const closeLabel = '关闭全部功能';
      final closeAction = find.bySemanticsLabel(closeLabel);
      expect(closeAction, findsOneWidget);
      expect(
        find.ancestor(
          of: find.byIcon(Icons.close),
          matching: find.byType(AppPressable),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(closeAction).height, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(closeAction),
        matchesSemantics(
          label: closeLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(closeLabel));
      await tester.pumpAndSettle();

      expect(find.text('全部功能'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });
}
