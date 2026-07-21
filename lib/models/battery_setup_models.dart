import 'persistence_value.dart';

/// Official `BatteryTypeBean` from `app/centralControl/batteryType(/ext)`.
class OfficialBatteryType {
  final String type;
  final String name;

  const OfficialBatteryType({required this.type, required this.name});

  factory OfficialBatteryType.fromJson(Map<String, dynamic> json) {
    return OfficialBatteryType(
      type: parsePersistedString(json['type'] ?? json['id'] ?? json['typeId']),
      name: parsePersistedString(
        json['name'] ?? json['label'] ?? json['typeName'],
      ),
    );
  }

  /// Official custom type uses type id `"0"` and free-form V/AH inputs.
  bool get isCustom => type == '0';

  bool get isValid => type.isNotEmpty && name.isNotEmpty;
}

/// Official `BatterySpecBean` from `app/centralControl/batterySpecByType`.
class OfficialBatterySpec {
  final String code;
  final String spec;

  const OfficialBatterySpec({required this.code, required this.spec});

  factory OfficialBatterySpec.fromJson(Map<String, dynamic> json) {
    return OfficialBatterySpec(
      code: parsePersistedString(
        json['code'] ?? json['specCode'] ?? json['id'],
      ),
      spec: parsePersistedString(json['spec'] ?? json['label'] ?? json['name']),
    );
  }

  bool get isValid => code.isNotEmpty && spec.isNotEmpty;
}

/// Payload for `POST app/centralControl/batterySetUp` (affirmBatteryInfo).
class AffirmBatteryInfoRequest {
  final String carId;
  final String? batteryCode;
  final String? bindDate;
  final String? batteryType;
  final String? batteryVoltage;
  final String? batteryCapacity;

  const AffirmBatteryInfoRequest({
    required this.carId,
    this.batteryCode,
    this.bindDate,
    this.batteryType,
    this.batteryVoltage,
    this.batteryCapacity,
  });

  Map<String, Object> toBody() {
    final body = <String, Object>{'carId': carId};
    void put(String key, String? value) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) body[key] = text;
    }

    put('batteryCode', batteryCode);
    put('bindDate', bindDate);
    put('batteryType', batteryType);
    put('batteryVoltage', batteryVoltage);
    put('batteryCapacity', batteryCapacity);
    return body;
  }
}
