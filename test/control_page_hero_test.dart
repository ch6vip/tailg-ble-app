import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/control_page_hero.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/typography.dart';
import 'helpers/view_size.dart';

void main() {
  testWidgets('hero actions expose semantics and keep 44dp targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var vehicleTapped = false;
    var connectTapped = false;
    var detailTapped = false;
    var messageTapped = false;

    try {
      await tester.pumpWidget(
        TestApp(
          home: Scaffold(
            body: ControlPageHero(
              batteryLevel: 72,
              rangeKm: 48,
              vehicleName: '测试车辆',
              onVehicleSwitch: () => vehicleTapped = true,
              onConnect: () => connectTapped = true,
              onDetail: () => detailTapped = true,
              onMessage: () => messageTapped = true,
            ),
          ),
        ),
      );

      final vehicleSwitch = find.byKey(
        const ValueKey('control-hero-vehicle-switch'),
      );
      expect(vehicleSwitch, findsOneWidget);
      expectMinTouchTargetHeight(tester, vehicleSwitch);

      const vehicleLabel = '测试车辆，切换车辆';
      final vehicleAction = find.bySemanticsLabel(vehicleLabel);
      expect(vehicleAction, findsOneWidget);
      expect(
        tester.getSemantics(vehicleAction),
        matchesSemantics(
          label: vehicleLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      const batteryLabel = '电量 72%，续航 48 km';
      final batteryAction = find.bySemanticsLabel(batteryLabel);
      expect(batteryAction, findsOneWidget);
      expect(
        tester.getSemantics(batteryAction),
        matchesSemantics(label: batteryLabel),
      );

      const connectLabel = '点击连接';
      final connectAction = find.bySemanticsLabel(connectLabel);
      expect(connectAction, findsOneWidget);
      expectMinTouchTargetHeight(tester, connectAction);
      expect(
        find.byKey(const ValueKey('control-hero-message-dot')),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text(connectLabel),
          matching: find.byType(AppPressable),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(connectAction),
        matchesSemantics(
          label: connectLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      for (final label in ['车辆详情', '消息']) {
        final action = find.bySemanticsLabel(label);
        expect(action, findsOneWidget);
        expectMinTouchTargetHeight(tester, action);
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

      tester.semantics.tap(find.semantics.byLabel(vehicleLabel));
      tester.semantics.tap(find.semantics.byLabel(connectLabel));
      tester.semantics.tap(find.semantics.byLabel('车辆详情'));
      tester.semantics.tap(find.semantics.byLabel('消息'));

      expect(vehicleTapped, isTrue);
      expect(connectTapped, isTrue);
      expect(detailTapped, isTrue);
      expect(messageTapped, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('hero title and battery metrics avoid negative letter spacing', (
    tester,
  ) async {
    Future<void> pumpHero(Size size) async {
      applyTestViewSize(tester, size);
      await tester.pumpWidget(
        const TestApp(
          home: Scaffold(
            body: ControlPageHero(
              batteryLevel: 72,
              rangeKm: 48,
              vehicleName: '测试车辆',
            ),
          ),
        ),
      );
      await tester.pump();
    }

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final size in [const Size(430, 900), const Size(320, 900)]) {
      await pumpHero(size);

      final titleSpacing = tester
          .widget<Text>(find.text('测试车辆'))
          .style
          ?.letterSpacing;
      final rangeSpacing = tester
          .widget<Text>(find.text('48'))
          .style
          ?.letterSpacing;

      expect(titleSpacing, nonNegativeLetterSpacing);
      expect(rangeSpacing, nonNegativeLetterSpacing);
    }
  });

  testWidgets('ble connection pill follows official status labels', (
    tester,
  ) async {
    Future<void> pump(String? label) async {
      await tester.pumpWidget(
        TestApp(
          home: Scaffold(
            body: ControlPageHero(
              batteryLevel: 72,
              rangeKm: 48,
              vehicleName: '测试车辆',
              connectionLabel: label,
              connectionVariant: 'QGJ',
              onConnect: () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pump('未连接');
    expect(find.bySemanticsLabel('点击连接'), findsOneWidget);
    expect(find.text('QGJ'), findsOneWidget);

    await pump('连接中');
    expect(find.bySemanticsLabel('连接中'), findsOneWidget);

    await pump('正在重连');
    expect(find.bySemanticsLabel('重连中'), findsOneWidget);

    await pump('已连接');
    expect(find.bySemanticsLabel('已连接'), findsOneWidget);
  });
}
