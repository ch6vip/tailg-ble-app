import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/services/replica_feature_store.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

void main() {
  setUp(() {
    VehicleStore().resetForTest();
    SharedPreferences.setMockInitialValues({});
  });

  test('VehicleStore saves default vehicle and renames it', () async {
    final store = VehicleStore();
    await store.init();

    final vehicle = await store.upsert(
      id: 'AA:BB:CC:DD:EE:FF',
      name: '测试车辆',
      protocol: VehicleProtocol.qgj,
      makeDefault: true,
      lastConnectedAt: DateTime(2026, 5, 28, 10, 30),
    );

    expect(vehicle.id, 'AA:BB:CC:DD:EE:FF');
    expect(store.defaultVehicle?.displayName, '测试车辆');
    expect(store.defaultVehicle?.protocol, VehicleProtocol.qgj);

    await store.rename(vehicle.id, '通勤车');

    expect(store.defaultVehicle?.displayName, '通勤车');

    await store.updateLastLocation(
      vehicle.id,
      VehicleLocation(
        latitude: 31.2304,
        longitude: 121.4737,
        accuracy: 12,
        recordedAt: DateTime(2026, 5, 28, 10, 35),
      ),
    );

    expect(
      store.defaultVehicle?.lastLocation?.coordinateText,
      '31.230400, 121.473700',
    );

    await store.updateQgjCredentials(
      id: vehicle.id,
      password: 123456,
      userId: 789,
    );

    expect(store.defaultVehicle?.qgjLoginPassword, 123456);
    expect(store.defaultVehicle?.qgjUserId, 789);

    await store.updateQgjCredentials(id: vehicle.id, clear: true);

    expect(store.defaultVehicle?.hasQgjCredentials, isFalse);
  });

  test('VehicleStore can reload a different mock preferences state', () async {
    final firstStore = VehicleStore();
    await firstStore.init();
    await firstStore.upsert(
      id: 'AA:BB:CC:DD:EE:FF',
      name: '第一辆车',
      makeDefault: true,
    );

    SharedPreferences.setMockInitialValues({
      'vehicle_profiles':
          '[{"id":"11:22:33:44:55:66","name":"第二辆车","protocol":"standard"}]',
      'vehicle_default_id': '11:22:33:44:55:66',
    });
    VehicleStore().resetForTest();

    final reloadedStore = VehicleStore();
    await reloadedStore.init();

    expect(reloadedStore.vehicles, hasLength(1));
    expect(reloadedStore.defaultVehicle?.id, '11:22:33:44:55:66');
    expect(reloadedStore.defaultVehicle?.displayName, '第二辆车');
    expect(reloadedStore.defaultVehicle?.protocol, VehicleProtocol.standard);
  });

  test('ReplicaFeatureStore saves quick control config', () async {
    final store = ReplicaFeatureStore();

    final defaults = await store.loadQuickControlConfig();
    expect(defaults.firstActionId, 'soundEffects');
    expect(defaults.secondActionId, 'seat');

    await store.saveQuickControlConfig(
      const QuickControlConfig(firstActionId: 'fence', secondActionId: 'find'),
    );

    final saved = await store.loadQuickControlConfig();
    expect(saved.firstActionId, 'fence');
    expect(saved.secondActionId, 'find');
  });
}
