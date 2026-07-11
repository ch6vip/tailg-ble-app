import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

Future<void> _pumpControlPage(WidgetTester tester, Size size) async {
  resetMockPreferences();
  VehicleStore().resetForTest();
  await VehicleStore().init();
  await VehicleStore().upsert(
    id: 'AA:BB:CC:DD:EE:FF',
    name: '测试车辆',
    protocol: VehicleProtocol.auto,
    makeDefault: true,
  );

  applyTestViewSize(tester, size);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(const TestApp(home: ControlPage()));
  await tester.pump(const Duration(milliseconds: 50));
  expect(tester.takeException(), isNull);
  // Official replica lower area follows app-ui fragment_control.xml.
  expect(find.text('车辆定位'), findsOneWidget);
}

void main() {
  // Official lower entries render without overflow on wide surfaces.
  testWidgets('service cards render on wide surface', (tester) async {
    await _pumpControlPage(tester, const Size(2400, 2400));
    expect(find.text('历史轨迹'), findsOneWidget);
    expect(find.text('功能设置'), findsOneWidget);
    expect(find.text('NFC钥匙'), findsNothing);
  });

  // Official lower entries remain stable on narrow surfaces.
  testWidgets('service cards render on narrow surface', (tester) async {
    await _pumpControlPage(tester, const Size(430, 2600));
    expect(find.text('历史轨迹'), findsOneWidget);
    expect(find.bySemanticsLabel('可添加GPS'), findsOneWidget);
  });

  // Official lower entries are visible on control page.
  testWidgets('service cards display key text labels', (tester) async {
    await _pumpControlPage(tester, const Size(430, 2600));
    expect(find.text('车辆定位'), findsOneWidget);
    expect(find.text('历史轨迹'), findsOneWidget);
    expect(find.text('功能设置'), findsOneWidget);
    expect(find.text('NFC钥匙'), findsNothing);
  });

  testWidgets('service cards use AppPressable feedback', (tester) async {
    await _pumpControlPage(tester, const Size(430, 2600));

    for (final label in ['车辆定位', '历史轨迹']) {
      final card = find.ancestor(
        of: find.text(label),
        matching: find.byType(AppPressable),
      );
      expect(card, findsOneWidget);
      expectMinTouchTargetHeight(tester, card);
    }

    final gpsCard = find.bySemanticsLabel('可添加GPS');
    expect(gpsCard, findsOneWidget);
    expectMinTouchTargetHeight(tester, gpsCard);
  });

  testWidgets('service cards expose semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpControlPage(tester, const Size(430, 2600));

      for (final label in ['车辆定位', '历史轨迹', '可添加GPS']) {
        final card = find.bySemanticsLabel(label);
        expect(card, findsOneWidget);
        expect(
          tester.getSemantics(card),
          matchesSemantics(
            label: label,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
      }
    } finally {
      semantics.dispose();
    }
  });
}
