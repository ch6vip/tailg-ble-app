import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/vehicle_control_home_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/service_locator.dart';

import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';

/// P4-4 light smoke: signed-in cloud state → 爱车 page renders without crash.
void main() {
  setUp(() async {
    resetMockStorage();
    await AppServices.reset();
  });

  tearDown(() async {
    await AppServices.reset();
    resetMockStorage();
  });

  testWidgets('signed-in vehicle home renders vehicle name', (tester) async {
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'smoke-1',
      'carNickName': '冒烟测试车',
      'modelType': 3,
      'isGps': 1,
      'btmac': 'AABBCCDDEEFF',
    });
    AppServices.instance.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'smoke-token',
        userId: 'u-smoke',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
      ),
    );

    await tester.pumpWidget(const TestApp(home: VehicleControlHomePage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('冒烟测试车'), findsWidgets);
  });
}
