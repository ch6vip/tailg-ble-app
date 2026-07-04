import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/pages/control_page.dart';
import 'package:tailg_ble_app/services/service_locator.dart';

import 'helpers/source_scan.dart';
import 'helpers/storage_mocks.dart';

void main() {
  test('ControlPage keeps home stream subscriptions split', () {
    final source = readSource('lib/pages/control_page.dart');

    expect(sourceExists('lib/utils/combined_stream.dart'), isFalse);
    expect(source, isNot(contains('_createCombinedStream')));
    expect(source, isNot(contains('_combinedStream')));
    expect(source, isNot(contains('StreamController<List<dynamic>>')));
    expect(source, isNot(contains('StreamSubscription<dynamic>')));
    expect(
      RegExp(
        r'StreamBuilder<ble\.ConnectionState>\(',
      ).allMatches(source).length,
      greaterThanOrEqualTo(1),
      reason:
          '_HomeTopSection should keep a typed connection-state subscription '
          'instead of sharing one combined home stream.',
    );
  });

  test('Home overview keeps bike state stream typed', () {
    final source = readSource('lib/pages/control_page_home_overview.dart');

    expect(source, contains('StreamBuilder<BikeState?>('));
    expect(source, isNot(contains('StreamBuilder<dynamic>(')));
  });

  setUp(() {
    resetMockStorage();
  });

  tearDown(() async {
    await AppServices.reset();
    resetMockStorage();
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
