import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/pages/garage_page.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';

void main() {
  setUp(() async {
    resetMockPreferences();
    app.vehicleStore.resetForTest();
    app.homeTabIndex.value = 3;
    await app.vehicleStore.init();
    await app.vehicleStore.upsert(
      id: 'AA:BB:CC:DD:EE:FF',
      name: '测试车辆',
      protocol: VehicleProtocol.auto,
      makeDefault: true,
    );
  });

  tearDown(() {
    app.vehicleStore.resetForTest();
    app.homeTabIndex.value = 0;
  });

  testWidgets('mini vehicle actions keep 44dp touch targets', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const TestApp(home: GaragePage(embedded: true)));
      await tester.pump();

      final locateAction = find.ancestor(
        of: find.text('定位'),
        matching: find.byType(AppPressable),
      );
      expect(locateAction, findsOneWidget);
      expectMinTouchTargetHeight(tester, locateAction);

      const locateLabel = '定位';
      final locateSemantics = find.bySemanticsLabel(locateLabel);
      expect(
        tester.getSemantics(locateSemantics),
        matchesSemantics(
          label: locateLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel(locateLabel));

      expect(app.homeTabIndex.value, 1);
    } finally {
      semantics.dispose();
    }
  });
}
