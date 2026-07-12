import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
}
