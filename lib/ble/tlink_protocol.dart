import 'dart:typed_data';

import 'aes.dart';
import 'hex.dart';
import '../models/command_types.dart';

const _tlinkTokenPlaintext = '850000002EC97FA3518DBFE04A6F5B12';

Uint8List buildTLinkTokenRequest(String keyHex) {
  return aesEcbEncrypt(keyHex, _tlinkTokenPlaintext);
}

Uint8List buildTLinkLoginFrame({
  required String keyHex,
  required int password,
  required int userId,
  required String token,
}) {
  final frame = '850A4A11${_uint32Hex(password)}${_uint32Hex(userId)}$token';
  return aesEcbEncrypt(keyHex, frame);
}

Uint8List buildTLinkCommand({
  required String keyHex,
  required CommandCode command,
  required String token,
}) {
  final header = switch (command) {
    CommandCode.lock => '85034A20',
    CommandCode.unlock => '85034A21',
    CommandCode.powerOn => '85034A22',
    CommandCode.powerOff => '85034A23',
    CommandCode.openSeat => '85034A24',
    CommandCode.find => '85034A25',
    _ => throw ArgumentError('Unsupported TLink command: ${command.name}'),
  };
  // Official writeData fills the command to one 16-byte block before adding
  // the 4-byte token: `85034Axx00 123456789ABCDE` + token.
  return aesEcbEncrypt(
    keyHex,
    '$header'
    '00123456789ABCDE$token',
  );
}

sealed class TLinkResponse {
  final String raw;
  const TLinkResponse(this.raw);
}

class TLinkTokenResponse extends TLinkResponse {
  final String token;
  const TLinkTokenResponse(super.raw, this.token);
}

class TLinkLoginResponse extends TLinkResponse {
  final bool success;
  const TLinkLoginResponse(super.raw, this.success);
}

class TLinkCommandResponse extends TLinkResponse {
  final String commandType;
  final String statusCode;
  final bool success;
  const TLinkCommandResponse(
    super.raw, {
    required this.commandType,
    required this.statusCode,
    required this.success,
  });
}

class TLinkUnknownResponse extends TLinkResponse {
  const TLinkUnknownResponse(super.raw);
}

TLinkResponse parseTLinkResponse(String keyHex, Uint8List encrypted) {
  try {
    final hex = aesEcbDecrypt(keyHex, encrypted);
    if (hex.startsWith('85000000') && hex.length >= 16) {
      return TLinkTokenResponse(hex, hex.substring(8, 16));
    }
    if (hex.startsWith('8503B511') && hex.length >= 10) {
      return TLinkLoginResponse(hex, hex.substring(8, 10) == '01');
    }
    if (hex.startsWith('8503B5') && hex.length >= 10) {
      final commandType = hex.substring(6, 8);
      final statusCode = hex.substring(8, 10);
      return TLinkCommandResponse(
        hex,
        commandType: commandType,
        statusCode: statusCode,
        success: statusCode == '01',
      );
    }
    return TLinkUnknownResponse(hex);
  } on FormatException {
    return TLinkUnknownResponse(bytesToHex(encrypted));
  } on RangeError {
    return TLinkUnknownResponse(bytesToHex(encrypted));
  } on ArgumentError {
    return TLinkUnknownResponse(bytesToHex(encrypted));
  }
}

String _uint32Hex(int value) =>
    (value & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase();
