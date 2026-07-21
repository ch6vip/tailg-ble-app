import 'persistence_value.dart';

/// Official `BmsBatteryInfoBean` from `POST app/mine/bmsBatteryInfo`.
class OfficialBmsInfo {
  final Map<String, dynamic> raw;
  final String imei;
  final String num;
  final String soc;
  final String batterySpec;
  final List<OfficialBmsDetail> details;

  const OfficialBmsInfo({
    required this.raw,
    required this.imei,
    required this.num,
    required this.soc,
    required this.batterySpec,
    required this.details,
  });

  factory OfficialBmsInfo.fromJson(Map<String, dynamic> json) {
    final detailsRaw = json['details'];
    final details = <OfficialBmsDetail>[];
    if (detailsRaw is Iterable) {
      for (final item in detailsRaw) {
        final map = parsePersistedMap(item);
        if (map != null) details.add(OfficialBmsDetail.fromJson(map));
      }
    }
    return OfficialBmsInfo(
      raw: Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(json)),
      imei: parsePersistedString(json['imei']),
      num: parsePersistedString(json['num']),
      soc: parsePersistedString(json['soc']),
      batterySpec: parsePersistedString(json['batterySpec']),
      details: List<OfficialBmsDetail>.unmodifiable(details),
    );
  }

  bool get hasData =>
      details.isNotEmpty ||
      soc.isNotEmpty ||
      batterySpec.isNotEmpty ||
      imei.isNotEmpty;

  OfficialBmsDetail? get primaryDetail =>
      details.isEmpty ? null : details.first;
}

class OfficialBmsDetail {
  final Map<String, dynamic> raw;
  final String name;
  final String sn;
  final String soc;
  final String soh;
  final String currentBatteryVoltage;
  final String batteryVoltage;
  final String batteryCurrent;
  final String batteryCapacity;
  final String batteryCyclesNum;
  final String batteryTemperature;
  final String batteryType;
  final String batteryVersion;
  final String batteryChargeNum;
  final String batteryDischargeNum;

  const OfficialBmsDetail({
    required this.raw,
    required this.name,
    required this.sn,
    required this.soc,
    required this.soh,
    required this.currentBatteryVoltage,
    required this.batteryVoltage,
    required this.batteryCurrent,
    required this.batteryCapacity,
    required this.batteryCyclesNum,
    required this.batteryTemperature,
    required this.batteryType,
    required this.batteryVersion,
    required this.batteryChargeNum,
    required this.batteryDischargeNum,
  });

  factory OfficialBmsDetail.fromJson(Map<String, dynamic> json) {
    return OfficialBmsDetail(
      raw: Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(json)),
      name: parsePersistedString(json['name']),
      sn: parsePersistedString(json['sn']),
      soc: parsePersistedString(json['soc']),
      soh: parsePersistedString(json['soh'] ?? json['SOH']),
      currentBatteryVoltage: parsePersistedString(
        json['currentBatteryVoltage'] ?? json['batteryVoltage'],
      ),
      batteryVoltage: parsePersistedString(json['batteryVoltage']),
      batteryCurrent: parsePersistedString(json['batteryCurrent']),
      batteryCapacity: parsePersistedString(
        json['batteryCapacity'] ?? json['capacitance'],
      ),
      batteryCyclesNum: parsePersistedString(
        json['batteryCyclesNum'] ?? json['loopCount'] ?? json['cycles'],
      ),
      batteryTemperature: parsePersistedString(
        json['batteryTemperature'] ?? json['temperature'],
      ),
      batteryType: parsePersistedString(json['batteryType']),
      batteryVersion: parsePersistedString(
        json['batteryVersion'] ?? json['swVer'] ?? json['hwVer'],
      ),
      batteryChargeNum: parsePersistedString(json['batteryChargeNum']),
      batteryDischargeNum: parsePersistedString(json['batteryDischargeNum']),
    );
  }

  bool get hasData =>
      soc.isNotEmpty ||
      soh.isNotEmpty ||
      currentBatteryVoltage.isNotEmpty ||
      batteryCyclesNum.isNotEmpty ||
      batteryTemperature.isNotEmpty ||
      batteryCapacity.isNotEmpty;
}
