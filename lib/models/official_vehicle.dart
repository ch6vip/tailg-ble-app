import 'command_types.dart';
import 'persistence_value.dart';

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
    required this.mileage,
    this.raw = const {},
  });

  factory OfficialVehicle.fromJson(Map<String, dynamic> json) {
    return OfficialVehicle(
      imei: _stringValue(json['imei']),
      imeiGps: _stringValue(json['imeiGps']),
      carId: _stringValue(json['carId']),
      carName: _stringValue(json['carName']),
      carNickName: _stringValue(json['carNickName']),
      carPhoto: _stringValue(json['carPhoto']),
      frame: _stringValue(json['frame']),
      defenceStatus: _intOrNull(json['defenceStatus']),
      acc: _intOrNull(json['acc']),
      electricQuantity: _intOrNull(json['electricQuantity']),
      voltage: _doubleOrNull(json['voltage']),
      online: _boolValue(json['online']),
      btname: _stringValue(json['btname']),
      btmac: _stringValue(json['btmac']),
      longitude: _stringValue(json['longitude']),
      latitude: _stringValue(json['latitude']),
      modelType: _intOrNull(json['modelType']),
      mileage: _doubleOrNull(json['mileage']),
      raw: Map<String, dynamic>.unmodifiable(json),
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

class OfficialVehicleLocation {
  final Map<String, dynamic> raw;
  final String extendId;
  final String bleConnectTime;
  final String bleConnectLat;
  final String bleConnectLng;
  final String carId;
  final String bleConnectAddress;

  const OfficialVehicleLocation({
    required this.raw,
    required this.extendId,
    required this.bleConnectTime,
    required this.bleConnectLat,
    required this.bleConnectLng,
    required this.carId,
    required this.bleConnectAddress,
  });

  factory OfficialVehicleLocation.fromJson(Map<String, dynamic> json) {
    return OfficialVehicleLocation(
      raw: _rawPayload(json),
      extendId: _clean(json['extendId']) ?? '',
      bleConnectTime: _clean(json['bleConnectTime']) ?? '',
      bleConnectLat: _clean(json['bleConnectLat']) ?? '',
      bleConnectLng: _clean(json['bleConnectLng']) ?? '',
      carId: _clean(json['carId']) ?? '',
      bleConnectAddress: _clean(json['bleConnectAddress']) ?? '',
    );
  }

  bool get hasData =>
      bleConnectLat.isNotEmpty ||
      bleConnectLng.isNotEmpty ||
      bleConnectAddress.isNotEmpty ||
      bleConnectTime.isNotEmpty;

  double? get latitude => _double(bleConnectLat);
  double? get longitude => _double(bleConnectLng);

  static double? _double(String value) => double.tryParse(value.trim());
}

class OfficialFenceData {
  final Map<String, dynamic> raw;
  final String fenceRadius;
  final String fenceRadiusMax;
  final String fenceRadiusMin;
  final String fenceSwitch;
  final String fenceTimeFr;
  final String fenceTimeTo;

  const OfficialFenceData({
    required this.raw,
    required this.fenceRadius,
    required this.fenceRadiusMax,
    required this.fenceRadiusMin,
    required this.fenceSwitch,
    required this.fenceTimeFr,
    required this.fenceTimeTo,
  });

  factory OfficialFenceData.fromJson(Map<String, dynamic> json) {
    return OfficialFenceData(
      raw: _rawPayload(json),
      fenceRadius: _clean(json['fenceRadius'] ?? json['range']) ?? '',
      fenceRadiusMax: _clean(json['fenceRadiusMax']) ?? '',
      fenceRadiusMin: _clean(json['fenceRadiusMin']) ?? '',
      fenceSwitch: _clean(json['fenceSwitch']) ?? '',
      fenceTimeFr: _clean(json['fenceTimeFr']) ?? '',
      fenceTimeTo: _clean(json['fenceTimeTo']) ?? '',
    );
  }

  bool get hasData =>
      fenceRadius.isNotEmpty ||
      fenceRadiusMax.isNotEmpty ||
      fenceRadiusMin.isNotEmpty ||
      fenceSwitch.isNotEmpty ||
      fenceTimeFr.isNotEmpty ||
      fenceTimeTo.isNotEmpty;

  bool get enabled => fenceSwitch == '1' || fenceSwitch.toLowerCase() == 'true';

  String get statusLabel {
    if (fenceSwitch.isEmpty) return '待读取';
    return enabled ? '已开启' : '已关闭';
  }

  String get radiusLabel {
    final meters = radiusMeters;
    if (meters == null) return fenceRadius.isEmpty ? '待读取' : fenceRadius;
    return '${meters.toStringAsFixed(0)}m';
  }

  double? get radiusMeters {
    if (fenceRadius.isEmpty) return null;
    final value = double.tryParse(fenceRadius);
    if (value == null) return null;
    return value * 100;
  }

  String get timeLabel {
    if (fenceTimeFr.isEmpty && fenceTimeTo.isEmpty) return '待读取';
    return '${fenceTimeFr.isEmpty ? '--' : fenceTimeFr} - ${fenceTimeTo.isEmpty ? '--' : fenceTimeTo}';
  }
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
      raw: _rawPayload(json),
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
      raw: _rawPayload(json),
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

  String get mileageLabel => mileage.isEmpty ? '待读取' : '${_round1(mileage)}km';
  String get averageSpeedLabel =>
      averageSpeed.isEmpty ? '待读取' : '${_round1(averageSpeed)}km/h';
  String get maxSpeedLabel =>
      maxSpeed.isEmpty ? '待读取' : '${_round1(maxSpeed)}km/h';

  // Official trip values can come back as long raw doubles
  // (e.g. "20.133333333"). Round to one decimal and drop a trailing ".0"
  // so the list stays readable; fall back to the raw text if it isn't numeric.
  static String _round1(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) return value;
    final fixed = parsed.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }
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
      raw: _rawPayload(json),
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
    final dumpEnergyPercent = _clean(json['dumpEnergyPercent']);
    final dumpEnergyPercentLabel =
        _clean(json['dumpEnergyPercentLabel']) ??
        (dumpEnergyPercent == null ? '' : '$dumpEnergyPercent%');
    return OfficialBatteryInfo(
      raw: _rawPayload(json),
      dumpEnergyPercent: dumpEnergyPercent ?? '',
      dumpEnergyPercentLabel: dumpEnergyPercentLabel,
      remainingMileage: _clean(json['remainingMileage']) ?? '',
      mileage: _clean(json['mileage']) ?? '',
      capacitance: _clean(json['capacitance']) ?? '',
      consumePowerPercent: _clean(json['consumePowerPercent']) ?? '',
      loopCount: _clean(json['loopCount']) ?? '',
      temperature: _clean(json['temperature']) ?? '',
      batteryScore: _clean(json['batteryScore']) ?? '',
      voltage: _clean(json['voltage']) ?? '',
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

String? _clean(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text == '--' || text.toLowerCase() == 'null') {
    return null;
  }
  return text;
}

class OfficialCloudMessage {
  final String id;
  final String title;
  final String content;
  final DateTime time;
  final OfficialCloudMessageCategory category;
  final String messageCode;
  final String carId;
  final String? url;

  const OfficialCloudMessage({
    required this.id,
    required this.title,
    required this.content,
    required this.time,
    required this.category,
    this.messageCode = '',
    this.carId = '',
    this.url,
  });

  factory OfficialCloudMessage.vehicle(Map<String, dynamic> json) {
    final id = _firstNonEmpty([
      json['msgId'],
      json['carProblemMessageRecordId'],
      json['carProblemMessageInfoId'],
    ]);
    return OfficialCloudMessage(
      id: id.isEmpty ? _fallbackId(json, 'vehicle') : 'vehicle:$id',
      title: _clean(json['title']) ?? '车辆消息',
      content: _clean(json['content']) ?? '',
      time: _parseMessageTime(json['sendTime']),
      category: OfficialCloudMessageCategory.vehicle,
      messageCode: _clean(json['messageCode']) ?? '',
      carId: _clean(json['carId']) ?? '',
    );
  }

  factory OfficialCloudMessage.system(Map<String, dynamic> json) {
    final id = _firstNonEmpty([
      json['sysMessageRecordId'],
      json['sysMessageInfoId'],
      json['messageCode'],
    ]);
    return OfficialCloudMessage(
      id: id.isEmpty ? _fallbackId(json, 'system') : 'system:$id',
      title: _clean(json['title']) ?? '系统消息',
      content: _clean(json['content'] ?? json['description']) ?? '',
      time: _parseMessageTime(json['sendTime']),
      category: OfficialCloudMessageCategory.system,
      messageCode: _clean(json['messageCode']) ?? '',
      url: _clean(json['url']),
    );
  }

  static String _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = _clean(value);
      if (text != null && text.isNotEmpty) return text;
    }
    return '';
  }

  static String _fallbackId(Map<String, dynamic> json, String prefix) {
    final title = _clean(json['title']) ?? '';
    final content = _clean(json['content']) ?? '';
    final sendTime = _clean(json['sendTime']) ?? '';
    return '$prefix:${title.hashCode}_${content.hashCode}_$sendTime';
  }
}

enum OfficialCloudMessageCategory {
  vehicle('设备消息'),
  system('系统消息');

  final String label;
  const OfficialCloudMessageCategory(this.label);
}

DateTime _parseMessageTime(Object? value) {
  final text = _clean(value);
  if (text == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
  return parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

class OfficialVehicleSelfCheck {
  final Map<String, dynamic> raw;
  final int? code;
  final String message;
  final Object? data;

  const OfficialVehicleSelfCheck({
    required this.raw,
    required this.code,
    required this.message,
    required this.data,
  });

  factory OfficialVehicleSelfCheck.fromResponse(Map<String, dynamic> json) {
    return OfficialVehicleSelfCheck(
      raw: _rawPayload(json),
      code: _intOrNull(json['code']),
      message: json['msg']?.toString() ?? '',
      data: json['data'],
    );
  }

  bool get hasData => data != null;

  Map<String, dynamic> get dataMap => _dataMap(data);

  String get displayMessage {
    final text = message.trim();
    if (text.isNotEmpty) return text;
    if (code != null) return 'code=$code';
    return '自检已返回';
  }
}

Map<String, dynamic> _rawPayload(Map<String, dynamic> json) {
  return _stringKeyedMap(json);
}

Map<String, dynamic> _dataMap(Object? value) {
  if (value is Map<Object?, Object?>) return _stringKeyedMap(value);
  return const {};
}

Map<String, dynamic> _stringKeyedMap(Map<Object?, Object?> value) {
  return Map<String, dynamic>.unmodifiable(parsePersistedMap(value)!);
}

String _stringValue(Object? value) => value?.toString().trim() ?? '';

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

bool _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  return text == 'true' || text == '1';
}

List<OfficialTravelRecord> _travelRecords(Object? value) {
  return parsePersistedMapList(
    value,
  ).map(OfficialTravelRecord.fromJson).toList(growable: false);
}

int? _intOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _doubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
