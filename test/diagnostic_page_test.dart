import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/pages/diagnostic_page.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets(
    'diagnostic action shows info snack when vehicle is disconnected',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const TestApp(home: DiagnosticPage()));
      await tester.pump();

      await tester.tap(find.text('一键诊断'));
      await tester.pump();

      expect(find.text('请先连接车辆'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    },
  );
}
