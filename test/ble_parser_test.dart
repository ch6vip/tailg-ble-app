import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/aes.dart';
import 'package:tailg_ble_app/ble/parser.dart';

void main() {
  const key = '00112233445566778899aabbccddeeff';
  Uint8List encrypted(String plaintextHex) => aesEcbEncrypt(key, plaintextHex);

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

  test('valid token frame extracts token from decrypted boundary bytes', () {
    final r = parseResponse(key, encrypted('78000000AABBCCDD1111111111111111'));

    expect(r, isA<TokenResponse>());
    expect((r as TokenResponse).token, 'AABBCCDD');
    expect(r.raw, '78000000AABBCCDD1111111111111111');
  });

  test('valid command frame extracts command type and status', () {
    final r = parseResponse(key, encrypted('7803C2010011111111111111AABBCCDD'));

    expect(r, isA<CommandResponse>());
    final command = r as CommandResponse;
    expect(command.commandType, '01');
    expect(command.statusCode, '00');
    expect(command.success, isTrue);
  });

  test('state response parses failed and powered-on states', () {
    final failed = parseResponse(
      key,
      encrypted('7803C20CFF11111111111111AABBCCDD'),
    );
    final poweredOn = parseResponse(
      key,
      encrypted('7803C20C0311111111111111AABBCCDD'),
    );

    expect(failed, isA<StateResponse>());
    expect((failed as StateResponse).success, isFalse);

    expect(poweredOn, isA<StateResponse>());
    final state = poweredOn as StateResponse;
    expect(state.success, isTrue);
    expect(state.bikeState?.isPowerOn, isTrue);
    expect(state.bikeState?.isLocked, isFalse);
  });

  test('decrypted frame with non-0x78 boundary returns UnknownResponse', () {
    final r = parseResponse(key, encrypted('7903C2010011111111111111AABBCCDD'));

    expect(r, isA<UnknownResponse>());
    expect(r.raw, '7903C2010011111111111111AABBCCDD');
  });
}
