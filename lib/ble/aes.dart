import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'hex.dart';

Uint8List aesEcbEncrypt(String keyHex, String dataHex) {
  if (keyHex.length != 32) {
    throw ArgumentError(
      'AES key hex must be 32 characters (16 bytes), got ${keyHex.length}',
    );
  }
  if (dataHex.isEmpty) {
    throw ArgumentError('Data hex must not be empty');
  }
  if (dataHex.length % 32 != 0) {
    throw ArgumentError(
      'Data hex length must be a multiple of 32 (16-byte blocks), got ${dataHex.length}',
    );
  }
  final key = Key(hexToBytes(keyHex));
  final encrypter = Encrypter(AES(key, mode: AESMode.ecb, padding: null));
  final encrypted = encrypter.encryptBytes(hexToBytes(dataHex));
  return Uint8List.fromList(encrypted.bytes);
}

String aesEcbDecrypt(String keyHex, Uint8List data) {
  if (keyHex.length != 32) {
    throw ArgumentError(
      'AES key hex must be 32 characters (16 bytes), got ${keyHex.length}',
    );
  }
  if (data.isEmpty) {
    throw ArgumentError('Data must not be empty');
  }
  if (data.length % 16 != 0) {
    throw ArgumentError(
      'Data length must be a multiple of 16 bytes, got ${data.length}',
    );
  }
  final key = Key(hexToBytes(keyHex));
  final encrypter = Encrypter(AES(key, mode: AESMode.ecb, padding: null));
  final decrypted = encrypter.decryptBytes(Encrypted(data));
  return bytesToHex(Uint8List.fromList(decrypted));
}
