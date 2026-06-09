import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

import 'helpers/test_app.dart';

void main() {
  // Regression: the bound (vehicle-present) control home used to throw
  // "Null check operator used on a null value" on first build, because the
  // quick-function card's scroll-progress indicator read maxScrollExtent before
  // the horizontal list had laid out. In release that surfaced as a large grey
  // ErrorWidget filling the screen below the SHORTCUTS section.
  testWidgets('bound control home builds without throwing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    VehicleStore().resetForTest();
    await VehicleStore().init();
    await VehicleStore().upsert(
      id: 'AA:BB:CC:DD:EE:FF',
      name: '测试车辆',
      protocol: VehicleProtocol.auto,
      makeDefault: true,
    );

    await tester.pumpWidget(const TestApp(home: ControlPage()));
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('SHORTCUTS'), findsOneWidget);
  });
}
