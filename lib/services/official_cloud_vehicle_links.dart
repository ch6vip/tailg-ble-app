part of 'official_cloud_service.dart';

class OfficialCloudVehicleLinks {
  const OfficialCloudVehicleLinks._();

  static Map<String, String> normalize(Map<String, String> links) {
    final next = <String, String>{};
    for (final entry in links.entries) {
      final officialKey = entry.key.trim();
      final localId = entry.value.trim();
      if (officialKey.isEmpty || localId.isEmpty) continue;
      next[officialKey] = localId;
    }
    return next;
  }

  /// Link policy (P1-5):
  /// - One official key → one local device id.
  /// - If [localVehicleId] was linked to another official key, that mapping is
  ///   replaced (switch car wins; prevents A-local controlling B-official).
  /// - Empty localId unlinks the official key.
  static Map<String, String> link(
    Map<String, String> links, {
    required String officialVehicleKey,
    required String localVehicleId,
  }) {
    final key = officialVehicleKey.trim();
    final localId = localVehicleId.trim();
    final next = normalize(links);
    if (key.isEmpty) return next;
    if (localId.isEmpty) return next..remove(key);
    // Drop any other official keys pointing at the same local id.
    next.removeWhere((officialKey, linkedLocalId) {
      return officialKey != key && linkedLocalId == localId;
    });
    next[key] = localId;
    return next;
  }

  static Map<String, String> unlink(
    Map<String, String> links,
    String officialVehicleKey,
  ) {
    return normalize(links)..remove(officialVehicleKey.trim());
  }

  static Map<String, String> prune(
    Map<String, String> links,
    Set<String> validLocalVehicleIds,
  ) {
    final validIds = validLocalVehicleIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final next = <String, String>{};
    for (final entry in normalize(links).entries) {
      final officialKey = entry.key;
      final localId = entry.value;
      if (!validIds.contains(localId)) continue;
      next[officialKey] = localId;
    }
    return next;
  }

  static bool isLinkedTo(
    Map<String, String> links, {
    required String officialVehicleKey,
    required String localVehicleId,
  }) {
    final key = officialVehicleKey.trim();
    final localId = localVehicleId.trim();
    if (key.isEmpty || localId.isEmpty) return false;
    return normalize(links)[key] == localId;
  }
}
