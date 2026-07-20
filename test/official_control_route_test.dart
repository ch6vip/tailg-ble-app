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

    test(
      'modelType 8 QGJ: isGps==1 and not LOGIN → cloud; else BLE required',
      () {
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
        final pureBleNoLogin = OfficialControlRoute.resolve(
          bindingCar: true,
          modelType: 8,
          isGps: 0,
          bleReady: false,
          cloudSessionReady: true,
        );

        expect(remote.usesCloud, isTrue);
        expect(remote.bleStack, OfficialBleStackKind.qgj);
        expect(local.usesBle, isTrue);
        expect(pureBleNoLogin.isUnavailable, isTrue);
        expect(pureBleNoLogin.reason, '蓝牙未连接');
      },
    );

    test(
      'modelType 10/14 C39 follow isGps hybrid gate with standard stack',
      () {
        for (final type in OfficialControlRoute.c39ModelTypes) {
          final remote = OfficialControlRoute.resolve(
            bindingCar: true,
            modelType: type,
            isGps: 1,
            bleReady: false,
            cloudSessionReady: true,
          );
          final local = OfficialControlRoute.resolve(
            bindingCar: true,
            modelType: type,
            isGps: 0,
            bleReady: true,
            cloudSessionReady: true,
          );
          expect(remote.usesCloud, isTrue, reason: 'type $type remote');
          expect(remote.bleStack, OfficialBleStackKind.standard);
          expect(local.usesBle, isTrue, reason: 'type $type local');
        }
      },
    );

    test('gpsCombo modelTypes fall back to cloud without isGps gate', () {
      for (final type in OfficialControlRoute.gpsComboModelTypes) {
        final ble = OfficialControlRoute.resolve(
          bindingCar: true,
          modelType: type,
          isGps: 0,
          bleReady: true,
          cloudSessionReady: true,
        );
        final cloud = OfficialControlRoute.resolve(
          bindingCar: true,
          modelType: type,
          isGps: 0,
          bleReady: false,
          cloudSessionReady: true,
        );
        expect(ble.usesBle, isTrue, reason: 'type $type BLE');
        expect(cloud.usesCloud, isTrue, reason: 'type $type cloud');
      }
    });

    test('official no-op and unknown model types are unavailable', () {
      for (final type in {
        ...OfficialControlRoute.unsupportedControlModelTypes,
        9999,
      }) {
        final decision = OfficialControlRoute.resolve(
          bindingCar: true,
          modelType: type,
          isGps: 1,
          bleReady: true,
          cloudSessionReady: true,
        );
        expect(decision.isUnavailable, isTrue, reason: 'type $type');
      }
    });

    test('unbound vehicle is unavailable', () {
      final decision = OfficialControlRoute.resolve(
        bindingCar: false,
        modelType: 1,
        isGps: 1,
        bleReady: true,
        cloudSessionReady: true,
      );
      expect(decision.isUnavailable, isTrue);
      expect(decision.reason, '未绑定车辆');
    });

    test('network / session gates for cloud path', () {
      final noNet = OfficialControlRoute.resolve(
        bindingCar: true,
        modelType: 1,
        isGps: 0,
        bleReady: false,
        networkReady: false,
        cloudSessionReady: true,
      );
      final noSession = OfficialControlRoute.resolve(
        bindingCar: true,
        modelType: 1,
        isGps: 0,
        bleReady: false,
        networkReady: true,
        cloudSessionReady: false,
      );
      expect(noNet.isUnavailable, isTrue);
      expect(noNet.reason, '手机网络未连接');
      expect(noSession.isUnavailable, isTrue);
      expect(noSession.reason, contains('登录'));
    });

    // P0-C2 table-driven matrix: modelType × bleReady × network × session
    test('table-driven branches cover ControlFragment families', () {
      final cases = <_RouteCase>[
        // KKS
        _RouteCase(1, 0, true, true, true, expectsBle: true),
        _RouteCase(1, 0, false, true, true, expectsCloud: true),
        _RouteCase(1, 0, false, false, true, expectsUnavailable: true),
        // YJ cloud only
        _RouteCase(2, 1, true, true, true, expectsCloud: true),
        _RouteCase(2, 0, false, true, false, expectsUnavailable: true),
        // QGJ hybrid
        _RouteCase(8, 1, false, true, true, expectsCloud: true),
        _RouteCase(
          283,
          1,
          true,
          true,
          true,
          expectsBle: true,
          stack: OfficialBleStackKind.qgj,
        ),
        _RouteCase(8, 0, false, true, true, expectsUnavailable: true),
        // C39
        _RouteCase(10, 1, false, true, true, expectsCloud: true),
        _RouteCase(14, 0, true, true, true, expectsBle: true),
        // GPS combo
        _RouteCase(401, 0, false, true, true, expectsCloud: true),
        _RouteCase(928, 0, true, true, true, expectsBle: true),
        _RouteCase(2103, 1, false, true, true, expectsCloud: true),
        _RouteCase(2201, 0, true, false, true, expectsBle: true),
        // default/BB hybrid
        _RouteCase(3, 1, false, true, true, expectsCloud: true),
        _RouteCase(3, 0, true, true, true, expectsBle: true),
        _RouteCase(3, 0, false, true, true, expectsUnavailable: true),
        // no-op control family
        _RouteCase(1501, 0, false, true, true, expectsUnavailable: true),
      ];

      for (final c in cases) {
        final d = OfficialControlRoute.resolve(
          bindingCar: true,
          modelType: c.modelType,
          isGps: c.isGps,
          bleReady: c.bleReady,
          networkReady: c.networkReady,
          cloudSessionReady: c.cloudSessionReady,
        );
        if (c.expectsBle) {
          expect(d.usesBle, isTrue, reason: c.describe);
          if (c.stack != null) expect(d.bleStack, c.stack, reason: c.describe);
        } else if (c.expectsCloud) {
          expect(d.usesCloud, isTrue, reason: c.describe);
        } else if (c.expectsUnavailable) {
          expect(d.isUnavailable, isTrue, reason: c.describe);
        }
      }
    });
  });
}

class _RouteCase {
  final int modelType;
  final int isGps;
  final bool bleReady;
  final bool networkReady;
  final bool cloudSessionReady;
  final bool expectsBle;
  final bool expectsCloud;
  final bool expectsUnavailable;
  final OfficialBleStackKind? stack;

  const _RouteCase(
    this.modelType,
    this.isGps,
    this.bleReady,
    this.networkReady,
    this.cloudSessionReady, {
    this.expectsBle = false,
    this.expectsCloud = false,
    this.expectsUnavailable = false,
    this.stack,
  });

  String get describe =>
      'type=$modelType isGps=$isGps ble=$bleReady net=$networkReady session=$cloudSessionReady';
}
