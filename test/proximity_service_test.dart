import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/services/proximity_service.dart';

void main() {
  setUp(() {
    ProximityService().resetForTest();
    SharedPreferences.setMockInitialValues({});
  });

  test('ProximityService coalesces init and loads persisted switch', () async {
    SharedPreferences.setMockInitialValues({'proximity_unlock_enabled': true});
    ProximityService().resetForTest();

    final service = ProximityService();
    await Future.wait([
      service.init(ConnectionManager()),
      service.init(ConnectionManager()),
    ]);

    expect(service.enabled, isTrue);
  });

  test('ProximityService ignores blank target device ids', () async {
    final service = ProximityService();
    await service.init(ConnectionManager());

    service.setTargetDevice('   ');

    expect(service.targetDeviceId, isNull);
  });
}
