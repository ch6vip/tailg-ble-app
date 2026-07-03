import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/pages/location_page.dart';
import 'package:tailg_ble_app/widgets/app_pressable.dart';

import 'helpers/test_app.dart';

void main() {
  test('LocationPage routes vehicle and cloud streams through notifiers', () {
    final source = File('lib/pages/location_page.dart').readAsStringSync();
    final vehiclesListener = _listenerBlock(
      source,
      'vehicleStore.vehiclesStream.listen',
    );
    final cloudListener = _listenerBlock(
      source,
      'officialCloudService.stateStream.listen',
    );

    expect(source, contains('ValueNotifier<OfficialCloudState>'));
    expect(source, contains('ValueNotifier<List<VehicleProfile>>'));
    expect(source, isNot(contains('setState(() {})')));

    expect(vehiclesListener, contains('_vehiclesNotifier.value = v'));
    expect(vehiclesListener, isNot(contains('setState')));
    expect(cloudListener, contains('_cloudStateNotifier.value = c'));
    expect(cloudListener, isNot(contains('setState')));
  });

  test('LocationPage keeps map tab isolated behind RepaintBoundary', () {
    final source = File('lib/pages/location_page.dart').readAsStringSync();

    expect(
      RegExp(r'RepaintBoundary\(\s*child:\s*_MapTab\(').hasMatch(source),
      isTrue,
      reason:
          'The map tab should stay behind RepaintBoundary so parent '
          'rebuilds do not repaint FlutterMap.',
    );
  });

  testWidgets('LocationPage segmented tabs keep 44dp touch targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    try {
      await tester.pumpWidget(
        const TestApp(home: LocationPage(embedded: true)),
      );
      await tester.pump();

      final locationTab = find.ancestor(
        of: find.text('位置'),
        matching: find.byType(AppPressable),
      );
      expect(locationTab, findsOneWidget);
      expect(tester.getSize(locationTab).height, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(find.bySemanticsLabel('位置')),
        matchesSemantics(
          label: '位置',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('轨迹')),
        matchesSemantics(
          label: '轨迹',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasSelectedState: true,
          isSelected: false,
        ),
      );

      const refreshLabel = '刷新';
      final refreshAction = find.bySemanticsLabel(refreshLabel);
      expect(refreshAction, findsOneWidget);
      expect(tester.getSize(refreshAction).height, greaterThanOrEqualTo(44));
      expect(
        tester.getSemantics(refreshAction),
        matchesSemantics(
          label: refreshLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(find.semantics.byLabel('轨迹'));
      await tester.pump();

      expect(find.text('历史轨迹'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('轨迹')),
        matchesSemantics(
          label: '轨迹',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('LocationPage travel month controls keep 44dp touch targets', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const TestApp(
        home: LocationPage(
          initialTab: LocationInitialTab.travel,
          embedded: true,
        ),
      ),
    );
    await tester.pump();

    final previousMonth = find.byTooltip('上个月');
    expect(previousMonth, findsOneWidget);
    expect(tester.getSize(previousMonth).height, greaterThanOrEqualTo(44));
  });
}

String _listenerBlock(String source, String listenerStart) {
  final start = source.indexOf(listenerStart);
  expect(start, isNot(-1), reason: 'Missing $listenerStart');

  final end = source.indexOf('});', start);
  expect(end, isNot(-1), reason: 'Missing end of $listenerStart block');

  return source.substring(start, end + 3);
}
