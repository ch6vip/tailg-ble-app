import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/firmware_ota_page.dart';
import 'package:tailg_ble_app/theme/app_colors.dart';

import 'helpers/test_app.dart';
import 'helpers/view_size.dart';

void main() {
  testWidgets('firmware OTA uses Cyber home mobile surface', (tester) async {
    setTestViewSize(tester, const Size(390, 844));

    await tester.pumpWidget(const TestApp(home: FirmwareOtaPage()));
    await tester.pump();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      CyberHomeColors.pageBg,
    );
    expect(find.text('车辆固件'), findsOneWidget);
    expect(find.text('检查并升级'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
