import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/aes.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/ble/constants.dart';
import 'package:tailg_ble_app/ble/tlink_protocol.dart';

void main() {
  const key = '1AF78CD35BE92F4CA06DB89EC2D7EF01';
  const token = 'A1B2C3D4';

  test('TLink token request and login frame match official plaintext', () {
    expect(
      aesEcbDecrypt(key, buildTLinkTokenRequest(key)),
      '850000002EC97FA3518DBFE04A6F5B12',
    );
    expect(
      aesEcbDecrypt(
        key,
        buildTLinkLoginFrame(
          keyHex: key,
          password: 1234,
          userId: 42,
          token: token,
        ),
      ),
      '850A4A11000004D20000002AA1B2C3D4',
    );
  });

  test('TLink six-key frame includes official filler and token', () {
    expect(
      aesEcbDecrypt(
        key,
        buildTLinkCommand(keyHex: key, command: CommandCode.lock, token: token),
      ),
      '85034A2000123456789ABCDEA1B2C3D4',
    );
    expect(
      aesEcbDecrypt(
        key,
        buildTLinkCommand(
          keyHex: key,
          command: CommandCode.openSeat,
          token: token,
        ),
      ),
      '85034A2400123456789ABCDEA1B2C3D4',
    );
  });

  test('TLink parser separates token, login ACK and command ACK', () {
    TLinkResponse parse(String plaintext) =>
        parseTLinkResponse(key, aesEcbEncrypt(key, plaintext));

    final tokenResponse = parse('85000000A1B2C3D40000000000000000');
    expect(tokenResponse, isA<TLinkTokenResponse>());
    expect((tokenResponse as TLinkTokenResponse).token, token);

    final login = parse('8503B511010000000000000000000000');
    expect(login, isA<TLinkLoginResponse>());
    expect((login as TLinkLoginResponse).success, isTrue);

    final command = parse('8503B522010000000000000000000000');
    expect(command, isA<TLinkCommandResponse>());
    expect((command as TLinkCommandResponse).commandType, '22');
    expect(command.success, isTrue);
  });

  test('receiving a TLink token alone never marks official LOGIN', () {
    final manager = ConnectionManager();
    addTearDown(manager.dispose);

    manager.acceptTLinkTokenForTest(token);
    expect(manager.token, token);
    expect(manager.state, ConnectionState.connected);
    expect(manager.isProtocolLoggedIn, isFalse);

    expect(manager.acceptTLinkLoginForTest(true), isTrue);
    expect(manager.state, ConnectionState.ready);
    expect(manager.isProtocolLoggedIn, isTrue);
  });

  test('malformed encrypted payload is safe', () {
    expect(
      parseTLinkResponse(key, Uint8List.fromList([1, 2, 3])),
      isA<TLinkUnknownResponse>(),
    );
  });
}
