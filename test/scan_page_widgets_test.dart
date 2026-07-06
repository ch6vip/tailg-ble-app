import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/scan_page.dart';

import 'helpers/source_scan.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';

void main() {
  test('ScanPage uses injectable clock for manual bind timestamp', () {
    final source = readSource('lib/pages/scan_page.dart');

    expect(source, contains('final DateTime Function()? clock;'));
    expect(source, contains('widget.clock ?? DateTime.now'));
    expect(source, isNot(contains('lastConnectedAt: DateTime.now()')));
  });

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
      expectMinTouchTargetHeight(tester, scanAction);
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
      expectMinTouchTargetHeight(tester, stopAction);
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
