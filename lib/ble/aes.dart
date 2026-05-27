import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'hex.dart';

Uint8List aesEcbEncrypt(String keyHex, String dataHex) {
  final key = Key(hexToBytes(keyHex));
  final encrypter = Encrypter(AES(key, mode: AESMode.ecb, padding: null));
  final encrypted = encrypter.encryptBytes(hexToBytes(dataHex));
  return Uint8List.fromList(encrypted.bytes);
}

String aesEcbDecrypt(String keyHex, Uint8List data) {
  final key = Key(hexToBytes(keyHex));
  final encrypter = Encrypter(AES(key, mode: AESMode.ecb, padding: null));
  final decrypted = encrypter.decryptBytes(Encrypted(data));
  return bytesToHex(Uint8List.fromList(decrypted));
}
