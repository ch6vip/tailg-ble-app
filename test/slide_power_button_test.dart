import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/widgets/slide_power_button.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('power-off slider waits at the end then resets on failure', (
    tester,
  ) async {
    var activations = 0;
    final command = Completer<void>();
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Center(
            child: SlidePowerButton(
              isPowered: false,
              onSlide: () async {
                activations += 1;
                await command.future;
              },
            ),
          ),
        ),
      ),
    );

    final thumb = find.byKey(const ValueKey('slide-power-thumb'));
    final initialX = tester.getTopLeft(thumb).dx;
    expect(find.text('右滑启动'), findsOneWidget);

    await tester.drag(thumb, const Offset(120, 0));
    await tester.pump(const Duration(milliseconds: 160));

    expect(activations, 1);
    expect(find.text('正在通电'), findsOneWidget);
    expect(find.byKey(const ValueKey('power-progress')), findsOneWidget);
    expect(tester.getTopLeft(thumb).dx, closeTo(initialX + 100, 0.1));

    command.complete();
    await tester.pump();
    expect(find.byKey(const ValueKey('power-success-animation')), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(thumb).dx, closeTo(initialX, 0.1));
  });

  testWidgets('confirmed power-off keeps the thumb at its new resting side', (
    tester,
  ) async {
    var activations = 0;
    var powered = true;
    final command = Completer<void>();
    late StateSetter update;
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return SlidePowerButton(
                  isPowered: powered,
                  onSlide: () async {
                    activations += 1;
                    await command.future;
                    update(() => powered = false);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    final thumb = find.byKey(const ValueKey('slide-power-thumb'));
    final initialX = tester.getTopLeft(thumb).dx;
    expect(find.text('左滑关闭'), findsOneWidget);

    await tester.drag(thumb, const Offset(-120, 0));
    await tester.pump(const Duration(milliseconds: 160));

    expect(activations, 1);
    expect(find.text('正在断电'), findsOneWidget);
    expect(find.byKey(const ValueKey('power-progress')), findsOneWidget);
    expect(tester.getTopLeft(thumb).dx, closeTo(initialX - 100, 0.1));

    command.complete();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('power-success-animation')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(find.text('右滑启动'), findsOneWidget);
    expect(tester.getTopLeft(thumb).dx, closeTo(initialX - 100, 0.1));
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
              onSlide: () async {
                activations += 1;
              },
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

  testWidgets('unavailable slider remains tappable for reason feedback', (
    tester,
  ) async {
    var explanations = 0;
    var activations = 0;
    await tester.pumpWidget(
      TestApp(
        home: Scaffold(
          body: Center(
            child: SlidePowerButton(
              isPowered: false,
              enabled: false,
              unavailableReason: '蓝牙未连接',
              onUnavailable: () async {
                explanations += 1;
              },
              onSlide: () async {
                activations += 1;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('控车不可用'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('slide-power-semantics')));
    await tester.pump();
    expect(explanations, 1);
    expect(activations, 0);
  });
}
