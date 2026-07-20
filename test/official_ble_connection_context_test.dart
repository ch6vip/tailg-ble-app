import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/constants.dart';
import 'package:tailg_ble_app/ble/official_ble_connection_context.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';

void main() {
  test('official modelType selects the same BLE stack and AES family', () {
    expect(
      OfficialBleConnectionContext.stackForModelType(1),
      OfficialBleStack.kks,
    );
    for (final type in [3, 10, 14, 401, 928, 1501, 1601, 1701, 2103, 2201]) {
      expect(
        OfficialBleConnectionContext.stackForModelType(type),
        OfficialBleStack.tlink,
      );
    }
    for (final type in [8, 283]) {
      expect(
        OfficialBleConnectionContext.stackForModelType(type),
        OfficialBleStack.qgj,
      );
    }

    expect(
      OfficialBleConnectionContext.cipherModelForModelType(3),
      ModelType.BB,
    );
    expect(
      OfficialBleConnectionContext.cipherModelForModelType(401),
      ModelType.BB,
    );
    expect(
      OfficialBleConnectionContext.cipherModelForModelType(10),
      ModelType.JW,
    );
    expect(
      OfficialBleConnectionContext.cipherModelForModelType(928),
      ModelType.JW,
    );
    expect(
      OfficialBleConnectionContext.stackForModelType(9999),
      OfficialBleStack.unsupported,
    );
  });

  test('shared official vehicle uses first child password in memory', () {
    final vehicle = OfficialVehicle.fromJson({
      'modelType': 3,
      'mac': 'AABBCCDDEEFF',
      'btmac': '11:22:33:44:55:66',
      'shareCarFlag': 1,
      'passwordInfo': {
        'main': '1234',
        'children': ['5678', '9012'],
      },
    });

    final context = OfficialBleConnectionContext.fromVehicle(
      vehicle,
      userId: '42',
    );

    expect(vehicle.bleIdentityMac, 'AABBCCDDEEFF');
    expect(context.selectedPassword, 5678);
    expect(context.userIdValue, 42);
    expect(context.hasTLinkCredentials, isTrue);
    expect(vehicle.toJson().containsKey('qgjLoginPassword'), isFalse);
  });

  test('missing uid or shared child password cannot authenticate', () {
    const context = OfficialBleConnectionContext(
      stack: OfficialBleStack.tlink,
      modelType: 3,
      cipherModel: ModelType.BB,
      identityMac: 'AABBCCDDEEFF',
      advertisedName: 'TL_BEUOZB',
      userId: '',
      mainPassword: 1234,
      childPasswords: [],
      shared: true,
    );

    expect(context.selectedPassword, isNull);
    expect(context.hasTLinkCredentials, isFalse);
  });
}
