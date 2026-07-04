import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/add_vehicle_page.dart';
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/snack_finders.dart';
import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

void main() {
  testWidgets('unbound banner auto advance pauses with app lifecycle', (
    tester,
  ) async {
    resetMockPreferences();
    VehicleStore().resetForTest();
    await VehicleStore().init();

    applyTestViewSize(tester, const Size(430, 2200));
    addTearDown(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const TestApp(home: ControlPage()));
    await tester.pump();

    expect(find.text('登录官方账号后同步车辆状态'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4, milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 401));
    await tester.pump();

    expect(find.text('手机就是你的车钥匙'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 401));

    expect(find.text('手机就是你的车钥匙'), findsOneWidget);
    expect(find.text('全面掌控车辆数据'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4, milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 401));
    await tester.pump();

    expect(find.text('全面掌控车辆数据'), findsOneWidget);
  });

  testWidgets('virtual experience action shows info snack', (tester) async {
    resetMockPreferences();
    VehicleStore().resetForTest();
    await VehicleStore().init();

    applyTestViewSize(tester, const Size(430, 2200));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const TestApp(home: ControlPage()));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('虚拟体验（演示）'));
    await tester.pump();

    expect(find.text('虚拟体验暂未开放，可先登录账号或使用近场连接'), findsOneWidget);
    expect(snackIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets(
    'official action buttons expose semantics and AppPressable feedback',
    (tester) async {
      final semantics = tester.ensureSemantics();
      resetMockPreferences();
      VehicleStore().resetForTest();
      await VehicleStore().init();

      try {
        applyTestViewSize(tester, const Size(430, 2200));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(const TestApp(home: ControlPage()));
        await tester.pump(const Duration(milliseconds: 50));

        for (final label in ['绑定设备', '虚拟体验（演示）']) {
          final semanticAction = find.bySemanticsLabel(label);
          expect(semanticAction, findsOneWidget);
          expect(
            tester.getSemantics(semanticAction),
            matchesSemantics(
              label: label,
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true,
            ),
          );
          final pressableAction = find.ancestor(
            of: find.text(label),
            matching: find.byType(AppPressable),
          );
          expect(pressableAction, findsOneWidget);
          expect(tester.getSize(pressableAction).height, 54);
        }

        tester.semantics.tap(find.semantics.byLabel('虚拟体验（演示）'));
        await tester.pump();

        expect(find.text('虚拟体验暂未开放，可先登录账号或使用近场连接'), findsOneWidget);
        expect(snackIcon(Icons.info_outline), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('primary bind action opens add vehicle page', (tester) async {
    final semantics = tester.ensureSemantics();
    resetMockPreferences();
    VehicleStore().resetForTest();
    await VehicleStore().init();

    try {
      applyTestViewSize(tester, const Size(430, 2200));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const TestApp(home: ControlPage()));
      await tester.pump(const Duration(milliseconds: 50));

      const linkLabel = '绑定设备';
      final officialCloudAction = find.bySemanticsLabel(linkLabel);
      expect(officialCloudAction, findsOneWidget);
      expect(
        tester.getSemantics(officialCloudAction),
        matchesSemantics(
          label: linkLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(linkLabel));
      await tester.pumpAndSettle();

      expect(find.byType(AddVehiclePage), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('bluetooth direct text link exposes semantics and 44dp target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    resetMockPreferences();
    VehicleStore().resetForTest();
    await VehicleStore().init();

    try {
      applyTestViewSize(tester, const Size(430, 2200));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const TestApp(home: ControlPage()));
      await tester.pump(const Duration(milliseconds: 50));

      const linkLabel = '附近车辆？使用近场连接';
      final officialCloudLink = find.ancestor(
        of: find.text(linkLabel),
        matching: find.byType(InkWell),
      );
      expect(officialCloudLink, findsOneWidget);
      expectMinTouchTargetHeight(tester, officialCloudLink);

      final linkAction = find.bySemanticsLabel(linkLabel);
      expect(linkAction, findsOneWidget);
      expect(
        tester.getSemantics(linkAction),
        matchesSemantics(
          label: linkLabel,
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
}
