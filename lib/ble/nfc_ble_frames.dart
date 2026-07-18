import 'dart:typed_data';

import 'hex.dart';

/// Official NFC/key frames from `TailgBleConfig` (standard stack writeData path).
abstract final class OfficialNfcBleFrames {
  static const headerAddUserKey = '85094A4105';
  static const headerAddUserKeyBle = '85064A4109';
  static const headerNfcAddMode = '85054A320202';
  static const headerNfcCheck = '85044A3201';
  static const headerNfcDel = '85054A320502';
  static const headerNfcFacSet = '85054A320412';
  static const cushionSetBody = '000000000000'; // TailgBleUtils.HEADER_SEND_CUSHION_SET_BODY fallback

  /// Phone/card key add (keyType 1 = phone, 2 = BLE key).
  static String addUserKeyHex({required int keyType, required String type}) {
    if (keyType == 1) {
      final tail = type == '1' ? '010103842000DE' : '000103842000DE';
      return '$headerAddUserKey$tail';
    }
    final tail = type == '1' ? '011003789ABCDE' : '001003789ABCDE';
    return '$headerAddUserKeyBle$tail';
  }

  static String checkNfcHex(String index) =>
      '$headerNfcCheck$index' '3456789ABCDE';

  static String delNfcHex(String index) =>
      '$headerNfcDel$index$cushionSetBody';

  static String addCardHex(String index) =>
      '$headerNfcAddMode$index$cushionSetBody';

  static Uint8List toBytes(String hex) => hexToBytes(hex);
}
