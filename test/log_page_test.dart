import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/pages/log_page.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';
import 'package:tailg_ble_app/widgets/lucide_icon.dart';

import 'helpers/platform_mocks.dart';
import 'helpers/snack_finders.dart';
import 'helpers/source_scan.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';

void main() {
  test('LogPage does not use empty setState refreshes', () {
    final source = readSource('lib/pages/log_page.dart');

    expect(source, isNot(contains('setState(() {})')));
    expect(source, contains('_refreshVisibleLogs'));
  });

  test('LogPage has no BLE-era connection category tabs', () {
    final source = readSource('lib/pages/log_page.dart');

    expect(source, isNot(contains("LogCategory.connection")));
    expect(source, isNot(contains("'连接'")));
    expect(source, isNot(contains('TabController')));
  });

  setUp(() {
    app.logService.clear();
    mockClipboardWrites();
  });

  tearDown(() {
    app.logService.clear();
    clearPlatformChannelMock();
  });

  testWidgets('copy action shows info snack when logs are empty', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(home: LogPage()));

    await tester.tap(find.byIcon(Lucide.copy));
    await tester.pump();

    expect(find.text('当前没有可复制的日志'), findsOneWidget);
    expect(snackIcon(Lucide.info), findsOneWidget);
  });

  testWidgets('new log entries refresh the visible list automatically', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(home: LogPage()));
    await tester.pump();

    expect(find.text('暂无日志'), findsOneWidget);

    app.logService.operation('测试操作');
    await tester.pump();
    await tester.pump();

    expect(find.text('测试操作'), findsOneWidget);
  });

  testWidgets('log entries render optional details', (tester) async {
    app.logService.operation('测试操作', detail: '耗时 12ms');

    await tester.pumpWidget(const TestApp(home: LogPage()));
    await tester.pump();

    expect(find.text('测试操作'), findsOneWidget);
    expect(find.text('耗时 12ms'), findsOneWidget);
  });

  testWidgets('header actions keep 44dp touch targets', (tester) async {
    await tester.pumpWidget(const TestApp(home: LogPage()));

    for (final icon in [Lucide.copy, Lucide.refresh, Lucide.trash]) {
      final action = find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(AppPressable),
      );
      expect(action, findsOneWidget);
      expectMinTouchTargetHeight(tester, action);
    }
  });

  testWidgets('copy action exports logs and shows success snack', (
    tester,
  ) async {
    app.logService.operation('测试操作');

    await tester.pumpWidget(const TestApp(home: LogPage()));

    await tester.tap(find.byIcon(Lucide.copy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('已复制诊断报告（1 条日志）'), findsOneWidget);
    expect(snackIcon(Lucide.checkCircle), findsOneWidget);
  });
}
