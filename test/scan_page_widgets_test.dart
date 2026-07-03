import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/scan_page.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('ScanFab exposes enabled scan semantics and target size', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;

    try {
      await tester.pumpWidget(
        TestApp(
          home: Scaffold(
            body: Center(
              child: ScanFab(
                scanning: false,
                enabled: true,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );

      final scanAction = find.bySemanticsLabel('扫描');
      expect(scanAction, findsOneWidget);
      expect(tester.getSize(scanAction).height, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(scanAction),
        matchesSemantics(
          label: '扫描',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel('扫描'));
      await tester.pump();

      expect(taps, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('ScanFab exposes disabled stop semantics without tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;

    try {
      await tester.pumpWidget(
        TestApp(
          home: Scaffold(
            body: Center(
              child: ScanFab(
                scanning: true,
                enabled: false,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );

      final stopAction = find.bySemanticsLabel('停止扫描');
      expect(stopAction, findsOneWidget);
      expect(tester.getSize(stopAction).height, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(stopAction),
        matchesSemantics(
          label: '停止扫描',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );

      await tester.tap(find.text('停止'));
      await tester.pump();

      expect(taps, 0);
    } finally {
      semantics.dispose();
    }
  });
}
