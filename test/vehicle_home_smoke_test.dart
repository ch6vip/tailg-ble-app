import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/vehicle_control_home_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/service_locator.dart';

import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/view_size.dart';

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
    setTestViewSize(tester, const Size(390, 844));
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
    // Channel-only card on home; unlock/induction lives in settings.
    expect(find.text('控车渠道'), findsOneWidget);
    expect(find.text('智能'), findsOneWidget);
    expect(find.text('仅蓝牙'), findsOneWidget);
    expect(find.text('仅云端'), findsOneWidget);
    expect(find.text('控车与解锁'), findsNothing);
    expect(find.text('解锁模式'), findsNothing);
    expect(
      tester.getTopLeft(find.text('控车渠道')).dy,
      greaterThan(tester.getTopLeft(find.text('暂无位置')).dy),
    );
    expect(
      tester.getTopLeft(find.text('寻车')).dy,
      greaterThan(tester.getTopLeft(find.text('控车渠道')).dy),
    );

    await tester.tap(find.text('仅云端'));
    await tester.pump();
    expect(find.text('仅官方账号远程'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('最近命令'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('最近命令'), findsOneWidget);
  });
}
