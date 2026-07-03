import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/vehicle_settings_page.dart';

import 'helpers/snack_finders.dart';
import 'helpers/test_app.dart';

void main() {
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
      expect(tester.getSize(pendingRow).height, greaterThanOrEqualTo(44));
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
      expect(tester.getSize(soundRow).height, greaterThanOrEqualTo(44));
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
