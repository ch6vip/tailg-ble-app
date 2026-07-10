import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/log_service.dart';

void main() {
  final log = LogService();

  setUp(log.resetForTest);
  tearDown(log.resetForTest);

  test('redacts sensitive values from messages and details', () {
    log.operation(
      'sync phone=18886120851 imei=860123456789377 token=abcdef123456 userId=user-secret password=qgj-secret',
      detail:
          '{"phone":"18886120851","imei":"860123456789377","token":"abcdef123456","authorization":"raw-secret-token","frame":"L12345678901234567","mac":"AA:BB:CC:DD:EE:FF"} Bearer bearer-secret-token',
    );

    final entry = log.all.single;

    expect(entry.message, contains('phone=188***851'));
    expect(entry.message, contains('imei=860***377'));
    expect(entry.message, contains('token=abc***456'));
    expect(entry.message, contains('userId=use***ret'));
    expect(entry.message, contains('password=qgj***ret'));
    expect(entry.message, isNot(contains('18886120851')));
    expect(entry.message, isNot(contains('860123456789377')));
    expect(entry.message, isNot(contains('abcdef123456')));
    expect(entry.message, isNot(contains('user-secret')));
    expect(entry.message, isNot(contains('qgj-secret')));

    expect(entry.detail, contains('"phone":"188***851"'));
    expect(entry.detail, contains('"imei":"860***377"'));
    expect(entry.detail, contains('"token":"abc***456"'));
    expect(entry.detail, contains('"authorization":"raw***ken"'));
    expect(entry.detail, contains('"frame":"L12***567"'));
    expect(entry.detail, contains('"mac":"AA:***:FF"'));
    expect(entry.detail, contains('Bearer bea***ken'));
    expect(entry.detail, isNot(contains('18886120851')));
    expect(entry.detail, isNot(contains('860123456789377')));
    expect(entry.detail, isNot(contains('abcdef123456')));
    expect(entry.detail, isNot(contains('raw-secret-token')));
    expect(entry.detail, isNot(contains('L12345678901234567')));
    expect(entry.detail, isNot(contains('AA:BB:CC:DD:EE:FF')));
    expect(entry.detail, isNot(contains('bearer-secret-token')));
  });

  test('keeps QGJ login frame details fully redacted', () {
    log.connection('QGJ 登录', detail: '01 02 03 04');

    final entry = log.all.single;

    expect(entry.detail, '<redacted login frame, 4 bytes>');
  });

  test('keeps log categories and default levels while redacting', () {
    log.connection('connection phone=18886120851');
    log.operation('operation token=abcdef123456');

    final connEntry = log.byCategory(LogCategory.connection).single;
    final operationEntry = log.byCategory(LogCategory.operation).single;

    expect(connEntry.level, LogLevel.debug);
    expect(connEntry.message, 'connection phone=188***851');
    expect(operationEntry.level, LogLevel.info);
    expect(operationEntry.message, 'operation token=abc***456');
  });

  test('returns detached log snapshots', () {
    log.connection('connection entry');
    log.operation('operation entry');

    final allEntries = log.all;
    final operationEntries = log.byCategory(LogCategory.operation);

    allEntries.clear();
    operationEntries.clear();

    expect(log.all, hasLength(2));
    expect(log.byCategory(LogCategory.operation), hasLength(1));
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

  test('resetForTest restores changes stream after dispose', () async {
    log.dispose();
    log.resetForTest();

    final event = log.changes.first;
    log.operation('restored stream');

    await expectLater(event, completes);
    expect(log.all.single.message, 'restored stream');
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
