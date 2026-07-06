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

  test('DiagnosticRecord parses object history entries with fallbacks', () {
    final record = DiagnosticRecord.tryParse('{}');

    expect(record, isNotNull);
    expect(record!.rawByte, 0);
    expect(record.faults, isEmpty);
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

  test('DiagnosticRecord parseHistory returns growable display history', () {
    final records = DiagnosticRecord.parseHistory([
      jsonEncode({'time': '2026-06-09T10:30:00.000', 'raw': 1}),
    ]);

    records.insert(
      0,
      DiagnosticRecord(
        time: DateTime(2026, 6, 9, 10, 31),
        rawByte: 2,
        faults: const [],
      ),
    );

    expect(records.map((record) => record.rawByte), [2, 1]);
  });

  test('DiagnosticRecord encodes history in persisted order with limit', () {
    final records = List.generate(
      22,
      (index) => DiagnosticRecord(
        time: DateTime(2026, 6, 9, 10, index),
        rawByte: index,
        faults: ['故障 $index'],
      ),
    );

    final encoded = DiagnosticRecord.encodeHistory(records);
    final decoded = encoded
        .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
        .toList();

    expect(encoded, hasLength(DiagnosticRecord.persistedHistoryLimit));
    expect(decoded.first['raw'], 21);
    expect(decoded.last['raw'], 2);
  });

  test('DiagnosticRecord falls back for partially malformed fields', () {
    final record = DiagnosticRecord.fromJson({
      'time': 'bad-time',
      'raw': 'bad-raw',
      'faults': [1, '电机故障'],
    }, fallbackNow: DateTime(2026, 6, 9, 10, 30));

    expect(record.time, DateTime(2026, 6, 9, 10, 30));
    expect(record.rawByte, 0);
    expect(record.faults, ['电机故障']);
  });

  test('DiagnosticRecord uses injected clock for malformed timestamps', () {
    final generatedAt = DateTime(2026, 6, 9, 10, 30);

    final record = DiagnosticRecord.fromJson({
      'time': 'bad-time',
    }, clock: () => generatedAt);

    expect(record.time, generatedAt);
  });

  test('DiagnosticRecord parseHistory passes injected clock to records', () {
    final generatedAt = DateTime(2026, 6, 9, 10, 30);

    final records = DiagnosticRecord.parseHistory([
      jsonEncode({'time': 'bad-time', 'raw': 1}),
    ], clock: () => generatedAt);

    expect(records.single.time, generatedAt);
  });
}
