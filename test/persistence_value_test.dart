import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/persistence_value.dart';

void main() {
  test('parsePersistedString trims stored values and falls back to empty', () {
    expect(parsePersistedString(null), '');
    expect(parsePersistedString('  bike  '), 'bike');
    expect(parsePersistedString(123), '123');
  });

  test('parsePersistedStringOr uses fallback for blank values', () {
    expect(parsePersistedStringOr(null, 'fallback'), 'fallback');
    expect(parsePersistedStringOr('', 'fallback'), 'fallback');
    expect(parsePersistedStringOr('   ', 'fallback'), 'fallback');
    expect(parsePersistedStringOr('  bike  ', 'fallback'), 'bike');
    expect(parsePersistedStringOr(123, 'fallback'), '123');
  });

  test('parsePersistedStringList keeps only string list entries', () {
    expect(parsePersistedStringList(null), isEmpty);
    expect(parsePersistedStringList('not-list'), isEmpty);
    expect(parsePersistedStringList(['欠压保护', 1, null, '电机故障']), [
      '欠压保护',
      '电机故障',
    ]);
  });

  test('parsePersistedStringList returns a detached list', () {
    final source = ['欠压保护'];
    final parsed = parsePersistedStringList(source);

    source.add('电机故障');

    expect(parsed, ['欠压保护']);
  });

  test('parsePersistedMap copies map payloads and ignores non-maps', () {
    final source = <Object?, Object?>{'latitude': '31.2304'};

    final parsed = parsePersistedMap(source);
    source['latitude'] = '0';

    expect(parsed, {'latitude': '31.2304'});
    expect(parsePersistedMap(null), isNull);
    expect(parsePersistedMap(42), isNull);
  });

  test('parsePersistedMap rejects non-string map keys', () {
    expect(
      () => parsePersistedMap(<Object?, Object?>{1: 'value'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('parsePersistedMapList copies map entries and ignores non-maps', () {
    final sourceMap = <Object?, Object?>{'latitude': '31.2304'};
    final parsed = parsePersistedMapList([
      sourceMap,
      'ignored',
      {'longitude': '121.4737'},
    ]);
    sourceMap['latitude'] = '0';

    expect(parsed, [
      {'latitude': '31.2304'},
      {'longitude': '121.4737'},
    ]);
    expect(() => parsed.add({'ignored': true}), throwsUnsupportedError);
    expect(parsePersistedMapList(null), isEmpty);
    expect(parsePersistedMapList({'latitude': '31.2304'}), isEmpty);
  });

  test('parsePersistedDouble preserves previous numeric parsing', () {
    expect(parsePersistedDouble(12), 12.0);
    expect(parsePersistedDouble(12.5), 12.5);
    expect(parsePersistedDouble(' 31.2304 '), 31.2304);
    expect(parsePersistedDouble('bad'), isNull);
  });

  test('parsePersistedInt preserves previous integer parsing', () {
    expect(parsePersistedInt(12), 12);
    expect(parsePersistedInt(12.9), 12);
    expect(parsePersistedInt(' 123456 '), 123456);
    expect(parsePersistedInt('12.9'), isNull);
    expect(parsePersistedInt('bad'), isNull);
  });

  test('parsePersistedBool preserves truthy persisted values', () {
    expect(parsePersistedBool(true), isTrue);
    expect(parsePersistedBool(1), isTrue);
    expect(parsePersistedBool(-1), isTrue);
    expect(parsePersistedBool(' true '), isTrue);
    expect(parsePersistedBool('YES'), isTrue);
    expect(parsePersistedBool('1'), isTrue);
  });

  test('parsePersistedBool falls back to false for falsey values', () {
    expect(parsePersistedBool(false), isFalse);
    expect(parsePersistedBool(0), isFalse);
    expect(parsePersistedBool('false'), isFalse);
    expect(parsePersistedBool('no'), isFalse);
    expect(parsePersistedBool('bad'), isFalse);
    expect(parsePersistedBool(null), isFalse);
  });

  test('parsePersistedDate preserves previous persistence date parsing', () {
    expect(parsePersistedDate(null), isNull);
    expect(parsePersistedDate('bad-date'), isNull);
    expect(
      parsePersistedDate('2026-06-09T10:30:00.000'),
      DateTime(2026, 6, 9, 10, 30),
    );
    expect(parsePersistedDate(789), isNull);
  });

  test('parsePersistedDateOr uses parsed dates before fallback values', () {
    final fallback = DateTime(2026, 6, 9, 10, 30);

    expect(
      parsePersistedDateOr('2026-06-09T11:30:00.000', fallback),
      DateTime(2026, 6, 9, 11, 30),
    );
    expect(parsePersistedDateOr('bad-date', fallback), fallback);
  });

  test('parsePersistedDateOr uses injected clock for final fallback', () {
    final generatedAt = DateTime(2026, 6, 9, 10, 30);

    expect(
      parsePersistedDateOr('bad-date', null, clock: () => generatedAt),
      generatedAt,
    );
  });
}
