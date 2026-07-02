import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/services/service_locator.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    await AppServices.reset();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('ControlPage ignores vehicle stream events after unmount', (
    tester,
  ) async {
    for (var i = 0; i < 6; i++) {
      await tester.pumpWidget(const MaterialApp(home: ControlPage()));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);

      await app.vehicleStore.upsert(
        id: 'vehicle-$i',
        name: 'Vehicle $i',
        makeDefault: true,
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Unmounted _HomeBody subscriptions must not update disposed '
            'notifiers when VehicleStore emits.',
      );
    }
  });
}
