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

  test('VehicleStore tolerates corrupt persisted vehicle data', () async {
    SharedPreferences.setMockInitialValues({
      'vehicle_profiles': 'not-json',
      'vehicle_default_id': 'missing',
    });
    VehicleStore().resetForTest();

    final store = VehicleStore();
    await store.init();

    expect(store.vehicles, isEmpty);
    expect(store.defaultVehicle, isNull);
    expect(store.defaultVehicleId, isNull);
  });

  test(
    'VehicleStore skips malformed entries and normalizes default id',
    () async {
      SharedPreferences.setMockInitialValues({
        'vehicle_profiles':
            '[{"id":"","name":"空 ID"},'
            '{"id":"AA:BB:CC:DD:EE:FF","name":"有效车辆","protocol":"qgj"},'
            '42]',
        'vehicle_default_id': 'missing',
      });
      VehicleStore().resetForTest();

      final store = VehicleStore();
      await Future.wait([store.init(), store.init()]);

      expect(store.vehicles, hasLength(1));
      expect(store.defaultVehicle?.id, 'AA:BB:CC:DD:EE:FF');
      expect(store.defaultVehicle?.displayName, '有效车辆');
      expect(store.defaultVehicle?.protocol, VehicleProtocol.qgj);
      expect(store.defaultVehicleId, 'AA:BB:CC:DD:EE:FF');
    },
  );

  test('VehicleStore keeps recoverable profiles with malformed fields', () async {
    SharedPreferences.setMockInitialValues({
      'vehicle_profiles':
          '[{"id":"AA:BB:CC:DD:EE:FF",'
          '"name":123,'
          '"protocol":456,'
          '"createdAt":789,'
          '"updatedAt":"bad-date",'
          '"lastConnectedAt":"2026-06-09T10:30:00.000",'
          '"qgjLoginPassword":"123456",'
          '"qgjUserId":"789",'
          '"lastLocation":{"latitude":"31.2304","longitude":"121.4737","accuracy":"12"}}]',
      'vehicle_default_id': 'AA:BB:CC:DD:EE:FF',
    });
    VehicleStore().resetForTest();

    final store = VehicleStore();
    await store.init();

    expect(store.vehicles, hasLength(1));
    expect(store.defaultVehicle?.displayName, '123');
    expect(store.defaultVehicle?.protocol, VehicleProtocol.auto);
    expect(store.defaultVehicle?.lastConnectedAt, DateTime(2026, 6, 9, 10, 30));
    expect(
      store.defaultVehicle?.lastLocation?.coordinateText,
      '31.230400, 121.473700',
    );
    expect(store.defaultVehicle?.lastLocation?.accuracy, 12);
    expect(store.defaultVehicle?.qgjLoginPassword, 123456);
    expect(store.defaultVehicle?.qgjUserId, 789);
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

  test('ReplicaFeatureStore tolerates corrupt persisted config', () async {
    SharedPreferences.setMockInitialValues({
      'replica_nfc_keys': 'not-json',
      'replica_fence_config': '[',
      'replica_share_members': '{"not":"a-list"}',
      'replica_quick_control_config': 'bad',
      'replica_quick_shortcuts_config': '42',
      'replica_main_control_config': 'null',
    });

    final store = ReplicaFeatureStore();

    expect(await store.loadNfcKeys(), isEmpty);
    expect(await store.loadFenceConfig(), isNull);
    expect(await store.loadShareMembers(), isEmpty);
    expect(
      await store.loadQuickControlConfig(),
      isA<QuickControlConfig>()
          .having(
            (config) => config.firstActionId,
            'firstActionId',
            'soundEffects',
          )
          .having((config) => config.secondActionId, 'secondActionId', 'seat'),
    );
    expect(await store.loadQuickShortcutsConfig(), isA<QuickShortcutsConfig>());
    expect(await store.loadMainControlConfig(), isA<MainControlConfig>());
  });
}
