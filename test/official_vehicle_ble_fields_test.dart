import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/official_ble_connection_context.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';

void main() {
  group('OfficialVehicle BLE identity / password parsing', () {
    test('fills btmac from mac when only mac is present', () {
      final v = OfficialVehicle.fromJson({
        'carId': 'c1',
        'modelType': 8,
        'mac': 'AABBCCDDEEFF',
      });
      expect(v.btmac, 'AABBCCDDEEFF');
      expect(v.bleIdentityMac, 'AABBCCDDEEFF');
      expect(v.raw['mac'], 'AABBCCDDEEFF');
      expect(v.raw['btmac'], 'AABBCCDDEEFF');
    });

    test('fills mac from btmac when only btmac is present', () {
      final v = OfficialVehicle.fromJson({
        'carId': 'c1',
        'modelType': 3,
        'btmac': '11:22:33:44:55:66',
      });
      expect(v.btmac, '11:22:33:44:55:66');
      expect(v.bleIdentityMac, '112233445566');
      expect(v.raw['mac'], '11:22:33:44:55:66');
    });

    test('reads passwordInfo.main and children', () {
      final v = OfficialVehicle.fromJson({
        'carId': 'c1',
        'modelType': 8,
        'mac': 'AABBCCDDEEFF',
        'passwordInfo': {
          'main': 123456,
          'children': [111, 222],
        },
      });
      expect(v.mainBlePassword, 123456);
      expect(v.childBlePasswords, [111, 222]);
    });

    test('reads alternate password key shapes', () {
      final v = OfficialVehicle.fromJson({
        'carId': 'c1',
        'modelType': 8,
        'btMac': 'AABBCCDDEEFF',
        'pwdInfo': {'mainPassword': 654321, 'children': <int>[]},
      });
      expect(v.btmac, 'AABBCCDDEEFF');
      expect(v.mainBlePassword, 654321);
      final ctx = OfficialBleConnectionContext.fromVehicle(v, userId: '42');
      expect(ctx.stack, OfficialBleStack.qgj);
      expect(ctx.targetMacCompact, 'AABBCCDDEEFF');
      expect(ctx.hasQgjCredentials, isTrue);
    });
  });
}
