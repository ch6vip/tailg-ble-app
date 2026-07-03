import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';
import 'package:tailg_ble_app/widgets/control_card.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('side action remains tappable through AppPressable', (
    tester,
  ) async {
    var seatOpenCount = 0;

    await tester.pumpWidget(
      TestApp(home: ControlCard(onSeatOpen: () => seatOpenCount++)),
    );

    await tester.tap(find.text('打开座桶'));
    await tester.pump();

    expect(seatOpenCount, 1);
  });

  testWidgets('sub controls use AppPressable feedback', (tester) async {
    await tester.pumpWidget(const TestApp(home: ControlCard()));

    for (final label in ['感应解锁', '用车人', '超级仪表']) {
      final control = find.ancestor(
        of: find.text(label),
        matching: find.byType(AppPressable),
      );
      expect(control, findsOneWidget);
      expect(tester.getSize(control).height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('pressable actions expose labels and selected semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var seatOpenCount = 0;
    bool? proximityNext;
    try {
      await tester.pumpWidget(
        TestApp(
          home: ControlCard(
            onSeatOpen: () => seatOpenCount++,
            onToggleProximity: (value) => proximityNext = value,
            proximityEnabled: true,
          ),
        ),
      );

      final seatAction = find.bySemanticsLabel('打开座桶');
      expect(seatAction, findsOneWidget);
      expect(
        tester.getSemantics(seatAction),
        matchesSemantics(
          label: '打开座桶',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('打开座桶'));
      await tester.pump();
      expect(seatOpenCount, 1);

      final proximityAction = find.bySemanticsLabel('感应解锁');
      expect(proximityAction, findsOneWidget);
      expect(
        tester.getSemantics(proximityAction),
        matchesSemantics(
          label: '感应解锁',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      tester.semantics.tap(find.semantics.byLabel('感应解锁'));
      await tester.pump();
      expect(proximityNext, isFalse);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('power knob fires after hold completes', (tester) async {
    var powerCount = 0;

    await tester.pumpWidget(
      TestApp(home: ControlCard(onPowerOn: () => powerCount++)),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.power_settings_new)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await gesture.up();
    await tester.pump();

    expect(powerCount, 1);
  });

  testWidgets('power knob exposes a long-press semantics action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var powerCount = 0;

    try {
      await tester.pumpWidget(
        TestApp(home: ControlCard(onPowerOn: () => powerCount++)),
      );

      final powerAction = find.bySemanticsLabel('电源：长按开机');
      expect(powerAction, findsOneWidget);
      expect(
        tester.getSemantics(powerAction),
        matchesSemantics(
          label: '电源：长按开机',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasLongPressAction: true,
        ),
      );

      tester.semantics.longPress(find.semantics.byLabel('电源：长按开机'));
      await tester.pump();

      expect(powerCount, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('busy power knob exposes disabled semantics', (tester) async {
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        TestApp(home: ControlCard(onPowerOn: () {}, busy: true)),
      );

      final powerAction = find.bySemanticsLabel('电源：处理中');
      expect(powerAction, findsOneWidget);
      final SemanticsNode node = tester.getSemantics(powerAction);
      expect(
        node,
        matchesSemantics(
          label: '电源：处理中',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.longPress),
        isFalse,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('power knob cancels hold after pointer leaves knob', (
    tester,
  ) async {
    var powerCount = 0;

    await tester.pumpWidget(
      TestApp(home: ControlCard(onPowerOn: () => powerCount++)),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.power_settings_new)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveBy(const Offset(140, 0));
    await tester.pump(const Duration(milliseconds: 1300));
    await gesture.up();
    await tester.pump();

    expect(powerCount, 0);
  });

  testWidgets('power knob ignores secondary mouse button holds', (
    tester,
  ) async {
    var powerCount = 0;

    await tester.pumpWidget(
      TestApp(home: ControlCard(onPowerOn: () => powerCount++)),
    );

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.down(tester.getCenter(find.byIcon(Icons.power_settings_new)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await gesture.up();
    await tester.pump();

    expect(powerCount, 0);
  });
}
