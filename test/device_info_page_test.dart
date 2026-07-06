import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/device_info_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/view_size.dart';

void main() {
  setUp(() {
    resetMockPreferences();
    app.vehicleStore.resetForTest();
    app.officialCloudService.resetForTest();
  });

  tearDown(() {
    app.vehicleStore.resetForTest();
    app.officialCloudService.resetForTest();
  });

  testWidgets('device info renders official vehicle status rows', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(430, 1200));
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'official-1',
      'carNickName': '官方车',
      'online': true,
      'electricQuantity': 88,
    });
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
      ),
    );

    await tester.pumpWidget(const TestApp(home: DeviceInfoPage()));
    await tester.pump();

    expect(find.text('官方在线'), findsOneWidget);
    expect(find.text('车辆在线'), findsOneWidget);
    expect(find.text('官方电量'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
  });
}
