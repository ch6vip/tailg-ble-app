import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/service_hub_page.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

Future<void> _pumpServiceHub(WidgetTester tester, Size size) async {
  applyTestViewSize(tester, size);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(const TestApp(home: ServiceHubPage()));
  await tester.pump();
  expect(tester.takeException(), isNull);
  expect(find.text('服务中心'), findsOneWidget);
  expect(find.text('车辆定位'), findsOneWidget);
}

void main() {
  testWidgets('service hub tiles render on wide surface', (tester) async {
    await _pumpServiceHub(tester, const Size(2400, 2400));
    expect(find.text('历史轨迹'), findsOneWidget);
    expect(find.text('电子围栏'), findsOneWidget);
    expect(find.text('车辆设置'), findsOneWidget);
  });

  testWidgets('service hub tiles render on narrow surface', (tester) async {
    await _pumpServiceHub(tester, const Size(430, 2600));
    expect(find.text('历史轨迹'), findsOneWidget);
    expect(find.text('电池服务'), findsOneWidget);
  });

  testWidgets('service hub displays key text labels', (tester) async {
    await _pumpServiceHub(tester, const Size(430, 2600));
    for (final label in ['车辆定位', '历史轨迹', '电子围栏', '车辆设置', '电池服务']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('service hub tiles use AppPressable feedback', (tester) async {
    await _pumpServiceHub(tester, const Size(430, 2600));

    for (final label in ['车辆定位', '历史轨迹']) {
      final tile = find.ancestor(
        of: find.text(label),
        matching: find.byType(AppPressable),
      );
      expect(tile, findsOneWidget);
      expectMinTouchTargetHeight(tester, tile);
    }
  });

  testWidgets('service hub tiles expose semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpServiceHub(tester, const Size(430, 2600));

      for (final label in ['车辆定位', '历史轨迹', '电子围栏']) {
        final tile = find.bySemanticsLabel(label);
        expect(tile, findsOneWidget);
        expect(
          tester.getSemantics(tile),
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
