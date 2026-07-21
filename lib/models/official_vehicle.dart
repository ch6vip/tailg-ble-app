import '../services/display_number_formatter.dart';
import 'command_types.dart';
import 'persistence_value.dart';

export 'official_cloud_message.dart';
export 'official_location_data.dart';
export 'official_vehicle_self_check.dart';

enum OfficialCloudCommand {
  lock('lock', CommandCode.lock),
  unlock('unlock', CommandCode.unlock),
  start('start', CommandCode.powerOn),
  stop('stop', CommandCode.powerOff),
  search('search', CommandCode.find),
  openCushion('openCushion', CommandCode.openSeat);

  final String apiName;
  final CommandCode commandCode;

  const OfficialCloudCommand(this.apiName, this.commandCode);

  static OfficialCloudCommand? fromCommandCode(CommandCode command) {
    for (final item in values) {
      if (item.commandCode == command) return item;
    }
    return null;
  }
}

class OfficialVehicle {
  static const _gpsModelTypes = {3, 8, 1501, 1601, 1701};
  static final RegExp _btmacSeparatorPattern = RegExp(r'[^0-9a-fA-F]');

  final String imei;
  final String imeiGps;
  final String carId;
  final String carName;
  final String carNickName;
  final String carPhoto;
  final String frame;
  final int? defenceStatus;
  final int? acc;
  final int? electricQuantity;
  final double? voltage;
  final bool online;
  final String btname;
  final String btmac;
  final String longitude;
  final String latitude;
  final int? modelType;
  final int? isGps;
  final String mqHost;
  final String mqPort;

  /// Official C18/QGJ MQTT auth (`CarControlInfoBean.mqUsername`).
  final String mqUsername;

  /// Official C18/QGJ MQTT auth (`CarControlInfoBean.mqPassword`).
  final String mqPassword;
  final double? mileage;
  final Map<String, dynamic> raw;

  const OfficialVehicle({
    required this.imei,
    required this.imeiGps,
    required this.carId,
    required this.carName,
    required this.carNickName,
    required this.carPhoto,
    required this.frame,
    required this.defenceStatus,
    required this.acc,
    required this.electricQuantity,
    required this.voltage,
    required this.online,
    required this.btname,
    required this.btmac,
    required this.longitude,
    required this.latitude,
    required this.modelType,
    required this.isGps,
    required this.mqHost,
    required this.mqPort,
    required this.mqUsername,
    required this.mqPassword,
    required this.mileage,
    this.raw = const {},
  });

  factory OfficialVehicle.fromJson(Map<String, dynamic> json) {
    // Official ControlFragment reads both `mac` (identity) and `btmac`.
    // Some payloads only fill one of them; keep both usable for BLE near-field.
    final btmacRaw = parsePersistedString(
      json['btmac'] ?? json['btMac'] ?? json['BTMAC'] ?? json['bluetoothMac'],
    );
    final identityMacRaw = parsePersistedString(
      json['mac'] ?? json['Mac'] ?? json['identityMac'] ?? json['bleMac'],
    );
    final normalizedBtmac = btmacRaw.isNotEmpty ? btmacRaw : identityMacRaw;

    // passwordInfo may arrive nested, stringified, or under alternate keys.
    final passwordInfo =
        parsePersistedMap(json['passwordInfo']) ??
        parsePersistedMap(json['password_info']) ??
        parsePersistedMap(json['pwdInfo']) ??
        parsePersistedMap(json['password']);
    final enriched = Map<String, dynamic>.of(json);
    if (normalizedBtmac.isNotEmpty &&
        parsePersistedString(enriched['btmac']).isEmpty) {
      enriched['btmac'] = normalizedBtmac;
    }
    if (identityMacRaw.isNotEmpty &&
        parsePersistedString(enriched['mac']).isEmpty) {
      enriched['mac'] = identityMacRaw;
    } else if (identityMacRaw.isEmpty &&
        normalizedBtmac.isNotEmpty &&
        parsePersistedString(enriched['mac']).isEmpty) {
      // Fall back so QGJ identity path still has a mac-like field.
      enriched['mac'] = normalizedBtmac;
    }
    if (passwordInfo != null && enriched['passwordInfo'] is! Map) {
      enriched['passwordInfo'] = passwordInfo;
    }

    return OfficialVehicle(
      imei: parsePersistedString(json['imei']),
      imeiGps: parsePersistedString(json['imeiGps']),
      carId: parsePersistedString(json['carId']),
      carName: parsePersistedString(json['carName']),
      carNickName: parsePersistedString(json['carNickName']),
      carPhoto: parsePersistedString(json['carPhoto']),
      frame: parsePersistedString(json['frame']),
      defenceStatus: parsePersistedInt(json['defenceStatus']),
      acc: parsePersistedInt(json['acc']),
      electricQuantity: parsePersistedInt(json['electricQuantity']),
      voltage: parsePersistedDouble(json['voltage']),
      online: parsePersistedBool(json['online']),
      btname: parsePersistedString(
        json['btname'] ?? json['btName'] ?? json['bluetoothName'],
      ),
      btmac: normalizedBtmac,
      longitude: parsePersistedString(json['longitude']),
      latitude: parsePersistedString(json['latitude']),
      modelType: parsePersistedInt(json['modelType']),
      isGps: parsePersistedInt(json['isGps']),
      mqHost: parsePersistedString(json['mqHost']),
      mqPort: parsePersistedString(json['mqPort']),
      mqUsername: parsePersistedString(
        json['mqUsername'] ?? json['mqUserName'] ?? json['mqttUsername'],
      ),
      mqPassword: parsePersistedString(
        json['mqPassword'] ?? json['mqttPassword'],
      ),
      mileage: parsePersistedDouble(json['mileage']),
      raw: Map<String, dynamic>.unmodifiable(enriched),
    );
  }

  Map<String, dynamic> toJson() {
    final json = Map<String, dynamic>.of(raw);
    json.addAll({
      'imei': imei,
      'imeiGps': imeiGps,
      'carId': carId,
      'carName': carName,
      'carNickName': carNickName,
      'carPhoto': carPhoto,
      'frame': frame,
      'defenceStatus': defenceStatus,
      'acc': acc,
      'electricQuantity': electricQuantity,
      'voltage': voltage,
      'online': online,
      'btname': btname,
      'btmac': btmac,
      'longitude': longitude,
      'latitude': latitude,
      'modelType': modelType,
      'isGps': isGps,
      'mqHost': mqHost,
      'mqPort': mqPort,
      'mqUsername': mqUsername,
      'mqPassword': mqPassword,
      'mileage': mileage,
    });
    return json;
  }

  String get key {
    if (carId.isNotEmpty) return carId;
    if (imei.isNotEmpty) return imei;
    if (imeiGps.isNotEmpty) return imeiGps;
    return '$btmac|$btname|$carName';
  }

  String get displayName {
    return _firstNonBlank([carNickName, carName, btname, frame, imei]) ??
        '官方车辆';
  }

  String get normalizedDeviceMac {
    final compact = btmac.replaceAll(_btmacSeparatorPattern, '').toUpperCase();
    if (compact.length != 12) return '';
    final pairs = <String>[];
    for (var index = 0; index < compact.length; index += 2) {
      pairs.add(compact.substring(index, index + 2));
    }
    return pairs.join(':');
  }

  /// QGJ compares this backend identity with advertisement manufacturer data.
  /// Other stacks usually return the same value as [normalizedDeviceMac].
  String get bleIdentityMac {
    final rawMac = parsePersistedString(
      raw['mac'] ?? raw['Mac'] ?? raw['identityMac'] ?? raw['bleMac'],
    );
    final source = rawMac.isNotEmpty ? rawMac : btmac;
    final compact = source.replaceAll(_btmacSeparatorPattern, '').toUpperCase();
    return compact.length == 12 ? compact : '';
  }

  int? get mainBlePassword {
    final passwordInfo =
        parsePersistedMap(raw['passwordInfo']) ??
        parsePersistedMap(raw['password_info']) ??
        parsePersistedMap(raw['pwdInfo']) ??
        parsePersistedMap(raw['password']);
    final direct = parsePersistedInt(
      passwordInfo?['main'] ??
          passwordInfo?['mainPassword'] ??
          passwordInfo?['password'],
    );
    if (direct != null) return direct;
    return parsePersistedInt(
      raw['mainPassword'] ?? raw['mainPwd'] ?? raw['password'],
    );
  }

  List<int> get childBlePasswords {
    final passwordInfo =
        parsePersistedMap(raw['passwordInfo']) ??
        parsePersistedMap(raw['password_info']) ??
        parsePersistedMap(raw['pwdInfo']) ??
        parsePersistedMap(raw['password']);
    final source =
        passwordInfo?['children'] ??
        passwordInfo?['child'] ??
        passwordInfo?['childrenPassword'] ??
        raw['childrenPassword'] ??
        raw['children'];
    if (source is! Iterable) return const [];
    return source
        .map(parsePersistedInt)
        .whereType<int>()
        .toList(growable: false);
  }

  bool get shareCarFlag => parsePersistedBool(raw['shareCarFlag']);

  bool get hasDeviceMac => normalizedDeviceMac.isNotEmpty;

  bool get hasGpsService {
    final type = modelType;
    return type != null && _gpsModelTypes.contains(type) && imeiGps.isNotEmpty;
  }

  String get commandImei {
    if (hasGpsService) {
      return imeiGps;
    }
    return imei;
  }

  bool get isLocked => defenceStatus == 1;
  bool get isPowerOn => acc == 1;

  /// Official `CarControlInfoBean.isCushionLock`. Null means the backend did
  /// not provide the capability, which is intentionally treated as unknown.
  bool? get isCushionLockSupported {
    const keys = <String>[
      'isCushionLock',
      'cushionLock',
      'isSeatLock',
      'seatLock',
    ];
    for (final key in keys) {
      if (!raw.containsKey(key)) continue;
      final value = raw[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value?.toString().trim().toLowerCase();
      if (text == '1' || text == 'true') return true;
      if (text == '0' || text == 'false') return false;
      return null;
    }
    return null;
  }

  OfficialVehicle copyWith({
    int? defenceStatus,
    int? acc,
    int? electricQuantity,
    double? voltage,
    bool? online,
    String? carNickName,
    String? longitude,
    String? latitude,
    double? mileage,
  }) {
    return OfficialVehicle(
      imei: imei,
      imeiGps: imeiGps,
      carId: carId,
      carName: carName,
      carNickName: carNickName ?? this.carNickName,
      carPhoto: carPhoto,
      frame: frame,
      defenceStatus: defenceStatus ?? this.defenceStatus,
      acc: acc ?? this.acc,
      electricQuantity: electricQuantity ?? this.electricQuantity,
      voltage: voltage ?? this.voltage,
      online: online ?? this.online,
      btname: btname,
      btmac: btmac,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
      modelType: modelType,
      isGps: isGps,
      mqHost: mqHost,
      mqPort: mqPort,
      mqUsername: mqUsername,
      mqPassword: mqPassword,
      mileage: mileage ?? this.mileage,
      raw: raw,
    );
  }

  bool get supportsNavigationProjection => _rawFeatureFlag(raw, const [
    'navigationProjection',
    'navProjection',
    'screenProjection',
    'mapEs',
    'mapProjection',
  ]);

  bool get supportsCamera =>
      _rawFeatureFlag(raw, const ['camera', 'cameraService', 'videoService']);

  bool get supportsSmartMeter => _rawFeatureFlag(raw, const [
    'smartMeter',
    'smartInstrument',
    'instrumentService',
    'sqService',
  ]);

  bool get supportsServiceRenewal => _rawFeatureFlag(raw, const [
    'bleRenewal',
    'bluetoothRenewal',
    'bleRecharge',
    'bleServiceRenew',
  ]);

  bool get supportsChargingStation => _rawFeatureFlag(raw, const [
    'chargingStation',
    'chargeStation',
    'tailgCharging',
  ]);

  String get onlineLabel => online ? '车辆在线' : '车辆离线';
  String get defenceLabel => isLocked ? '已设防' : '已解防';
  String get powerLabel => isPowerOn ? '车辆已启动' : '车辆未启动';
}

class OfficialTravelDay {
  final Map<String, dynamic> raw;
  final String sec;
  final String hours;
  final String min;
  final String travelDate;
  final String totalTime;
  final List<OfficialTravelRecord> records;
  final String days;
  final String totalMileage;

  const OfficialTravelDay({
    required this.raw,
    required this.sec,
    required this.hours,
    required this.min,
    required this.travelDate,
    required this.totalTime,
    required this.records,
    required this.days,
    required this.totalMileage,
  });

  factory OfficialTravelDay.fromJson(Map<String, dynamic> json) {
    return OfficialTravelDay(
      raw: _stringKeyedMap(json),
      sec: _clean(json['sec']) ?? '',
      hours: _clean(json['hours']) ?? '',
      min: _clean(json['min']) ?? '',
      travelDate: _clean(json['travelDate']) ?? '',
      totalTime: _clean(json['totalTime']) ?? '',
      records: _travelRecords(json['deviceTravelDtoList']),
      days: _clean(json['days']) ?? '',
      totalMileage: _clean(json['totalMileage']) ?? '',
    );
  }

  bool get hasData =>
      travelDate.isNotEmpty ||
      totalTime.isNotEmpty ||
      totalMileage.isNotEmpty ||
      records.isNotEmpty;
}

class OfficialTravelRecord {
  final Map<String, dynamic> raw;
  final String hours;
  final String carName;
  final String averageSpeed;
  final String deviceTravelId;
  final String sec;
  final String min;
  final String travelDate;
  final String imei;
  final String days;
  final String startTime;
  final String endTime;
  final String mileage;
  final String frame;
  final String maxSpeed;

  const OfficialTravelRecord({
    required this.raw,
    required this.hours,
    required this.carName,
    required this.averageSpeed,
    required this.deviceTravelId,
    required this.sec,
    required this.min,
    required this.travelDate,
    required this.imei,
    required this.days,
    required this.startTime,
    required this.endTime,
    required this.mileage,
    required this.frame,
    required this.maxSpeed,
  });

  factory OfficialTravelRecord.fromJson(Map<String, dynamic> json) {
    return OfficialTravelRecord(
      raw: _stringKeyedMap(json),
      hours: _clean(json['hours']) ?? '',
      carName: _clean(json['carName']) ?? '',
      averageSpeed: _clean(json['averageSpeed']) ?? '',
      deviceTravelId: _clean(json['deviceTravelId']) ?? '',
      sec: _clean(json['sec']) ?? '',
      min: _clean(json['min']) ?? '',
      travelDate: _clean(json['travelDate']) ?? '',
      imei: _clean(json['imei']) ?? '',
      days: _clean(json['days']) ?? '',
      startTime: _clean(json['startTime']) ?? '',
      endTime: _clean(json['endTime']) ?? '',
      mileage: _clean(json['mileage']) ?? '',
      frame: _clean(json['frame']) ?? '',
      maxSpeed: _clean(json['maxSpeed']) ?? '',
    );
  }

  String get durationLabel {
    final parts = <String>[];
    if (hours.isNotEmpty && hours != '0') {
      parts.add('${hours}h');
    }
    if (min.isNotEmpty && min != '0') {
      parts.add('${min}m');
    }
    if (sec.isNotEmpty && sec != '0') {
      parts.add('${sec}s');
    }
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      return '$startTime - $endTime';
    }
    return '待读取';
  }

  /// Official travel `mileage` is meters → display via [formatTravelMileageMetersText].
  String get mileageLabel =>
      mileage.isEmpty ? '待读取' : formatTravelMileageMetersText(mileage);
  String get averageSpeedLabel => averageSpeed.isEmpty
      ? '待读取'
      : '${formatCompactDecimalText(averageSpeed)}km/h';
  String get maxSpeedLabel =>
      maxSpeed.isEmpty ? '待读取' : '${formatCompactDecimalText(maxSpeed)}km/h';

  /// Raw travel mileage in meters (official `deviceTravel` unit).
  double get mileageMeters => parseTravelMileageMeters(mileage);

  /// Travel mileage converted to km (`meters / 1000`).
  double get mileageKm => travelMetersToKm(mileageMeters);

  /// Duration from hours/min/sec fields; non-numeric parts count as 0.
  int get durationSeconds =>
      (int.tryParse(hours) ?? 0) * 3600 +
      (int.tryParse(min) ?? 0) * 60 +
      (int.tryParse(sec) ?? 0);
}

double sumTravelMileageKm(Iterable<OfficialTravelRecord> records) {
  return records.fold<double>(0, (sum, record) => sum + record.mileageKm);
}

int sumTravelDurationSeconds(Iterable<OfficialTravelRecord> records) {
  return records.fold<int>(0, (sum, record) => sum + record.durationSeconds);
}

/// Compact `2h30m` / `30m` duration label used by travel and ride stats.
///
/// When [emptyWhenZero] is true, zero/negative totals render as `''`
/// (travel day cards prefer blank over `0m`).
String formatCompactDuration(int seconds, {bool emptyWhenZero = false}) {
  if (seconds <= 0) return emptyWhenZero ? '' : '0m';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h${minutes}m';
  return '${minutes}m';
}

class OfficialTravelPoint {
  final Map<String, dynamic> raw;
  final String lng;
  final String heading;
  final String starsNum;
  final String lat;
  final String reportTime;
  final String speed;

  const OfficialTravelPoint({
    required this.raw,
    required this.lng,
    required this.heading,
    required this.starsNum,
    required this.lat,
    required this.reportTime,
    required this.speed,
  });

  factory OfficialTravelPoint.fromJson(Map<String, dynamic> json) {
    return OfficialTravelPoint(
      raw: _stringKeyedMap(json),
      lng: _clean(json['lng']) ?? '',
      heading: _clean(json['heading']) ?? '',
      starsNum: _clean(json['starsNum']) ?? '',
      lat: _clean(json['lat']) ?? '',
      reportTime: _clean(json['reportTime']) ?? '',
      speed: _clean(json['speed']) ?? '',
    );
  }

  double? get latitude => double.tryParse(lat);
  double? get longitude => double.tryParse(lng);

  bool get hasCoordinate => latitude != null && longitude != null;
}

class OfficialBatteryInfo {
  final Map<String, dynamic> raw;
  final String dumpEnergyPercent;
  final String dumpEnergyPercentLabel;
  final String remainingMileage;
  final String mileage;
  final String capacitance;
  final String consumePowerPercent;
  final String loopCount;
  final String temperature;
  final String batteryScore;
  final String voltage;

  const OfficialBatteryInfo({
    required this.raw,
    required this.dumpEnergyPercent,
    required this.dumpEnergyPercentLabel,
    required this.remainingMileage,
    required this.mileage,
    required this.capacitance,
    required this.consumePowerPercent,
    required this.loopCount,
    required this.temperature,
    required this.batteryScore,
    required this.voltage,
  });

  factory OfficialBatteryInfo.fromJson(Map<String, dynamic> json) {
    // Official BatteryInfoBean field names, plus common alternates seen in
    // nested / BMS payloads. Numeric 0 must be kept (今日耗电/循环次数 can be 0).
    final dumpEnergyPercent = _batteryField(json, const [
      'dumpEnergyPercent',
      'dumpEnergy',
      'soc',
      'SOC',
      'electricQuantity',
      'batteryPercent',
    ]);
    final dumpEnergyPercentLabel =
        _batteryField(json, const ['dumpEnergyPercentLabel', 'socLabel']) ??
        (dumpEnergyPercent == null ? '' : '$dumpEnergyPercent%');
    return OfficialBatteryInfo(
      raw: _stringKeyedMap(json),
      dumpEnergyPercent: dumpEnergyPercent ?? '',
      dumpEnergyPercentLabel: dumpEnergyPercentLabel,
      remainingMileage:
          _batteryField(json, const [
            'remainingMileage',
            'remainMileage',
            'leftMileage',
            'estimateMileage',
          ]) ??
          '',
      mileage:
          _batteryField(json, const ['mileage', 'totalMileage', 'odometer']) ??
          '',
      capacitance:
          _batteryField(json, const [
            'capacitance',
            'capacity',
            'batteryCapacity',
            'estimateBatteryCapacity',
          ]) ??
          '',
      consumePowerPercent:
          _batteryField(json, const [
            'consumePowerPercent',
            'consumePower',
            'todayConsumePower',
            'todayPowerConsume',
            'powerConsumePercent',
            'dayConsumePower',
          ]) ??
          '',
      loopCount:
          _batteryField(json, const [
            'loopCount',
            'cycleCount',
            'cycles',
            'batteryCyclesNum',
            'batteryCycle',
            'cycleTimes',
          ]) ??
          '',
      temperature:
          _batteryField(json, const [
            'temperature',
            'batteryTemperature',
            'temp',
            'batteryTemp',
            'currentTemperature',
          ]) ??
          '',
      batteryScore:
          _batteryField(json, const [
            'batteryScore',
            'score',
            'soh',
            'SOH',
            'healthScore',
          ]) ??
          '',
      voltage:
          _batteryField(json, const [
            'voltage',
            'batteryVoltage',
            'currentBatteryVoltage',
            'vol',
          ]) ??
          '',
    );
  }

  bool get hasData =>
      dumpEnergyPercent.isNotEmpty ||
      remainingMileage.isNotEmpty ||
      mileage.isNotEmpty ||
      capacitance.isNotEmpty ||
      consumePowerPercent.isNotEmpty ||
      loopCount.isNotEmpty ||
      temperature.isNotEmpty ||
      batteryScore.isNotEmpty ||
      voltage.isNotEmpty;
}

/// Read first non-empty battery metric. Keeps numeric `0` / `"0"`.
String? _batteryField(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (!json.containsKey(key)) continue;
    final cleaned = _clean(json[key]);
    if (cleaned != null) return cleaned;
  }
  return null;
}

String? _clean(Object? value) {
  if (value == null) return null;
  // Keep real zero values from the official battery API.
  if (value is num) return value.toString();
  final text = value.toString().trim();
  if (text.isEmpty || text == '--' || text.toLowerCase() == 'null') {
    return null;
  }
  return text;
}

Map<String, dynamic> _stringKeyedMap(Map<Object?, Object?> value) {
  return Map<String, dynamic>.unmodifiable(parsePersistedMap(value)!);
}

String? _firstNonBlank(Iterable<String> values) {
  for (final value in values) {
    final text = value.trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

bool _rawFeatureFlag(Map<String, dynamic> raw, List<String> keys) {
  if (raw.isEmpty) return false;
  final targets = keys.map((key) => key.toLowerCase()).toList(growable: false);
  return _rawEntries(raw).any((entry) {
    final key = entry.key.toLowerCase();
    if (!targets.any(key.contains)) return false;
    return _truthyFeatureValue(entry.value);
  });
}

Iterable<MapEntry<String, Object?>> _rawEntries(
  Map<Object?, Object?> raw, [
  String prefix = '',
]) sync* {
  for (final entry in raw.entries) {
    final key = entry.key?.toString() ?? '';
    final path = prefix.isEmpty ? key : '$prefix.$key';
    final value = entry.value;
    yield MapEntry(path, value);
    if (value is Map<Object?, Object?>) {
      yield* _rawEntries(value, path);
    }
  }
}

bool _truthyFeatureValue(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty) return false;
    return !const {
      '0',
      'false',
      'no',
      'n',
      'off',
      '关闭',
      '无',
      'none',
      'null',
    }.contains(text);
  }
  if (value is Iterable) return value.isNotEmpty;
  if (value is Map) {
    for (final key in const [
      'enabled',
      'enable',
      'support',
      'supported',
      'open',
    ]) {
      if (value.containsKey(key)) return _truthyFeatureValue(value[key]);
    }
    return value.isNotEmpty;
  }
  return value != null;
}

List<OfficialTravelRecord> _travelRecords(Object? value) {
  return parsePersistedMapList(
    value,
  ).map(OfficialTravelRecord.fromJson).toList(growable: false);
}
