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
}
