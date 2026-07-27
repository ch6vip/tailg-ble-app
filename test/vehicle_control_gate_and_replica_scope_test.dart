import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/widgets/vehicle_control_gate.dart';

import 'helpers/source_scan.dart';

void main() {
  group('VehicleControlHomeGate (P1-1)', () {
    test('resolves signed out / no vehicle / loading / error / near field', () {
      expect(
        VehicleControlHomeGate.resolve(
          signedIn: false,
          hasVehicle: false,
          loading: false,
          showNearFieldHint: false,
        ),
        VehicleControlHomeGateKind.signedOut,
      );
      expect(
        VehicleControlHomeGate.resolve(
          signedIn: true,
          hasVehicle: false,
          loading: true,
          showNearFieldHint: false,
        ),
        VehicleControlHomeGateKind.loading,
      );
      expect(
        VehicleControlHomeGate.resolve(
          signedIn: true,
          hasVehicle: false,
          loading: false,
          error: '网络错误',
          showNearFieldHint: false,
        ),
        VehicleControlHomeGateKind.error,
      );
      expect(
        VehicleControlHomeGate.resolve(
          signedIn: true,
          hasVehicle: false,
          loading: false,
          showNearFieldHint: false,
        ),
        VehicleControlHomeGateKind.noVehicle,
      );
      expect(
        VehicleControlHomeGate.resolve(
          signedIn: true,
          hasVehicle: true,
          loading: false,
          showNearFieldHint: true,
        ),
        VehicleControlHomeGateKind.nearField,
      );
      expect(
        VehicleControlHomeGate.resolve(
          signedIn: true,
          hasVehicle: true,
          loading: false,
          showNearFieldHint: false,
        ),
        VehicleControlHomeGateKind.none,
      );
    });
  });

  group('replica pages demote local-only features (P2)', () {
    test('NFC / fence / share pages declare non-official local demos', () {
      final source = readSource('lib/pages/official_replica_pages.dart');
      // P3-6: NFC now writes official BLE frames on LOGIN; when not LOGIN it
      // must still make clear it only keeps a local list and does not write.
      expect(source, contains('未 standard LOGIN：仅本地列表（不会写车）'));
      expect(source, contains('本地草稿围栏'));
      expect(source, contains('非官方云围栏'));
      expect(source, contains('本地演示 · 非官方家庭共享'));
      expect(source, contains('已保存为本地草稿（未同步官方围栏）'));
    });

    test('service hub omits unavailable after-sales entry', () {
      final source = readSource('lib/pages/service_hub_page.dart');
      expect(source, isNot(contains('售后服务')));
      expect(source, isNot(contains('outOfReplicaScope')));
      expect(source, contains('故障诊断'));
      expect(source, contains('官方账号'));
    });
  });

  group('near-field permission UI (P0/P1)', () {
    test('爱车 header BLE entry keeps permission flow without a banner', () {
      final source = readSource('lib/pages/cyber_vehicle_control_page_v2.dart');
      expect(source, isNot(contains('需要蓝牙和定位权限才能本地控车')));
      expect(source, isNot(contains('车辆在附近时可连接蓝牙本地控车')));
      expect(source, contains("actionLabel: '去设置'"));
      expect(source, contains('permissionService.openSystemSettings()'));
      expect(source, contains('连接车辆蓝牙'));
      expect(source, contains('_manualNearFieldConnect'));
      expect(source, contains('本地控车需授权蓝牙'));
      expect(source, contains('_controlDisabledMessage'));
    });

    test('scan page surfaces settings action on permanent deny', () {
      final source = readSource('lib/pages/scan_page.dart');
      expect(source, contains("actionLabel: '去设置'"));
      expect(source, contains('openSystemSettings'));
    });
  });
}
