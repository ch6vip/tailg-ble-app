import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/widgets/control_card.dart';

import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';

void main() {
  testWidgets('official quick actions render', (tester) async {
    await tester.pumpWidget(TestApp(home: ControlCard(onOpenSeat: () {})));

    expect(find.text('打开座桶'), findsOneWidget);
    expect(find.bySemanticsLabel('添加快捷功能'), findsOneWidget);
    expect(find.text('更多功能'), findsNothing);
  });

  testWidgets('official quick actions keep stable touch geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: ControlCard(onOpenSeat: () {}, onQuickEdit: () {}),
      ),
    );

    final openSeat = find.bySemanticsLabel('打开座桶');
    expect(openSeat, findsOneWidget);
    expectMinTouchTargetHeight(tester, openSeat);

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
          home: ControlCard(onOpenSeat: () {}, onQuickEdit: () {}),
        ),
      );

      final action = find.bySemanticsLabel('打开座桶');
      expect(action, findsOneWidget);
      expect(
        tester.getSemantics(action),
        matchesSemantics(
          label: '打开座桶',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

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

  testWidgets('quick actions invoke assigned callbacks', (tester) async {
    var openSeatCount = 0;
    var editCount = 0;

    await tester.pumpWidget(
      TestApp(
        home: ControlCard(
          onOpenSeat: () => openSeatCount++,
          onQuickEdit: () => editCount++,
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('打开座桶'));
    await tester.tap(find.bySemanticsLabel('编辑快捷功能'));
    await tester.pumpAndSettle();

    expect(openSeatCount, 1);
    expect(editCount, 1);
  });

  testWidgets('quick actions fall back to placeholders without callbacks', (
    tester,
  ) async {
    var editCount = 0;

    await tester.pumpWidget(
      TestApp(home: ControlCard(onQuickEdit: () => editCount++)),
    );

    expect(find.text('打开座桶'), findsNothing);
    final placeholders = find.bySemanticsLabel('添加快捷功能');
    expect(placeholders, findsNWidgets(2));

    await tester.tap(placeholders.first);
    await tester.tap(placeholders.last);
    await tester.pumpAndSettle();

    expect(editCount, 2);
  });

  testWidgets('power knob fires after right slide completes', (tester) async {
    var powerCount = 0;

    await tester.pumpWidget(
      TestApp(home: ControlCard(onPowerOn: () => powerCount++)),
    );

    await tester.drag(
      find.byKey(const ValueKey('control-power-slide')),
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

    await tester.drag(
      find.byKey(const ValueKey('control-power-slide')),
      const Offset(-640, 0),
    );
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

  testWidgets('right slide startup uses square official handle', (
    tester,
  ) async {
    await tester.pumpWidget(TestApp(home: ControlCard(onPowerOn: () {})));

    final slide = find.byKey(const ValueKey('control-power-slide'));
    final track = tester
        .widgetList<Container>(
          find.descendant(of: slide, matching: find.byType(Container)),
        )
        .firstWhere((container) {
          final decoration = container.decoration;
          return decoration is BoxDecoration &&
              decoration.color == const Color(0xFFEFF0F5);
        });
    final decoration = track.decoration as BoxDecoration;
    final assetNames = tester
        .widgetList<Image>(
          find.descendant(of: slide, matching: find.byType(Image)),
        )
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((asset) => asset.assetName);

    expect(decoration.image, isNull);
    expect(
      assetNames,
      contains('assets/official_tailg/ic_slide_start_tip_r.png'),
    );
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
      find.byKey(const ValueKey('control-power-slide')),
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
    await gesture.down(
      tester.getCenter(find.byKey(const ValueKey('control-power-slide'))),
    );
    await gesture.moveBy(const Offset(180, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(powerCount, 0);
  });
}
