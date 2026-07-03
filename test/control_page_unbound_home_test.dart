import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/pages/official_cloud_page.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/snack_finders.dart';
import 'helpers/test_app.dart';

void main() {
  testWidgets('unbound banner auto advance pauses with app lifecycle', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    VehicleStore().resetForTest();
    await VehicleStore().init();

    tester.view.physicalSize = const Size(430, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const TestApp(home: ControlPage()));
    await tester.pump();

    expect(find.text('绑定设备后同步车辆状态'), findsOneWidget);

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
    SharedPreferences.setMockInitialValues({});
    VehicleStore().resetForTest();
    await VehicleStore().init();

    tester.view.physicalSize = const Size(430, 2200);
    tester.view.devicePixelRatio = 1.0;
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

    expect(find.text('虚拟体验功能开发中，可先「绑定设备」或登录官方账号查看车辆'), findsOneWidget);
    expect(snackIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('official action buttons use AppPressable feedback', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    VehicleStore().resetForTest();
    await VehicleStore().init();

    tester.view.physicalSize = const Size(430, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const TestApp(home: ControlPage()));
    await tester.pump(const Duration(milliseconds: 50));

    for (final label in ['绑定设备', '虚拟体验（演示）']) {
      final action = find.ancestor(
        of: find.text(label),
        matching: find.byType(AppPressable),
      );
      expect(action, findsOneWidget);
      expect(tester.getSize(action).height, 54);
    }
  });

  testWidgets('official cloud text link exposes semantics and 44dp target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({});
    VehicleStore().resetForTest();
    await VehicleStore().init();

    try {
      tester.view.physicalSize = const Size(430, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const TestApp(home: ControlPage()));
      await tester.pump(const Duration(milliseconds: 50));

      const linkLabel = '已绑定官方账号？登录后自动显示车辆';
      final officialCloudLink = find.ancestor(
        of: find.text(linkLabel),
        matching: find.byType(InkWell),
      );
      expect(officialCloudLink, findsOneWidget);
      expect(
        tester.getSize(officialCloudLink).height,
        greaterThanOrEqualTo(44),
      );

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

      tester.semantics.tap(find.semantics.byLabel(linkLabel));
      await tester.pumpAndSettle();

      expect(find.byType(OfficialCloudPage), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
