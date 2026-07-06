import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/main.dart' as app;
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/pages/battery_details_page.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

import 'helpers/snack_finders.dart';
import 'helpers/source_scan.dart';
import 'helpers/test_app.dart';
import 'helpers/touch_target.dart';
import 'helpers/view_size.dart';

void main() {
  setUp(() {
    app.officialCloudService.resetForTest();
  });

  test('BatteryDetailsPage redacts refresh failure snack messages', () {
    final source = readSource('lib/pages/battery_details_page.dart');
    final refreshStart = source.indexOf('Future<void> _refreshOfficialBattery');
    final helperStart = source.indexOf(
      'String _errorMessage(Object e)',
      refreshStart,
    );
    final helperEnd = source.indexOf('class _BatteryHero', helperStart);

    expect(refreshStart, greaterThanOrEqualTo(0));
    expect(helperStart, greaterThan(refreshStart));
    expect(helperEnd, greaterThan(helperStart));

    final refreshSource = source.substring(refreshStart, helperStart);
    final helperSource = source.substring(helperStart, helperEnd);

    expect(
      refreshSource,
      contains('AppSnack.error(context, _errorMessage(e))'),
    );
    expect(
      refreshSource,
      isNot(contains('AppSnack.error(context, e.toString())')),
    );
    expect(helperSource, contains('OfficialCloudRedactor.text(e.message)'));
    expect(helperSource, contains('OfficialCloudRedactor.text(e.toString())'));
  });

  testWidgets('refreshing battery details while signed out shows info snack', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(430, 1200));

    await tester.pumpWidget(const TestApp(home: BatteryDetailsPage()));
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('请先登录官方账号'), findsOneWidget);
    expect(snackIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('battery correction action keeps a 44dp touch target', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(430, 1200));

    await tester.pumpWidget(const TestApp(home: BatteryDetailsPage()));
    await tester.pump();

    final correctionAction = find.ancestor(
      of: find.text('更正电池'),
      matching: find.byType(TextButton),
    );
    expect(correctionAction, findsOneWidget);
    expectMinTouchTargetHeight(tester, correctionAction);
  });

  testWidgets('official battery metrics render voltage and temperature', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(430, 1200));
    app.officialCloudService.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'token',
        batteryInfo: OfficialBatteryInfo.fromJson({
          'voltage': 52.4,
          'temperature': 31.2,
        }),
      ),
    );

    await tester.pumpWidget(const TestApp(home: BatteryDetailsPage()));
    await tester.pump();

    expect(find.text('52.4V'), findsWidgets);
    expect(find.text('31.2°C'), findsWidgets);
  });
}
