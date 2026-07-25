import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/widgets/slide_to_unlock_button.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('slide unlock exposes an accessible activation action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var unlocks = 0;
    try {
      await tester.pumpWidget(
        TestApp(
          home: Scaffold(
            body: Center(
              child: SlideToUnlockButton(onUnlocked: () => unlocks++),
            ),
          ),
        ),
      );

      final action = find.bySemanticsLabel('滑动开锁');
      expect(action, findsOneWidget);
      expect(
        tester.getSemantics(action),
        matchesSemantics(
          label: '滑动开锁',
          hint: '向右滑动，或使用辅助功能激活',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel('滑动开锁'));
      await tester.pump();
      expect(unlocks, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('dragging the thumb across the threshold unlocks once', (
    tester,
  ) async {
    var unlocks = 0;
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Center(child: SlideToUnlockButton(onUnlocked: () => unlocks++)),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('slide-unlock-thumb')),
      const Offset(110, 0),
    );
    await tester.pump();

    expect(unlocks, 1);
  });
}
