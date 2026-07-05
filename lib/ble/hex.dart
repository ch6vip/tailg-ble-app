import 'dart:typed_data';

final RegExp _hexPattern = RegExp(r'^[0-9a-fA-F]*$');

Uint8List hexToBytes(String hex) {
  if (hex.isEmpty) return Uint8List(0);
  if (hex.length % 2 != 0) {
    throw ArgumentError('Hex string must have even length, got ${hex.length}');
  }
  if (!_hexPattern.hasMatch(hex)) {
    throw ArgumentError('Hex string contains invalid characters: $hex');
  }
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return bytes;
}

String bytesToHex(Uint8List bytes) {
  return bytes.map(intToHex2).join();
}

String bytesToSpacedHex(Iterable<int> bytes) {
  return bytes.map(intToHex2Lower).join(' ');
}

String intToHex4Lower(int n) {
  return n.toRadixString(16).padLeft(4, '0');
}

String intToHex2Lower(int n) {
  return (n & 0xff).toRadixString(16).padLeft(2, '0');
}

String intToHex2(int n) {
  return (n & 0xff).toRadixString(16).padLeft(2, '0').toUpperCase();
}
