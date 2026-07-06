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

  test('ScanPage handles manual scan startup failures', () {
    final source = readSource('lib/pages/scan_page.dart');

    expect(source, contains('on PlatformException catch'));
    expect(source, contains('手动扫描启动失败'));
    expect(source, contains('扫描启动失败，请检查蓝牙权限'));
  });

  test('ScanPage cancels scan subscriptions before disposing notifiers', () {
    final source = readSource('lib/pages/scan_page.dart');
    final cancelScanResults = source.indexOf('_scanResultsSub?.cancel();');
    final cancelIsScan = source.indexOf('_isScanSub?.cancel();');
    final disposeResultsNotifier = source.indexOf(
      '_resultsNotifier.dispose();',
    );

    expect(cancelScanResults, greaterThanOrEqualTo(0));
    expect(cancelIsScan, greaterThanOrEqualTo(0));
    expect(disposeResultsNotifier, greaterThanOrEqualTo(0));
    expect(cancelScanResults, lessThan(disposeResultsNotifier));
    expect(cancelIsScan, lessThan(disposeResultsNotifier));
  });

  test('ScanPage does not expose raw connection exceptions in snack text', () {
    final source = readSource('lib/pages/scan_page.dart');
    final catchStart = source.indexOf("logService.ble('连接绑定设备失败'");
    final catchEnd = source.indexOf('    } finally {', catchStart);

    expect(catchStart, greaterThanOrEqualTo(0));
    expect(catchEnd, greaterThan(catchStart));

    final catchSource = source.substring(catchStart, catchEnd);

    expect(catchSource, contains('detail: e.toString()'));
    expect(catchSource, contains("AppSnack.error(context, '连接失败，请稍后重试')"));
    expect(catchSource, isNot(contains("'连接失败: \$e'")));
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
