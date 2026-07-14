part of 'official_cloud_service.dart';

enum OfficialCloudResponseCode {
  success('200'),
  legacySuccess('0');

  final String wireCode;

  const OfficialCloudResponseCode(this.wireCode);

  static OfficialCloudResponseCode? parse(Object? code) {
    final normalized = code?.toString().trim();
    for (final value in values) {
      if (value.wireCode == normalized) return value;
    }
    return null;
  }

  static bool isSuccessBody(Map<String, dynamic> body) {
    return parse(body['code'])?.isSuccess == true;
  }

  bool get isSuccess {
    return switch (this) {
      OfficialCloudResponseCode.success ||
      OfficialCloudResponseCode.legacySuccess => true,
    };
  }
}

final class OfficialCloudLoginValidator {
  OfficialCloudLoginValidator._();

  static final RegExp _phonePattern = RegExp(r'^\d{11}$');
  static final RegExp _smsCodePattern = RegExp(r'^\d{4,8}$');
  static final RegExp _phoneWhitespacePattern = RegExp(r'\s+');

  static String compactPhone(String value) {
    return value.replaceAll(_phoneWhitespacePattern, '');
  }

  static bool isValidPhone(String value) {
    return _phonePattern.hasMatch(value);
  }

  static bool isValidSmsCode(String value) {
    return _smsCodePattern.hasMatch(value);
  }
}

/// Shared user-facing copy for official-cloud auth gates.
abstract final class OfficialCloudMessages {
  static const signInRequired = '请先登录官方账号';
  static const signInAndSelectVehicleRequired = '请先登录官方账号并选择车辆';

  /// Contextual gate used by location sync actions.
  static String signInRequiredBefore(String action) => '请先登录官方账号后再$action';
}

class OfficialCloudState {
  final bool initialized;
  final String token;
  final String phone;
  final String userId;
  final bool loading;
  final String? error;
  final List<OfficialVehicle> vehicles;
  final String? selectedVehicleKey;
  final Map<String, String> localVehicleLinks;
  final OfficialBatteryInfo? batteryInfo;
  final bool batteryInfoLoading;
  final String? batteryInfoError;
  final OfficialVehicleLocation? vehicleLocation;
  final bool vehicleLocationLoading;
  final String? vehicleLocationError;
  final OfficialFenceData? fenceData;
  final bool fenceLoading;
  final String? fenceError;
  final List<OfficialTravelDay> travelDays;
  final String travelMonth;
  final bool travelLoading;
  final String? travelError;
  final Map<String, List<OfficialTravelPoint>> travelDetails;
  final bool travelDetailLoading;
  final String? travelDetailError;
  final List<OfficialCloudMessage> vehicleMessages;
  final List<OfficialCloudMessage> systemMessages;
  final bool messagesLoading;
  final String? messagesError;

  const OfficialCloudState({
    required this.initialized,
    required this.token,
    required this.phone,
    required this.userId,
    required this.loading,
    required this.error,
    required this.vehicles,
    required this.selectedVehicleKey,
    required this.localVehicleLinks,
    required this.batteryInfo,
    required this.batteryInfoLoading,
    required this.batteryInfoError,
    required this.vehicleLocation,
    required this.vehicleLocationLoading,
    required this.vehicleLocationError,
    required this.fenceData,
    required this.fenceLoading,
    required this.fenceError,
    required this.travelDays,
    required this.travelMonth,
    required this.travelLoading,
    required this.travelError,
    required this.travelDetails,
    required this.travelDetailLoading,
    required this.travelDetailError,
    required this.vehicleMessages,
    required this.systemMessages,
    required this.messagesLoading,
    required this.messagesError,
  });

  factory OfficialCloudState.initial() => const OfficialCloudState(
    initialized: false,
    token: '',
    phone: '',
    userId: '',
    loading: false,
    error: null,
    vehicles: [],
    selectedVehicleKey: null,
    localVehicleLinks: {},
    batteryInfo: null,
    batteryInfoLoading: false,
    batteryInfoError: null,
    vehicleLocation: null,
    vehicleLocationLoading: false,
    vehicleLocationError: null,
    fenceData: null,
    fenceLoading: false,
    fenceError: null,
    travelDays: [],
    travelMonth: '',
    travelLoading: false,
    travelError: null,
    travelDetails: {},
    travelDetailLoading: false,
    travelDetailError: null,
    vehicleMessages: [],
    systemMessages: [],
    messagesLoading: false,
    messagesError: null,
  );

  bool get signedIn => token.isNotEmpty;

  OfficialVehicle? get selectedVehicle {
    if (vehicles.isEmpty) return null;
    if (selectedVehicleKey == null) return vehicles.first;
    for (final vehicle in vehicles) {
      if (vehicle.key == selectedVehicleKey) return vehicle;
    }
    return vehicles.first;
  }

  String? linkedLocalVehicleId(String officialVehicleKey) =>
      OfficialCloudVehicleLinks.normalize(localVehicleLinks)[officialVehicleKey
          .trim()];

  OfficialCloudState copyWith({
    bool? initialized,
    String? token,
    String? phone,
    String? userId,
    bool? loading,
    Object? error = _sentinel,
    List<OfficialVehicle>? vehicles,
    Object? selectedVehicleKey = _sentinel,
    Map<String, String>? localVehicleLinks,
    Object? batteryInfo = _sentinel,
    bool? batteryInfoLoading,
    Object? batteryInfoError = _sentinel,
    Object? vehicleLocation = _sentinel,
    bool? vehicleLocationLoading,
    Object? vehicleLocationError = _sentinel,
    Object? fenceData = _sentinel,
    bool? fenceLoading,
    Object? fenceError = _sentinel,
    List<OfficialTravelDay>? travelDays,
    String? travelMonth,
    bool? travelLoading,
    Object? travelError = _sentinel,
    Map<String, List<OfficialTravelPoint>>? travelDetails,
    bool? travelDetailLoading,
    Object? travelDetailError = _sentinel,
    List<OfficialCloudMessage>? vehicleMessages,
    List<OfficialCloudMessage>? systemMessages,
    bool? messagesLoading,
    Object? messagesError = _sentinel,
  }) {
    return OfficialCloudState(
      initialized: initialized ?? this.initialized,
      token: token ?? this.token,
      phone: phone ?? this.phone,
      userId: userId ?? this.userId,
      loading: loading ?? this.loading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      vehicles: vehicles ?? this.vehicles,
      selectedVehicleKey: identical(selectedVehicleKey, _sentinel)
          ? this.selectedVehicleKey
          : selectedVehicleKey as String?,
      localVehicleLinks: localVehicleLinks ?? this.localVehicleLinks,
      batteryInfo: identical(batteryInfo, _sentinel)
          ? this.batteryInfo
          : batteryInfo as OfficialBatteryInfo?,
      batteryInfoLoading: batteryInfoLoading ?? this.batteryInfoLoading,
      batteryInfoError: identical(batteryInfoError, _sentinel)
          ? this.batteryInfoError
          : batteryInfoError as String?,
      vehicleLocation: identical(vehicleLocation, _sentinel)
          ? this.vehicleLocation
          : vehicleLocation as OfficialVehicleLocation?,
      vehicleLocationLoading:
          vehicleLocationLoading ?? this.vehicleLocationLoading,
      vehicleLocationError: identical(vehicleLocationError, _sentinel)
          ? this.vehicleLocationError
          : vehicleLocationError as String?,
      fenceData: identical(fenceData, _sentinel)
          ? this.fenceData
          : fenceData as OfficialFenceData?,
      fenceLoading: fenceLoading ?? this.fenceLoading,
      fenceError: identical(fenceError, _sentinel)
          ? this.fenceError
          : fenceError as String?,
      travelDays: travelDays ?? this.travelDays,
      travelMonth: travelMonth ?? this.travelMonth,
      travelLoading: travelLoading ?? this.travelLoading,
      travelError: identical(travelError, _sentinel)
          ? this.travelError
          : travelError as String?,
      travelDetails: travelDetails ?? this.travelDetails,
      travelDetailLoading: travelDetailLoading ?? this.travelDetailLoading,
      travelDetailError: identical(travelDetailError, _sentinel)
          ? this.travelDetailError
          : travelDetailError as String?,
      vehicleMessages: vehicleMessages ?? this.vehicleMessages,
      systemMessages: systemMessages ?? this.systemMessages,
      messagesLoading: messagesLoading ?? this.messagesLoading,
      messagesError: identical(messagesError, _sentinel)
          ? this.messagesError
          : messagesError as String?,
    );
  }

  static const _sentinel = Object();
}
