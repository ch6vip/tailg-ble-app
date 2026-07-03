import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/log_service.dart';

void main() {
  final log = LogService();

  setUp(log.clear);
  tearDown(log.clear);

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
}
