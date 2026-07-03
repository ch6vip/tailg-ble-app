import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

import 'helpers/test_app.dart';

Future<void> _pumpControlPage(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  VehicleStore().resetForTest();
  await VehicleStore().init();
  await VehicleStore().upsert(
    id: 'AA:BB:CC:DD:EE:FF',
    name: '测试车辆',
    protocol: VehicleProtocol.auto,
    makeDefault: true,
  );

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(const TestApp(home: ControlPage()));
  await tester.pump(const Duration(milliseconds: 50));
  expect(tester.takeException(), isNull);
  // v8: 3 service cards replace old SHORTCUTS
  expect(find.text('车辆定位'), findsOneWidget);
}

void main() {
  // v8: service cards render without overflow on wide surfaces
  testWidgets('service cards render on wide surface', (tester) async {
    await _pumpControlPage(tester, const Size(2400, 2400));
    expect(find.text('电池详情'), findsOneWidget);
    expect(find.text('骑行记录'), findsOneWidget);
  });

  // v8: service cards remain stable on narrow surfaces
  testWidgets('service cards render on narrow surface', (tester) async {
    await _pumpControlPage(tester, const Size(430, 2600));
    expect(find.text('电池详情'), findsOneWidget);
    expect(find.text('骑行记录'), findsOneWidget);
  });

  // v8: service cards visible on control page
  testWidgets('service cards display key text labels', (tester) async {
    await _pumpControlPage(tester, const Size(430, 2600));
    expect(find.text('车辆定位'), findsOneWidget);
    expect(find.text('电池详情'), findsOneWidget);
    expect(find.text('骑行记录'), findsOneWidget);
  });

  testWidgets('service cards expose semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpControlPage(tester, const Size(430, 2600));

      const locationLabel = '车辆定位，查看车辆实时位置与导航';
      final locationCard = find.bySemanticsLabel(locationLabel);
      expect(locationCard, findsOneWidget);
      expect(
        tester.getSemantics(locationCard),
        matchesSemantics(
          label: locationLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      const batteryLabel = '电池详情，BMS 电压 · 温度 · 循环次数，健康 96%';
      final batteryCard = find.bySemanticsLabel(batteryLabel);
      expect(batteryCard, findsOneWidget);
      expect(
        tester.getSemantics(batteryCard),
        matchesSemantics(
          label: batteryLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      const travelLabel = '骑行记录，轨迹回放 · 里程统计';
      final travelCard = find.bySemanticsLabel(travelLabel);
      expect(travelCard, findsOneWidget);
      expect(
        tester.getSemantics(travelCard),
        matchesSemantics(
          label: travelLabel,
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
