import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/pages/vehicle_message_page.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/snack_finders.dart';
import 'helpers/source_scan.dart';
import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';

void main() {
  test('VehicleMessagePage does not use empty setState refreshes', () {
    final source = readSource('lib/pages/vehicle_message_page.dart');

    expect(source, isNot(contains('setState(() {})')));
    expect(source, contains('_refreshVisibleMessages'));
  });

  setUp(() {
    resetMockPreferences();
    app.logService.clear();
  });

  tearDown(app.logService.clear);

  testWidgets('new log entries refresh visible messages automatically', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(home: VehicleMessagePage()));
    await tester.pump();

    expect(find.text('暂无消息'), findsOneWidget);

    app.logService.operation('发送指令');
    await tester.pump();
    await tester.pump();

    expect(find.text('发送指令'), findsOneWidget);
  });

  testWidgets('custom tabs keep 44dp touch targets', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const TestApp(home: VehicleMessagePage()));
      await tester.pump();

      final systemTab = find.ancestor(
        of: find.text('系统消息'),
        matching: find.byType(AppPressable),
      );
      expect(systemTab, findsOneWidget);
      expect(tester.getSize(systemTab).height, greaterThanOrEqualTo(44));

      const allLabel = '全部';
      expect(
        tester.getSemantics(find.bySemanticsLabel(allLabel)),
        matchesSemantics(
          label: allLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );

      const systemLabel = '系统消息';
      final systemTabSemantics = find.bySemanticsLabel(systemLabel);
      expect(
        tester.getSemantics(systemTabSemantics),
        matchesSemantics(
          label: systemLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(systemLabel));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(systemTabSemantics),
        matchesSemantics(
          label: systemLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('clearing current message group shows success snack', (
    tester,
  ) async {
    app.logService.operation('发送指令');

    await tester.pumpWidget(const TestApp(home: VehicleMessagePage()));
    await tester.pump();

    expect(find.text('发送指令'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('已清空 1 条当前分组消息'), findsOneWidget);
    expect(snackIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('message rows expose semantics and open detail sheet', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      app.logService.operation('发送指令');

      await tester.pumpWidget(const TestApp(home: VehicleMessagePage()));
      await tester.pump();

      const messageLabel = '发送指令，车辆指令已发送。，设备消息，未读';
      final messageRow = find.bySemanticsLabel(messageLabel);
      expect(messageRow, findsOneWidget);
      expect(
        tester.getSemantics(messageRow),
        matchesSemantics(
          label: messageLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(messageLabel));
      await tester.pumpAndSettle();

      expect(find.text('知道了'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
