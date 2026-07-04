import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/widgets/app_chrome.dart';

import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';

void main() {
  testWidgets('AppHeaderAction exposes size and enabled semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;

    try {
      await tester.pumpWidget(
        TestApp(
          home: Scaffold(
            body: Center(
              child: AppHeaderAction(
                key: const ValueKey('header-action'),
                icon: Icons.refresh,
                tooltip: '刷新',
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );

      final action = find.bySemanticsLabel('刷新');
      expect(action, findsOneWidget);
      expectMinTouchTargetHeight(
        tester,
        find.byKey(const ValueKey('header-action')),
      );
      expect(
        tester.getSemantics(action),
        matchesSemantics(
          label: '刷新',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel('刷新'));
      await tester.pump();

      expect(taps, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('AppHeaderAction exposes disabled semantics', (tester) async {
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        const TestApp(
          home: Scaffold(
            body: Center(
              child: AppHeaderAction(icon: Icons.refresh, tooltip: '刷新'),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('刷新')),
        matchesSemantics(
          label: '刷新',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });
}
