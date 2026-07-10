import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/pages/diagnostic_page.dart';
import 'package:tailg_ble_app/services/log_service.dart';
import 'package:tailg_ble_app/services/service_locator.dart';

import 'helpers/storage_mocks.dart';
import 'helpers/test_app.dart';
import 'helpers/view_size.dart';

void main() {
  tearDown(() async {
    await AppServices.reset();
    LogService().clear();
    resetMockPreferences();
  });

  testWidgets('diagnostic page renders persisted fault records', (
    tester,
  ) async {
    setTestViewSize(tester, const Size(430, 2400));
    final persisted = List.generate(3, (index) {
      final raw = index + 1;
      return jsonEncode(
        DiagnosticRecord(
          time: DateTime(2026, 6, 9, 10, raw),
          rawByte: raw,
          faults: ['故障 $raw'],
        ).toJson(),
      );
    });
    SharedPreferences.setMockInitialValues({'diagnostic_history': persisted});

    await tester.pumpWidget(const TestApp(home: DiagnosticPage()));
    await tester.pump();

    expect(find.text('故障诊断'), findsOneWidget);
    expect(find.text('故障 1'), findsOneWidget);
    expect(find.text('故障 2'), findsOneWidget);
    expect(find.text('故障 3'), findsOneWidget);
  });

  testWidgets('diagnostic page shows empty state without records', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TestApp(home: DiagnosticPage()));
    await tester.pump();

    expect(find.text('暂无诊断记录'), findsOneWidget);
  });
}
