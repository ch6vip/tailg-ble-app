import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/models/vehicle_profile.dart';
import 'package:tailg_ble_app/services/log_service.dart';
import 'package:tailg_ble_app/services/replica_feature_store.dart';
import 'package:tailg_ble_app/services/vehicle_store.dart';

import 'helpers/storage_mocks.dart';

void main() {
  setUp(() {
    VehicleStore().resetForTest();
    ReplicaFeatureStore().resetForTest();
    LogService().clear();
    resetMockStorage();
  });

  tearDown(() {
    LogService().clear();
  });

  test('VehicleStore saves default vehicle and renames it', () async {
    final store = VehicleStore();
    await store.init();
    final savedAt = DateTime(2026, 5, 28, 10);
    final renamedAt = DateTime(2026, 5, 28, 10, 32);
    final locationUpdatedAt = DateTime(2026, 5, 28, 10, 36);
    final credentialsUpdatedAt = DateTime(2026, 5, 28, 10, 40);
    final credentialsClearedAt = DateTime(2026, 5, 28, 10, 45);

    final vehicle = await store.upsert(
      id: 'AA:BB:CC:DD:EE:FF',
      name: '测试车辆',
      protocol: VehicleProtocol.qgj,
      makeDefault: true,
      lastConnectedAt: DateTime(2026, 5, 28, 10, 30),
      savedAt: savedAt,
    );

    expect(vehicle.id, 'AA:BB:CC:DD:EE:FF');
    expect(store.defaultVehicle?.displayName, '测试车辆');
    expect(store.defaultVehicle?.protocol, VehicleProtocol.qgj);
    expect(store.defaultVehicle?.createdAt, savedAt);
    expect(store.defaultVehicle?.updatedAt, savedAt);

    await store.rename(vehicle.id, '通勤车', savedAt: renamedAt);

    expect(store.defaultVehicle?.displayName, '通勤车');
    expect(store.defaultVehicle?.createdAt, savedAt);
    expect(store.defaultVehicle?.updatedAt, renamedAt);

    await store.updateLastLocation(
      vehicle.id,
      VehicleLocation(
        latitude: 31.2304,
        longitude: 121.4737,
        accuracy: 12,
        recordedAt: DateTime(2026, 5, 28, 10, 35),
      ),
      savedAt: locationUpdatedAt,
    );

    expect(
      store.defaultVehicle?.lastLocation?.coordinateText,
      '31.230400, 121.473700',
    );
    expect(store.defaultVehicle?.createdAt, savedAt);
    expect(store.defaultVehicle?.updatedAt, locationUpdatedAt);

    await store.updateQgjCredentials(
      id: vehicle.id,
      password: 123456,
      userId: 789,
      savedAt: credentialsUpdatedAt,
    );
    final prefs = await SharedPreferences.getInstance();
    final secureStorage = const FlutterSecureStorage();
    final persistedVehicles = prefs.getString('vehicle_profiles') ?? '';

    expect(store.defaultVehicle?.qgjLoginPassword, 123456);
    expect(store.defaultVehicle?.qgjUserId, 789);
    expect(store.defaultVehicle?.createdAt, savedAt);
    expect(store.defaultVehicle?.updatedAt, credentialsUpdatedAt);
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

    await store.updateQgjCredentials(
      id: vehicle.id,
      clear: true,
      savedAt: credentialsClearedAt,
    );

    expect(store.defaultVehicle?.hasQgjCredentials, isFalse);
    expect(store.defaultVehicle?.createdAt, savedAt);
    expect(store.defaultVehicle?.updatedAt, credentialsClearedAt);
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

  test('VehicleStore resetForTest restores stream after dispose', () async {
    final store = VehicleStore();

    store.dispose();
    store.resetForTest();
    await store.init();

    final event = store.vehiclesStream.first;
    await store.upsert(id: 'AA:BB:CC:DD:EE:FF', name: '测试车辆');

    await expectLater(event, completion(hasLength(1)));
    expect(store.vehicles.single.id, 'AA:BB:CC:DD:EE:FF');
  });

  test('VehicleStore restores persisted vehicle profile maps', () async {
    SharedPreferences.setMockInitialValues({
      'vehicle_profiles':
          '[{"id":"AA:BB:CC:DD:EE:FF","name":"有效车辆","protocol":"qgj"}]',
      'vehicle_default_id': 'AA:BB:CC:DD:EE:FF',
    });
    VehicleStore().resetForTest();

    final store = VehicleStore();
    await store.init();

    expect(store.vehicles, hasLength(1));
    expect(store.defaultVehicle?.id, 'AA:BB:CC:DD:EE:FF');
    expect(store.defaultVehicle?.displayName, '有效车辆');
    expect(store.defaultVehicle?.protocol, VehicleProtocol.qgj);
  });

  test('VehicleStore restores persisted profile location maps', () async {
    SharedPreferences.setMockInitialValues({
      'vehicle_profiles':
          '[{"id":"AA:BB:CC:DD:EE:FF","name":"有效车辆",'
          '"lastLocation":{"latitude":"31.2304","longitude":"121.4737",'
          '"accuracy":"12","recordedAt":"2026-06-09T10:30:00.000"}}]',
      'vehicle_default_id': 'AA:BB:CC:DD:EE:FF',
    });
    VehicleStore().resetForTest();

    final store = VehicleStore();
    await store.init();

    final location = store.defaultVehicle?.lastLocation;
    expect(location?.latitude, 31.2304);
    expect(location?.longitude, 121.4737);
    expect(location?.accuracy, 12);
    expect(location?.recordedAt, DateTime(2026, 6, 9, 10, 30));
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
    'VehicleStore logs decoded null vehicle payloads as shape warnings',
    () async {
      SharedPreferences.setMockInitialValues({
        'vehicle_profiles': 'null',
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
      expect(warning.detail, contains('Null'));
    },
  );

  test(
    'VehicleStore skips malformed entries and normalizes default id',
    () async {
      SharedPreferences.setMockInitialValues({
        'vehicle_profiles':
            '[{"id":"","name":"空 ID"},'
            '{"id":"AA:BB:CC:DD:EE:FF","name":"有效车辆","protocol":"qgj"},'
            '42,'
            'null]',
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
          'Skipped vehicle profile entry with type Null',
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

  test('VehicleStore ignores non-map persisted lastLocation', () async {
    SharedPreferences.setMockInitialValues({
      'vehicle_profiles':
          '[{"id":"AA:BB:CC:DD:EE:FF","name":"有效车辆","lastLocation":42}]',
      'vehicle_default_id': 'AA:BB:CC:DD:EE:FF',
    });
    VehicleStore().resetForTest();

    final store = VehicleStore();
    await store.init();

    expect(store.vehicles, hasLength(1));
    expect(store.defaultVehicle?.lastLocation, isNull);
  });

  test(
    'VehicleStore migrates legacy QGJ credentials to secure storage and scrubs prefs',
    () async {
      SharedPreferences.setMockInitialValues({
        'vehicle_profiles':
            '[{"id":"AA:BB:CC:DD:EE:FF","name":"有效车辆","protocol":"qgj","qgjLoginPassword":"123456","qgjUserId":"789"}]',
        'vehicle_default_id': 'AA:BB:CC:DD:EE:FF',
      });
      resetMockSecureStorage();
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
    final createdAt = DateTime(2026, 6, 10, 10);
    final updatedAt = DateTime(2026, 6, 10, 11);

    final created = await store.upsert(
      id: '  AA:BB:CC:DD:EE:FF  ',
      name: '测试车辆',
      makeDefault: true,
      savedAt: createdAt,
    );
    final updated = await store.upsert(
      id: 'AA:BB:CC:DD:EE:FF',
      name: '更新车辆',
      protocol: VehicleProtocol.qgj,
      savedAt: updatedAt,
    );

    expect(created.id, 'AA:BB:CC:DD:EE:FF');
    expect(created.createdAt, createdAt);
    expect(created.updatedAt, createdAt);
    expect(updated.id, 'AA:BB:CC:DD:EE:FF');
    expect(updated.createdAt, createdAt);
    expect(updated.updatedAt, updatedAt);
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

  test('VehicleStore uses its clock for default write timestamps', () async {
    final timestamps = [
      DateTime(2026, 6, 10, 10),
      DateTime(2026, 6, 10, 11),
      DateTime(2026, 6, 10, 12),
      DateTime(2026, 6, 10, 13),
    ];
    var timestampIndex = 0;
    VehicleStore().resetForTest(clock: () => timestamps[timestampIndex++]);

    final store = VehicleStore();
    await store.init();

    final created = await store.upsert(id: 'AA:BB:CC:DD:EE:FF', name: '测试车辆');

    expect(created.createdAt, timestamps[0]);
    expect(created.updatedAt, timestamps[0]);

    await store.rename(created.id, '通勤车');

    expect(store.defaultVehicle?.createdAt, timestamps[0]);
    expect(store.defaultVehicle?.updatedAt, timestamps[1]);

    await store.updateLastLocation(
      created.id,
      VehicleLocation(
        latitude: 31.2304,
        longitude: 121.4737,
        accuracy: 12,
        recordedAt: DateTime(2026, 6, 10, 12, 30),
      ),
    );

    expect(store.defaultVehicle?.updatedAt, timestamps[2]);

    await store.updateQgjCredentials(
      id: created.id,
      password: 123456,
      userId: 789,
    );

    expect(store.defaultVehicle?.updatedAt, timestamps[3]);
    expect(timestampIndex, timestamps.length);
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

  test('ReplicaFeatureStore restores saved records and config', () async {
    final store = ReplicaFeatureStore();
    final createdAt = DateTime(2026, 6, 9, 10);
    final updatedAt = DateTime(2026, 6, 9, 11);

    await store.saveNfcKeys([
      NfcKeyRecord(id: 'nfc-1', name: '主钥匙', type: '卡片', createdAt: createdAt),
    ]);
    await store.saveShareMembers([
      ShareMemberRecord(
        id: 'share-1',
        name: '家人',
        phone: '18800001111',
        createdAt: createdAt,
      ),
    ]);
    await store.saveFenceConfig(
      FenceConfig(
        enabled: true,
        latitude: 31.2304,
        longitude: 121.4737,
        radiusMeters: 800,
        updatedAt: updatedAt,
      ),
    );

    final nfcKeys = await store.loadNfcKeys();
    final members = await store.loadShareMembers();
    final fence = await store.loadFenceConfig();

    expect(nfcKeys.single.name, '主钥匙');
    expect(nfcKeys.single.createdAt, createdAt);
    expect(members.single.phone, '18800001111');
    expect(members.single.createdAt, createdAt);
    expect(fence?.enabled, isTrue);
    expect(fence?.latitude, 31.2304);
    expect(fence?.longitude, 121.4737);
    expect(fence?.radiusMeters, 800);
    expect(fence?.updatedAt, updatedAt);
  });

  test('Replica feature records use provided fallback timestamps', () {
    final fallbackNow = DateTime(2026, 6, 9, 10, 30);

    final nfcKey = NfcKeyRecord.fromJson({
      'createdAt': 'bad-date',
    }, fallbackNow: fallbackNow);
    final member = ShareMemberRecord.fromJson({
      'createdAt': 'bad-date',
    }, fallbackNow: fallbackNow);
    final fence = FenceConfig.fromJson({
      'updatedAt': 'bad-date',
    }, fallbackNow: fallbackNow);

    expect(nfcKey.createdAt, fallbackNow);
    expect(member.createdAt, fallbackNow);
    expect(fence.updatedAt, fallbackNow);
  });

  test('Replica feature records use injected clock fallback', () {
    final generatedAt = DateTime(2026, 6, 9, 10, 35);

    final nfcKey = NfcKeyRecord.fromJson({
      'createdAt': 'bad-date',
    }, clock: () => generatedAt);
    final member = ShareMemberRecord.fromJson({
      'createdAt': 'bad-date',
    }, clock: () => generatedAt);
    final fence = FenceConfig.fromJson({
      'updatedAt': 'bad-date',
    }, clock: () => generatedAt);

    expect(nfcKey.createdAt, generatedAt);
    expect(member.createdAt, generatedAt);
    expect(fence.updatedAt, generatedAt);
  });

  test('ReplicaFeatureStore makeId uses provided timestamp', () {
    final store = ReplicaFeatureStore();
    final generatedAt = DateTime(2026, 6, 9, 10, 45);
    final prefix = '${generatedAt.microsecondsSinceEpoch}_';

    final first = store.makeId(now: generatedAt);
    final second = store.makeId(now: generatedAt);
    final firstSuffix = int.parse(first.substring(prefix.length));
    final secondSuffix = int.parse(second.substring(prefix.length));

    expect(first, startsWith(prefix));
    expect(second, startsWith(prefix));
    expect(secondSuffix, firstSuffix + 1);
  });

  test('ReplicaFeatureStore creates local records with its clock', () {
    final timestamps = [
      DateTime(2026, 6, 9, 10, 50),
      DateTime(2026, 6, 9, 10, 55),
      DateTime(2026, 6, 9, 11),
    ];
    var timestampIndex = 0;
    final store = ReplicaFeatureStore();
    store.resetForTest(clock: () => timestamps[timestampIndex++]);

    final nfcKey = store.createNfcKey(name: '主钥匙', type: '手机');
    final fence = store.createFenceConfig(
      enabled: true,
      latitude: 31.2304,
      longitude: 121.4737,
      radiusMeters: 800,
    );
    final member = store.createShareMember(name: '家人', phone: '18800001111');

    expect(nfcKey.createdAt, timestamps[0]);
    expect(nfcKey.id, startsWith('${timestamps[0].microsecondsSinceEpoch}_'));
    expect(fence.updatedAt, timestamps[1]);
    expect(member.createdAt, timestamps[2]);
    expect(member.id, startsWith('${timestamps[2].microsecondsSinceEpoch}_'));
    expect(timestampIndex, timestamps.length);
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

    final messages = LogService().all.map((entry) => entry.message).toList();
    expect(
      messages,
      containsAll(<String>[
        'ReplicaFeatureStore: JSON decode failed',
        'ReplicaFeatureStore: decode map failed',
        'ReplicaFeatureStore: expected list payload',
      ]),
    );
  });

  test('ReplicaFeatureStore logs malformed persisted payload shapes', () async {
    SharedPreferences.setMockInitialValues({
      'replica_nfc_keys': '[42]',
      'replica_fence_config': '[]',
      'replica_share_members': '{"not":"a-list"}',
    });

    final store = ReplicaFeatureStore();

    expect(await store.loadNfcKeys(), isEmpty);
    expect(await store.loadFenceConfig(), isNull);
    expect(await store.loadShareMembers(), isEmpty);

    final messages = LogService().all.map((entry) => entry.message).toList();
    expect(
      messages,
      containsAll(<String>[
        'ReplicaFeatureStore: skipped list item with type',
        'ReplicaFeatureStore: expected map payload',
        'ReplicaFeatureStore: expected list payload',
      ]),
    );
  });

  test('ReplicaFeatureStore keeps recoverable malformed records', () async {
    final fallbackNow = DateTime(2026, 6, 9, 10, 30);
    SharedPreferences.setMockInitialValues({
      'replica_nfc_keys':
          '[42,{"id":123,"name":456,"type":789,"createdAt":"bad-date"}]',
      'replica_share_members':
          '[{"id":123,"name":456,"phone":18800001111,"createdAt":"bad-date"}]',
      'replica_fence_config':
          '{"enabled":"true","latitude":"31.2304","longitude":"121.4737","radiusMeters":"800","updatedAt":"bad-date"}',
      'replica_quick_control_config':
          '{"firstActionId":123,"secondActionId":""}',
    });

    final store = ReplicaFeatureStore();
    store.resetForTest(clock: () => fallbackNow);

    final nfcKeys = await store.loadNfcKeys();
    expect(nfcKeys, hasLength(1));
    expect(nfcKeys.first.id, '123');
    expect(nfcKeys.first.name, '456');
    expect(nfcKeys.first.type, '789');
    expect(nfcKeys.first.createdAt, fallbackNow);

    final members = await store.loadShareMembers();
    expect(members, hasLength(1));
    expect(members.first.id, '123');
    expect(members.first.name, '456');
    expect(members.first.phone, '18800001111');
    expect(members.first.createdAt, fallbackNow);

    final fence = await store.loadFenceConfig();
    expect(fence, isNotNull);
    expect(fence!.enabled, isTrue);
    expect(fence.latitude, 31.2304);
    expect(fence.longitude, 121.4737);
    expect(fence.radiusMeters, 800);
    expect(fence.updatedAt, fallbackNow);
    expect(
      LogService().all.map((entry) => entry.message),
      contains('ReplicaFeatureStore: skipped list item with type'),
    );
  });
}
