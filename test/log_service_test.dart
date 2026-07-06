import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/log_service.dart';

void main() {
  final log = LogService();

  setUp(log.resetForTest);
  tearDown(log.resetForTest);

  test('redacts sensitive values from messages and details', () {
    log.operation(
      'sync phone=18886120851 imei=860123456789377 token=abcdef123456',
      detail:
          '{"phone":"18886120851","imei":"860123456789377","token":"abcdef123456","authorization":"raw-secret-token"} Bearer bearer-secret-token',
    );

    final entry = log.all.single;

    expect(entry.message, contains('phone=188***851'));
    expect(entry.message, contains('imei=860***377'));
    expect(entry.message, contains('token=abc***456'));
    expect(entry.message, isNot(contains('18886120851')));
    expect(entry.message, isNot(contains('860123456789377')));
    expect(entry.message, isNot(contains('abcdef123456')));

    expect(entry.detail, contains('"phone":"188***851"'));
    expect(entry.detail, contains('"imei":"860***377"'));
    expect(entry.detail, contains('"token":"abc***456"'));
    expect(entry.detail, contains('"authorization":"raw***ken"'));
    expect(entry.detail, contains('Bearer bea***ken'));
    expect(entry.detail, isNot(contains('18886120851')));
    expect(entry.detail, isNot(contains('860123456789377')));
    expect(entry.detail, isNot(contains('abcdef123456')));
    expect(entry.detail, isNot(contains('raw-secret-token')));
    expect(entry.detail, isNot(contains('bearer-secret-token')));
  });

  test('keeps QGJ login frame details fully redacted', () {
    log.ble('QGJ 登录', detail: '01 02 03 04');

    final entry = log.all.single;

    expect(entry.detail, '<redacted login frame, 4 bytes>');
  });

  test('keeps log categories and default levels while redacting', () {
    log.ble('ble phone=18886120851');
    log.operation('operation token=abcdef123456');

    final bleEntry = log.byCategory(LogCategory.ble).single;
    final operationEntry = log.byCategory(LogCategory.operation).single;

    expect(bleEntry.level, LogLevel.debug);
    expect(bleEntry.message, 'ble phone=188***851');
    expect(operationEntry.level, LogLevel.info);
    expect(operationEntry.message, 'operation token=abc***456');
  });

  test('uses provided log entry time', () {
    final time = DateTime(2026, 6, 9, 10, 30);

    log.operation('timestamped', time: time);

    expect(log.all.single.time, time);
  });

  test('uses injected default log entry time', () {
    final time = DateTime(2026, 6, 9, 10, 45);
    log.resetForTest(clock: () => time);

    log.operation('timestamped');

    expect(log.all.single.time, time);
  });

  test('keeps the latest 2000 log entries', () {
    for (var i = 0; i < 2001; i++) {
      log.operation('entry $i');
    }

    final entries = log.all;

    expect(entries, hasLength(2000));
    expect(log.evictedCount, 1);
    expect(entries.first.message, 'entry 1');
    expect(entries.last.message, 'entry 2000');
  });
}
