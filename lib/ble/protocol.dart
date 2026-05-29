import 'dart:typed_data';
import 'aes.dart';
import 'constants.dart';

const _tokenRequestPlaintext = '780000002D1A683D48271A18316E471A';

Uint8List buildTokenRequest(String keyHex) {
  return aesEcbEncrypt(keyHex, _tokenRequestPlaintext);
}

Uint8List buildCommand(String keyHex, CommandCode cmd, String token) {
  final frame = '7803C2${cmd.code}0011111111111111$token';
  return aesEcbEncrypt(keyHex, frame);
}

Uint8List buildCommandWithParam(
  String keyHex,
  CommandCode cmd,
  String param,
  String token,
) {
  final frame = '7803C2${cmd.code}${param}11111111111111$token';
  return aesEcbEncrypt(keyHex, frame);
}

Uint8List buildCommand3Params(
  String keyHex,
  CommandCode cmd,
  String p1,
  String p2,
  String p3,
  String token,
) {
  final frame = '7805C2${cmd.code}$p1$p2${p3}1111111111$token';
  return aesEcbEncrypt(keyHex, frame);
}
