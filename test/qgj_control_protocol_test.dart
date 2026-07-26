import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/constants.dart';
import 'package:tailg_ble_app/ble/qgj_protocol.dart';

void main() {
  test('QGJ seat support follows official ECU key versions', () {
    QgjResponse response(int version, {bool success = true}) => QgjResponse(
      cmdId: QgjCommandIds.keyVersionGet,
      payload: Uint8List.fromList([version]),
      success: success,
    );

    for (final version in [2, 6, 9]) {
      expect(parseQgjSeatSupport(response(version)), isTrue);
    }
    expect(parseQgjSeatSupport(response(1)), isFalse);
    expect(parseQgjSeatSupport(response(2, success: false)), isNull);
    expect(parseQgjSeatSupport(null), isNull);
  });

  test('QGJ key-version query uses official 0x1005 command id', () {
    expect(
      buildQgjCommand(QgjCommandIds.keyVersionGet),
      Uint8List.fromList([0xA7, 0x00, 0x00, 0x02, 0x10, 0x05]),
    );
  });
}
