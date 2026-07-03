import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/services/log_service.dart';
import 'package:tailg_ble_app/services/replica_feature_store.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

void main() {
  setUp(() {
    VehicleStore().resetForTest();
    LogService().clear();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() {
    LogService().clear();
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
    final prefs = await SharedPreferences.getInstance();
    final secureStorage = const FlutterSecureStorage();
    final persistedVehicles = prefs.getString('vehicle_profiles') ?? '';

    expect(store.defaultVehicle?.qgjLoginPassword, 123456);
    expect(store.defaultVehicle?.qgjUserId, 789);
    expect(persistedVehicles.contains('qgjLoginPassword'), isFalse);
    expect(persistedVehicles.contains('qgjUserId'), isFalse);
    expect(
      await secureStorage.read(key: 'vehicle_qgj_password:${vehicle.id}'),
      '123456',
    );
    expect(
      await secureStorage.read(key: 'vehicle_qgj_user_id:${vehicle.id}'),
      '789',
    );

    await store.updateQgjCredentials(id: vehicle.id, clear: true);

    expect(store.defaultVehicle?.hasQgjCredentials, isFalse);
    expect(
      await secureStorage.read(key: 'vehicle_qgj_password:${vehicle.id}'),
      isNull,
    );
    expect(
      await secureStorage.read(key: 'vehicle_qgj_user_id:${vehicle.id}'),
      isNull,
    );
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
    final warnings = LogService().all
        .where(
          (entry) =>
              entry.message == 'VehicleStore' &&
              entry.level == LogLevel.warning,
        )
        .toList();
    expect(warnings, hasLength(1));
    expect(
      warnings.single.detail,
      contains('Failed to decode persisted vehicle profiles'),
    );
  });

  test('VehicleStore logs non-list persisted vehicle payloads', () async {
    SharedPreferences.setMockInitialValues({
      'vehicle_profiles': '{"id":"AA:BB:CC:DD:EE:FF"}',
      'vehicle_default_id': 'AA:BB:CC:DD:EE:FF',
    });
    VehicleStore().resetForTest();

    final store = VehicleStore();
    await store.init();

    expect(store.vehicles, isEmpty);
    expect(store.defaultVehicleId, isNull);
    final warning = LogService().all.singleWhere(
      (entry) =>
          entry.message == 'VehicleStore' && entry.level == LogLevel.warning,
    );
    expect(
      warning.detail,
      contains('Expected persisted vehicle profiles to be a list'),
    );
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
      final warningDetails = LogService().all
          .where(
            (entry) =>
                entry.message == 'VehicleStore' &&
                entry.level == LogLevel.warning,
          )
          .map((entry) => entry.detail)
          .toList();
      expect(
        warningDetails,
        containsAll(<String>[
          'Skipped vehicle profile with blank id',
          'Skipped vehicle profile entry with type int',
        ]),
      );
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

  test(
    'VehicleStore migrates legacy QGJ credentials to secure storage and scrubs prefs',
    () async {
      SharedPreferences.setMockInitialValues({
        'vehicle_profiles':
            '[{"id":"AA:BB:CC:DD:EE:FF","name":"有效车辆","protocol":"qgj","qgjLoginPassword":"123456","qgjUserId":"789"}]',
        'vehicle_default_id': 'AA:BB:CC:DD:EE:FF',
      });
      FlutterSecureStorage.setMockInitialValues({});
      VehicleStore().resetForTest();

      final store = VehicleStore();
      await store.init();

      final prefs = await SharedPreferences.getInstance();
      final secureStorage = const FlutterSecureStorage();
      final persistedVehicles = prefs.getString('vehicle_profiles') ?? '';

      expect(store.defaultVehicle?.qgjLoginPassword, 123456);
      expect(store.defaultVehicle?.qgjUserId, 789);
      expect(persistedVehicles.contains('qgjLoginPassword'), isFalse);
      expect(persistedVehicles.contains('qgjUserId'), isFalse);
      expect(
        await secureStorage.read(key: 'vehicle_qgj_password:AA:BB:CC:DD:EE:FF'),
        '123456',
      );
      expect(
        await secureStorage.read(key: 'vehicle_qgj_user_id:AA:BB:CC:DD:EE:FF'),
        '789',
      );
    },
  );

  test('VehicleStore normalizes ids at write and lookup boundaries', () async {
    final store = VehicleStore();
    await store.init();

    final created = await store.upsert(
      id: '  AA:BB:CC:DD:EE:FF  ',
      name: '测试车辆',
      makeDefault: true,
    );
    final updated = await store.upsert(
      id: 'AA:BB:CC:DD:EE:FF',
      name: '更新车辆',
      protocol: VehicleProtocol.qgj,
    );

    expect(created.id, 'AA:BB:CC:DD:EE:FF');
    expect(updated.id, 'AA:BB:CC:DD:EE:FF');
    expect(store.vehicles, hasLength(1));
    expect(store.defaultVehicleId, 'AA:BB:CC:DD:EE:FF');
    expect(store.defaultVehicle?.displayName, '更新车辆');
    expect(store.defaultVehicle?.protocol, VehicleProtocol.qgj);

    await store.rename('  AA:BB:CC:DD:EE:FF  ', '重命名车辆');
    await store.setDefault(' AA:BB:CC:DD:EE:FF ');

    expect(store.defaultVehicle?.displayName, '重命名车辆');

    await store.remove(' AA:BB:CC:DD:EE:FF ');

    expect(store.vehicles, isEmpty);
    expect(store.defaultVehicleId, isNull);
  });

  test('VehicleStore remove clears secure QGJ credentials', () async {
    final store = VehicleStore();
    const secureStorage = FlutterSecureStorage();
    await store.init();
    await store.upsert(id: 'AA:BB:CC:DD:EE:FF', name: '测试车辆');
    await store.updateQgjCredentials(
      id: 'AA:BB:CC:DD:EE:FF',
      password: 123456,
      userId: 789,
    );

    await store.remove('AA:BB:CC:DD:EE:FF');

    expect(
      await secureStorage.read(key: 'vehicle_qgj_password:AA:BB:CC:DD:EE:FF'),
      isNull,
    );
    expect(
      await secureStorage.read(key: 'vehicle_qgj_user_id:AA:BB:CC:DD:EE:FF'),
      isNull,
    );
  });

  test(
    'VehicleStore rejects blank ids instead of persisting invalid profiles',
    () async {
      final store = VehicleStore();
      await store.init();

      await expectLater(
        store.upsert(id: '   ', name: '空白车辆'),
        throwsArgumentError,
      );

      expect(store.vehicles, isEmpty);
      expect(store.defaultVehicleId, isNull);
    },
  );

  test('VehicleStore normalizes persisted default id whitespace', () async {
    SharedPreferences.setMockInitialValues({
      'vehicle_profiles':
          '[{"id":"AA:BB:CC:DD:EE:FF","name":"有效车辆","protocol":"qgj"}]',
      'vehicle_default_id': '  AA:BB:CC:DD:EE:FF  ',
    });
    VehicleStore().resetForTest();

    final store = VehicleStore();
    await store.init();

    expect(store.defaultVehicleId, 'AA:BB:CC:DD:EE:FF');
    expect(store.defaultVehicle?.displayName, '有效车辆');
  });

  test('ReplicaFeatureStore tolerates corrupt persisted config', () async {
    SharedPreferences.setMockInitialValues({
      'replica_nfc_keys': 'not-json',
      'replica_fence_config': '[',
      'replica_share_members': '{"not":"a-list"}',
    });

    final store = ReplicaFeatureStore();

    expect(await store.loadNfcKeys(), isEmpty);
    expect(await store.loadFenceConfig(), isNull);
    expect(await store.loadShareMembers(), isEmpty);
  });

  test('ReplicaFeatureStore keeps recoverable malformed records', () async {
    SharedPreferences.setMockInitialValues({
      'replica_nfc_keys':
          '[{"id":123,"name":456,"type":789,"createdAt":"bad-date"}]',
      'replica_share_members':
          '[{"id":123,"name":456,"phone":18800001111,"createdAt":"bad-date"}]',
      'replica_fence_config':
          '{"enabled":"true","latitude":"31.2304","longitude":"121.4737","radiusMeters":"800","updatedAt":"bad-date"}',
      'replica_quick_control_config':
          '{"firstActionId":123,"secondActionId":""}',
    });

    final store = ReplicaFeatureStore();

    final nfcKeys = await store.loadNfcKeys();
    expect(nfcKeys, hasLength(1));
    expect(nfcKeys.first.id, '123');
    expect(nfcKeys.first.name, '456');
    expect(nfcKeys.first.type, '789');

    final members = await store.loadShareMembers();
    expect(members, hasLength(1));
    expect(members.first.id, '123');
    expect(members.first.name, '456');
    expect(members.first.phone, '18800001111');

    final fence = await store.loadFenceConfig();
    expect(fence, isNotNull);
    expect(fence!.enabled, isTrue);
    expect(fence.latitude, 31.2304);
    expect(fence.longitude, 121.4737);
    expect(fence.radiusMeters, 800);
  });
}
