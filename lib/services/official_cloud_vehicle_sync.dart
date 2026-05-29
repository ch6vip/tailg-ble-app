part of 'official_cloud_service.dart';

class OfficialCloudVehicleSyncDecision {
  final String? linkedLocalVehicleId;
  final OfficialCloudVehicleProfileData? profileData;

  const OfficialCloudVehicleSyncDecision._({
    required this.linkedLocalVehicleId,
    required this.profileData,
  });

  factory OfficialCloudVehicleSyncDecision.useLinkedLocalVehicle(
    String linkedLocalVehicleId,
  ) {
    return OfficialCloudVehicleSyncDecision._(
      linkedLocalVehicleId: linkedLocalVehicleId,
      profileData: null,
    );
  }

  factory OfficialCloudVehicleSyncDecision.upsertLocalProfile(
    OfficialCloudVehicleProfileData profileData,
  ) {
    return OfficialCloudVehicleSyncDecision._(
      linkedLocalVehicleId: null,
      profileData: profileData,
    );
  }
}

class OfficialCloudVehicleSyncPlanner {
  const OfficialCloudVehicleSyncPlanner._();

  static OfficialCloudVehicleSyncDecision? plan({
    required OfficialVehicle selectedVehicle,
    required Map<String, String> localVehicleLinks,
    required List<VehicleProfile> localVehicles,
  }) {
    final linkedId = selectedVehicle.key.isEmpty
        ? null
        : localVehicleLinks[selectedVehicle.key];
    if (linkedId != null && linkedId.isNotEmpty) {
      final hasLinkedVehicle = localVehicles.any(
        (local) => local.id == linkedId,
      );
      if (hasLinkedVehicle) {
        return OfficialCloudVehicleSyncDecision.useLinkedLocalVehicle(linkedId);
      }
    }

    final profileData = OfficialCloudVehicleMapper.profileFromOfficialVehicle(
      selectedVehicle,
    );
    if (profileData == null) return null;
    return OfficialCloudVehicleSyncDecision.upsertLocalProfile(profileData);
  }
}
