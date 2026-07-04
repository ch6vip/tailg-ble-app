import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/widgets/control_card.dart';

import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';

void main() {
  testWidgets('official quick placeholders render', (tester) async {
    await tester.pumpWidget(
      TestApp(
        home: ControlCard(onOpenSeat: () {}, onProximityUnlock: () {}),
      ),
    );

    expect(find.text('打开座桶'), findsNothing);
    expect(find.text('感应解锁'), findsNothing);
    expect(find.text('更多功能'), findsNothing);
  });

  testWidgets('official quick actions keep stable touch geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: ControlCard(
          onOpenSeat: () {},
          onProximityUnlock: () {},
          onQuickEdit: () {},
        ),
      ),
    );

    expect(find.bySemanticsLabel('添加快捷功能'), findsNWidgets(2));
    final edit = find.bySemanticsLabel('编辑快捷功能');
    expect(edit, findsOneWidget);
    expectMinTouchTargetHeight(tester, edit);

    for (final label in ['更多功能', '用车人', '超级仪表']) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('quick actions expose enabled labels', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        TestApp(
          home: ControlCard(
            onOpenSeat: () {},
            onProximityUnlock: () {},
            onQuickEdit: () {},
          ),
        ),
      );

      final placeholders = find.bySemanticsLabel('添加快捷功能');
      expect(placeholders, findsNWidgets(2));

      final edit = find.bySemanticsLabel('编辑快捷功能');
      expect(edit, findsOneWidget);
      expect(
        tester.getSemantics(edit),
        matchesSemantics(
          label: '编辑快捷功能',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('power knob fires after right slide completes', (tester) async {
    var powerCount = 0;

    await tester.pumpWidget(
      TestApp(home: ControlCard(onPowerOn: () => powerCount++)),
    );

    await tester.drag(
      find.byIcon(Icons.power_settings_new),
      const Offset(640, 0),
    );
    await tester.pumpAndSettle();

    expect(powerCount, 1);
  });

  testWidgets('powered knob fires after left slide completes', (tester) async {
    var powerCount = 0;

    await tester.pumpWidget(
      TestApp(home: ControlCard(powered: true, onPowerOn: () => powerCount++)),
    );

    await tester.drag(find.byIcon(Icons.power_off), const Offset(-640, 0));
    await tester.pumpAndSettle();

    expect(powerCount, 1);
  });

  testWidgets('power knob exposes slide semantics action', (tester) async {
    final semantics = tester.ensureSemantics();
    var powerCount = 0;

    try {
      await tester.pumpWidget(
        TestApp(home: ControlCard(onPowerOn: () => powerCount++)),
      );

      final powerAction = find.bySemanticsLabel('电源：右滑启动');
      expect(powerAction, findsOneWidget);
      expect(
        tester.getSemantics(powerAction),
        matchesSemantics(
          label: '电源：右滑启动',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasIncreaseAction: true,
        ),
      );

      tester.semantics.increase(find.semantics.byLabel('电源：右滑启动'));
      await tester.pump();

      expect(powerCount, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('powered knob exposes official close wording', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        TestApp(home: ControlCard(powered: true, onPowerOn: () {})),
      );

      expect(find.bySemanticsLabel('电源：左滑关闭'), findsOneWidget);
      expect(find.text('左滑关闭'), findsOneWidget);
      expect(find.text('左滑熄火'), findsNothing);
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
        node.getSemanticsData().hasAction(SemanticsAction.increase),
        isFalse,
      );
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.decrease),
        isFalse,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('lock command switches to disarm when vehicle is armed', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(home: ControlCard(locked: true, onUnlock: () {})),
    );

    expect(find.text('解防'), findsOneWidget);
    expect(find.text('设防'), findsNothing);
  });

  testWidgets('power knob ignores short slide', (tester) async {
    var powerCount = 0;

    await tester.pumpWidget(
      TestApp(home: ControlCard(onPowerOn: () => powerCount++)),
    );

    await tester.drag(
      find.byIcon(Icons.power_settings_new),
      const Offset(40, 0),
    );
    await tester.pumpAndSettle();

    expect(powerCount, 0);
  });

  testWidgets('power knob ignores secondary mouse button slides', (
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
    await gesture.moveBy(const Offset(180, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(powerCount, 0);
  });
}
