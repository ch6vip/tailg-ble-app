import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/parser.dart';

void main() {
  const key = '00112233445566778899aabbccddeeff';

  // Regression: a malformed/garbled BLE notification must never throw out of
  // parseResponse (it is called from an unguarded stream listener). It used to
  // throw ArgumentError ("Input buffer too short") and crash the app.
  test(
    'non block-aligned frame returns UnknownResponse instead of throwing',
    () {
      final r = parseResponse(key, Uint8List.fromList([1, 2, 3]));
      expect(r, isA<UnknownResponse>());
    },
  );

  test('empty frame returns UnknownResponse', () {
    final r = parseResponse(key, Uint8List(0));
    expect(r, isA<UnknownResponse>());
  });

  test('16-byte garbage frame does not throw', () {
    final r = parseResponse(
      key,
      Uint8List.fromList(List<int>.generate(16, (i) => i * 7 & 0xFF)),
    );
    expect(r, isA<ParsedResponse>());
  });
}
