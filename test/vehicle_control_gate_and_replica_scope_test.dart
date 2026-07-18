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

    test('service hub marks after-sales out of replica scope', () {
      final source = readSource('lib/pages/service_hub_page.dart');
      expect(source, contains('outOfReplicaScope'));
      expect(source, contains('非复刻范围'));
    });
  });
}
