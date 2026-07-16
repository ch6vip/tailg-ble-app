import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/service_hub_page.dart';

import 'helpers/test_app.dart';
import 'helpers/view_size.dart';

void main() {
  testWidgets('service hub uses sectioned IA without fat equal grid', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      setTestViewSize(tester, const Size(430, 1800));
      await tester.pumpWidget(const TestApp(home: ServiceHubPage()));
      await tester.pump();

      expect(find.text('服务中心'), findsOneWidget);
      expect(find.text('定位服务'), findsOneWidget);
      expect(find.text('车辆定位'), findsOneWidget);
      expect(find.text('历史轨迹'), findsOneWidget);
      expect(find.text('电子围栏'), findsOneWidget);
      expect(find.text('车辆与能耗'), findsOneWidget);
      expect(find.text('车辆设置'), findsOneWidget);
      expect(find.text('电池服务'), findsOneWidget);
      expect(find.text('骑行统计'), findsOneWidget);
      expect(find.text('更多'), findsOneWidget);
      expect(find.text('更多服务'), findsOneWidget);

      // Secondary entries stay off the first screen.
      expect(find.text('故障诊断'), findsNothing);
      expect(find.text('官方账号'), findsNothing);
      expect(find.text('售后服务'), findsNothing);
      expect(find.text('常用服务'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('更多服务 opens secondary entries page', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      setTestViewSize(tester, const Size(430, 1800));
      await tester.pumpWidget(const TestApp(home: ServiceHubPage()));
      await tester.pump();

      await tester.tap(find.text('更多服务'));
      await tester.pumpAndSettle();

      // Page header + list title both say 更多服务.
      expect(find.text('更多服务'), findsWidgets);
      expect(find.text('故障诊断'), findsOneWidget);
      expect(find.text('官方账号'), findsOneWidget);
      expect(find.text('售后服务'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
