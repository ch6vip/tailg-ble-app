import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/official_vehicle.dart';

/// Local read/hidden state for official cloud messages, shared by the message
/// center and the mine-page bell badge.
class MessageReadStore {
  MessageReadStore();

  static const prefReadIds = 'vehicle_message_read_ids';
  static const prefHiddenIds = 'vehicle_message_hidden_ids';

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  final Set<String> _readIds = {};
  final Set<String> _hiddenIds = {};
  var _loaded = false;

  Set<String> get readIds => Set.unmodifiable(_readIds);
  Set<String> get hiddenIds => Set.unmodifiable(_hiddenIds);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _readIds
      ..clear()
      ..addAll(prefs.getStringList(prefReadIds) ?? const []);
    _hiddenIds
      ..clear()
      ..addAll(prefs.getStringList(prefHiddenIds) ?? const []);
    _loaded = true;
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(prefReadIds, _sortedIds(_readIds));
    await prefs.setStringList(prefHiddenIds, _sortedIds(_hiddenIds));
  }

  List<String> _sortedIds(Set<String> ids) {
    final values = ids.toList(growable: false);
    values.sort();
    return values;
  }

  Future<void> replaceState({
    required Set<String> readIds,
    required Set<String> hiddenIds,
  }) async {
    await ensureLoaded();
    _readIds
      ..clear()
      ..addAll(readIds);
    _hiddenIds
      ..clear()
      ..addAll(hiddenIds);
    await persist();
  }

  Future<void> markRead(Iterable<String> ids) async {
    await ensureLoaded();
    final before = _readIds.length;
    _readIds.addAll(ids);
    if (_readIds.length != before) {
      await persist();
    }
  }

  Future<void> hideAndRead(Iterable<String> ids) async {
    await ensureLoaded();
    _hiddenIds.addAll(ids);
    _readIds.addAll(ids);
    await persist();
  }

  /// Recompute badge from the latest cloud message lists.
  Future<void> syncFromCloudMessages({
    required List<OfficialCloudMessage> vehicleMessages,
    required List<OfficialCloudMessage> systemMessages,
  }) async {
    await ensureLoaded();
    final visibleIds = <String>{
      for (final message in vehicleMessages)
        if (!_hiddenIds.contains(message.id)) message.id,
      for (final message in systemMessages)
        if (!_hiddenIds.contains(message.id)) message.id,
    };
    final next = visibleIds.where((id) => !_readIds.contains(id)).length;
    if (unreadCount.value != next) {
      unreadCount.value = next;
    }
  }

  /// Force badge to zero without wiping read history (used when lists empty).
  void setUnreadCount(int count) {
    final next = count < 0 ? 0 : count;
    if (unreadCount.value != next) {
      unreadCount.value = next;
    }
  }

  /// Test / locator reset helper.
  void resetForTest() {
    _readIds.clear();
    _hiddenIds.clear();
    unreadCount.value = 0;
    _loaded = false;
  }
}
