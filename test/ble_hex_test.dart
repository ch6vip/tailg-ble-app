import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/hex.dart';

void main() {
  test('intToHex2 renders uppercase two digit byte text', () {
    expect(intToHex2(0), '00');
    expect(intToHex2(10), '0A');
    expect(intToHex2(255), 'FF');
  });

  test('intToHex2 masks values to one byte', () {
    expect(intToHex2(0x123), '23');
    expect(intToHex2(-1), 'FF');
  });
}
