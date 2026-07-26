import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/widgets/slide_power_button.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('power-off slider starts right and resets after activation', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Center(
            child: SlidePowerButton(
              isPowered: false,
              onSlide: () => activations++,
            ),
          ),
        ),
      ),
    );

    final thumb = find.byKey(const ValueKey('slide-power-thumb'));
    final initialX = tester.getTopLeft(thumb).dx;
    expect(find.text('右滑启动'), findsOneWidget);

    await tester.drag(thumb, const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(activations, 1);
    expect(tester.getTopLeft(thumb).dx, closeTo(initialX, 0.1));
  });

  testWidgets('power-on slider starts right, slides left and resets', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Center(
            child: SlidePowerButton(
              isPowered: true,
              onSlide: () => activations++,
            ),
          ),
        ),
      ),
    );

    final thumb = find.byKey(const ValueKey('slide-power-thumb'));
    final initialX = tester.getTopLeft(thumb).dx;
    expect(find.text('左滑关闭'), findsOneWidget);

    await tester.drag(thumb, const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(activations, 1);
    expect(tester.getTopLeft(thumb).dx, closeTo(initialX, 0.1));
  });

  testWidgets('unknown and busy states disable activation', (tester) async {
    var activations = 0;
    Widget app({required bool? powered, bool busy = false}) {
      return TestApp(
        home: Scaffold(
          body: Center(
            child: SlidePowerButton(
              isPowered: powered,
              busy: busy,
              onSlide: () => activations++,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(app(powered: null));
    expect(find.text('车辆状态未知'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('slide-power-thumb')),
      const Offset(120, 0),
    );
    expect(activations, 0);

    await tester.pumpWidget(app(powered: false, busy: true));
    await tester.pump();
    expect(find.text('指令执行中'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('slide-power-thumb')),
      const Offset(120, 0),
    );
    await tester.pump();
    expect(activations, 0);
  });
}
