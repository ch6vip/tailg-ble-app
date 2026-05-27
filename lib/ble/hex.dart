import 'dart:typed_data';

Uint8List hexToBytes(String hex) {
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return bytes;
}

String bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
}

String intToHex2(int n) {
  return (n & 0xff).toRadixString(16).padLeft(2, '0').toUpperCase();
}
