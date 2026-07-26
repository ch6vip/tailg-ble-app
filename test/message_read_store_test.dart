import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/services/message_read_store.dart';

import 'helpers/storage_mocks.dart';

void main() {
  setUp(resetMockPreferences);

  test('persists read and hidden message ids in stable order', () async {
    final store = MessageReadStore();

    await store.replaceState(
      readIds: {'message-z', 'message-a'},
      hiddenIds: {'message-y', 'message-b'},
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(MessageReadStore.prefReadIds), [
      'message-a',
      'message-z',
    ]);
    expect(prefs.getStringList(MessageReadStore.prefHiddenIds), [
      'message-b',
      'message-y',
    ]);
  });

  test('restores persisted state through immutable views', () async {
    SharedPreferences.setMockInitialValues({
      MessageReadStore.prefReadIds: ['message-read'],
      MessageReadStore.prefHiddenIds: ['message-hidden'],
    });
    final store = MessageReadStore();

    await store.ensureLoaded();

    expect(store.readIds, {'message-read'});
    expect(store.hiddenIds, {'message-hidden'});
    expect(() => store.readIds.add('message-new'), throwsUnsupportedError);
    expect(() => store.hiddenIds.clear(), throwsUnsupportedError);
  });

  test('markRead and hideAndRead persist their combined state', () async {
    final store = MessageReadStore();

    await store.markRead(['message-read', 'message-read']);
    await store.hideAndRead(['message-hidden']);

    expect(store.readIds, {'message-read', 'message-hidden'});
    expect(store.hiddenIds, {'message-hidden'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(MessageReadStore.prefReadIds), [
      'message-hidden',
      'message-read',
    ]);
    expect(prefs.getStringList(MessageReadStore.prefHiddenIds), [
      'message-hidden',
    ]);
  });

  test('syncFromCloudMessages counts only visible unread ids', () async {
    final store = MessageReadStore();
    await store.markRead(['vehicle:read']);
    await store.hideAndRead(['vehicle:hidden']);

    await store.syncFromCloudMessages(
      vehicleMessages: [
        _vehicleMessage('read'),
        _vehicleMessage('hidden'),
        _vehicleMessage('unread'),
      ],
      systemMessages: [_systemMessage('system-unread')],
    );

    expect(store.unreadCount.value, 2);
  });

  test(
    'setUnreadCount clamps negative values and reset clears state',
    () async {
      final store = MessageReadStore();
      await store.replaceState(
        readIds: {'message-read'},
        hiddenIds: {'message-hidden'},
      );

      store.setUnreadCount(3);
      expect(store.unreadCount.value, 3);
      store.setUnreadCount(-1);
      expect(store.unreadCount.value, 0);

      store.resetForTest();
      expect(store.readIds, isEmpty);
      expect(store.hiddenIds, isEmpty);
      expect(store.unreadCount.value, 0);
    },
  );
}

OfficialCloudMessage _vehicleMessage(String id) {
  return OfficialCloudMessage.vehicle({'msgId': id});
}

OfficialCloudMessage _systemMessage(String id) {
  return OfficialCloudMessage.system({'sysMessageRecordId': id});
}
