part of 'official_cloud_service.dart';

class OfficialCloudVehicleLinks {
  const OfficialCloudVehicleLinks._();

  static Map<String, String> link(
    Map<String, String> links, {
    required String officialVehicleKey,
    required String localVehicleId,
  }) {
    return Map<String, String>.from(links)
      ..[officialVehicleKey] = localVehicleId;
  }

  static Map<String, String> unlink(
    Map<String, String> links,
    String officialVehicleKey,
  ) {
    return Map<String, String>.from(links)..remove(officialVehicleKey);
  }

  static Map<String, String> prune(
    Map<String, String> links,
    Set<String> validLocalVehicleIds,
  ) {
    return Map<String, String>.from(links)..removeWhere((_, localVehicleId) {
      return !validLocalVehicleIds.contains(localVehicleId);
    });
  }

  static bool isLinkedTo(
    Map<String, String> links, {
    required String officialVehicleKey,
    required String localVehicleId,
  }) {
    return links[officialVehicleKey] == localVehicleId;
  }
}
