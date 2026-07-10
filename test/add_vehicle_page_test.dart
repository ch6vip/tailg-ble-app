import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/add_vehicle_page.dart';
import 'package:tailg_ble_app/pages/official_cloud_page.dart';

import 'helpers/snack_finders.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

void main() {
  testWidgets('add vehicle page exposes official binding entries', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(430, 1400));

    await tester.pumpWidget(const TestApp(home: AddVehiclePage()));
    await tester.pump();

    for (final label in [
      '扫码绑定，扫描车身二维码添加车辆',
      '输入车架号/IMEI，手动填写车辆识别信息',
      '门店购车绑定，通过门店或购车记录完成绑定',
      '我的车辆，登录后自动显示账号下已绑定车辆',
      '绑定帮助，查看绑定说明和常见问题',
    ]) {
      final action = find.bySemanticsLabel(label);
      expect(action, findsOneWidget);
      expectMinTouchTargetHeight(tester, action);
    }
  });

  testWidgets('pending bind entry shows user-facing info snack', (
    tester,
  ) async {
    await tester.pumpWidget(const TestApp(home: AddVehiclePage()));
    await tester.pump();

    await tester.tap(find.text('扫码绑定'));
    await tester.pump();

    expect(find.text('扫码绑定暂未开放，请先登录账号同步已绑定车辆'), findsOneWidget);
    expect(snackIcon(Icons.info_outline), findsOneWidget);
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
}
