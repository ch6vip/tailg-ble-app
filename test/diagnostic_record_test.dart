import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/pages/diagnostic_page.dart';

void main() {
  test('DiagnosticRecord parses valid records and ignores corrupt history', () {
    final valid = jsonEncode({
      'time': '2026-06-09T10:30:00.000',
      'raw': 33,
      'faults': ['欠压保护'],
    });

    final record = DiagnosticRecord.tryParse(valid);

    expect(record, isNotNull);
    expect(record!.rawByte, 33);
    expect(record.faults, ['欠压保护']);
    expect(DiagnosticRecord.tryParse('not-json'), isNull);
  });

  test('DiagnosticRecord ignores non-object decoded history entries', () {
    expect(DiagnosticRecord.tryParse('42'), isNull);
    expect(DiagnosticRecord.tryParse('["bad-entry"]'), isNull);
  });

  test('DiagnosticRecord parses history in display order', () {
    final records = DiagnosticRecord.parseHistory([
      jsonEncode({
        'time': '2026-06-09T10:30:00.000',
        'raw': 1,
        'faults': ['电机故障'],
      }),
      'not-json',
      jsonEncode({
        'time': '2026-06-09T10:31:00.000',
        'raw': 2,
        'faults': ['转把故障'],
      }),
    ]);

    expect(records.map((record) => record.rawByte), [2, 1]);
    expect(records.first.faults, ['转把故障']);
  });

  test('DiagnosticRecord falls back for partially malformed fields', () {
    final record = DiagnosticRecord.fromJson({
      'time': 'bad-time',
      'raw': 'bad-raw',
      'faults': [1, '电机故障'],
    });

    expect(record.rawByte, 0);
    expect(record.faults, ['电机故障']);
  });
}
