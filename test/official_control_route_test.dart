import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/official_control_route.dart';

void main() {
  group('OfficialControlRoute (ControlFragment lock/start table)', () {
    test('modelType 1 KKS: BLE when ready else cloud', () {
      final ble = OfficialControlRoute.resolve(
        bindingCar: true,
        modelType: 1,
        isGps: 0,
        bleReady: true,
        cloudSessionReady: true,
      );
      final cloud = OfficialControlRoute.resolve(
        bindingCar: true,
        modelType: 1,
        isGps: 0,
        bleReady: false,
        cloudSessionReady: true,
      );

      expect(ble.usesBle, isTrue);
      expect(ble.bleStack, OfficialBleStackKind.standard);
      expect(cloud.usesCloud, isTrue);
    });

    test('modelType 2 YJ: cloud only', () {
      final withBle = OfficialControlRoute.resolve(
        bindingCar: true,
        modelType: 2,
        isGps: 1,
        bleReady: true,
        cloudSessionReady: true,
      );
      final noSession = OfficialControlRoute.resolve(
        bindingCar: true,
        modelType: 2,
        isGps: 1,
        bleReady: true,
        cloudSessionReady: false,
      );

      expect(withBle.usesCloud, isTrue);
      expect(withBle.bleStack, OfficialBleStackKind.none);
      expect(noSession.isUnavailable, isTrue);
    });

    test('modelType 8 QGJ: isGps==1 and not LOGIN → cloud; else BLE required', () {
      final remote = OfficialControlRoute.resolve(
        bindingCar: true,
        modelType: 8,
        isGps: 1,
        bleReady: false,
        cloudSessionReady: true,
      );
      final local = OfficialControlRoute.resolve(
        bindingCar: true,
        modelType: 8,
        isGps: 1,
        bleReady: true,
        cloudSessionReady: true,
      );
      final noGpsNeedsBle = OfficialControlRoute.resolve(
        bindingCar: true,
        modelType: 8,
        isGps: 0,
        bleReady: false,
        cloudSessionReady: true,
      );

      expect(remote.usesCloud, isTrue);
      expect(remote.bleStack, OfficialBleStackKind.qgj);
      expect(local.usesBle, isTrue);
      expect(local.bleStack, OfficialBleStackKind.qgj);
      expect(noGpsNeedsBle.isUnavailable, isTrue);
      expect(noGpsNeedsBle.reason, '蓝牙未连接');
    });

    test('modelType 10 C39 uses standard stack with isGps gate', () {
      final remote = OfficialControlRoute.resolve(
        bindingCar: true,
        modelType: 10,
        isGps: 1,
        bleReady: false,
        cloudSessionReady: true,
      );
      final local = OfficialControlRoute.resolve(
        bindingCar: true,
        modelType: 14,
        isGps: 0,
        bleReady: true,
        cloudSessionReady: true,
      );

      expect(remote.usesCloud, isTrue);
      expect(remote.bleStack, OfficialBleStackKind.standard);
      expect(local.usesBle, isTrue);
    });

    test('modelType 401 GPS combo: no isGps gate, BLE first else cloud', () {
      final local = OfficialControlRoute.resolve(
        bindingCar: true,
        modelType: 401,
        isGps: 0,
        bleReady: true,
        cloudSessionReady: true,
      );
      final remote = OfficialControlRoute.resolve(
        bindingCar: true,
        modelType: 928,
        isGps: 0,
        bleReady: false,
        cloudSessionReady: true,
      );

      expect(local.usesBle, isTrue);
      expect(remote.usesCloud, isTrue);
    });

    test('modelType 3 BB: isGps hybrid + standard BLE', () {
      final remote = OfficialControlRoute.resolve(
        bindingCar: true,
        modelType: 3,
        isGps: 1,
        bleReady: false,
        cloudSessionReady: true,
      );
      final needBle = OfficialControlRoute.resolve(
        bindingCar: true,
        modelType: 3,
        isGps: 0,
        bleReady: false,
        cloudSessionReady: true,
      );

      expect(remote.usesCloud, isTrue);
      expect(needBle.isUnavailable, isTrue);
      expect(needBle.reason, '蓝牙未连接');
    });

    test('unbound vehicle is unavailable', () {
      final d = OfficialControlRoute.resolve(
        bindingCar: false,
        modelType: 8,
        isGps: 1,
        bleReady: true,
        cloudSessionReady: true,
      );
      expect(d.isUnavailable, isTrue);
      expect(d.reason, '未绑定车辆');
    });
  });
}
