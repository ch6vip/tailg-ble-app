import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
