import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/add_vehicle_page.dart';
import 'package:tailg_ble_app/pages/official_cloud_page.dart';
import 'package:tailg_ble_app/pages/scan_page.dart';

import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

void main() {
  testWidgets('add vehicle page exposes cloud sync and BLE scan entries', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(430, 1400));

    await tester.pumpWidget(const TestApp(home: AddVehiclePage()));
    await tester.pump();

    expect(find.text('我的车辆'), findsOneWidget);
    expect(find.text('扫描附近车辆'), findsOneWidget);
    expect(find.text('扫码绑定'), findsNothing);
    expect(find.text('输入车架号/IMEI'), findsNothing);
    expect(find.text('门店购车绑定'), findsNothing);
    expect(find.textContaining('支持官方云端同步与本地蓝牙直连'), findsOneWidget);

    final action = find.bySemanticsLabel('我的车辆，登录官方账号后同步账号下已绑定车辆');
    expect(action, findsOneWidget);
    expectMinTouchTargetHeight(tester, action);
  });

  testWidgets('official account vehicle entry opens official page', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(home: AddVehiclePage()));
    await tester.pump();

    await tester.tap(find.text('我的车辆'));
    await tester.pumpAndSettle();

    expect(find.byType(OfficialCloudPage), findsOneWidget);
  });

  testWidgets('ble scan entry opens scan page', (tester) async {
    await tester.pumpWidget(const TestApp(home: AddVehiclePage()));
    await tester.pump();

    await tester.tap(find.text('扫描附近车辆'));
    await tester.pumpAndSettle();

    expect(find.byType(ScanPage), findsOneWidget);
  });
}
