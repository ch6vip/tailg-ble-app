part of 'official_cloud_service.dart';

class OfficialCloudVehicleLinks {
  const OfficialCloudVehicleLinks._();

  static Map<String, String> link(
    Map<String, String> links, {
    required String officialVehicleKey,
    required String localVehicleId,
  }) {
    final key = officialVehicleKey.trim();
    final localId = localVehicleId.trim();
    final next = Map<String, String>.from(links);
    if (key.isEmpty) return next;
    if (localId.isEmpty) return next..remove(key);
    return next..[key] = localId;
  }

  static Map<String, String> unlink(
    Map<String, String> links,
    String officialVehicleKey,
  ) {
    return Map<String, String>.from(links)..remove(officialVehicleKey.trim());
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
    for (final entry in links.entries) {
      final officialKey = entry.key.trim();
      final localId = entry.value.trim();
      if (officialKey.isEmpty || localId.isEmpty) continue;
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
    return links[key]?.trim() == localId;
  }
}
