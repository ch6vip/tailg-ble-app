import '../ble/constants.dart';

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
  });

  factory OfficialVehicle.fromJson(Map<String, dynamic> json) {
    return OfficialVehicle(
      imei: _string(json['imei']),
      imeiGps: _string(json['imeiGps']),
      carId: _string(json['carId']),
      carName: _string(json['carName']),
      carNickName: _string(json['carNickName']),
      carPhoto: _string(json['carPhoto']),
      frame: _string(json['frame']),
      defenceStatus: _intOrNull(json['defenceStatus']),
      acc: _intOrNull(json['acc']),
      electricQuantity: _intOrNull(json['electricQuantity']),
      voltage: _doubleOrNull(json['voltage']),
      online: _bool(json['online']),
      btname: _string(json['btname']),
      btmac: _string(json['btmac']),
      longitude: _string(json['longitude']),
      latitude: _string(json['latitude']),
      modelType: _intOrNull(json['modelType']),
      mileage: _doubleOrNull(json['mileage']),
    );
  }

  Map<String, dynamic> toJson() => {
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
  };

  String get key {
    if (carId.isNotEmpty) return carId;
    if (imei.isNotEmpty) return imei;
    if (imeiGps.isNotEmpty) return imeiGps;
    return '$btmac|$btname|$carName';
  }

  String get displayName {
    if (carNickName.trim().isNotEmpty) return carNickName.trim();
    if (carName.trim().isNotEmpty) return carName.trim();
    if (btname.trim().isNotEmpty) return btname.trim();
    if (frame.trim().isNotEmpty) return frame.trim();
    if (imei.trim().isNotEmpty) return imei.trim();
    return '官方车辆';
  }

  String get normalizedBtmac {
    final compact = btmac.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
    if (compact.length != 12) return '';
    final pairs = <String>[];
    for (var index = 0; index < compact.length; index += 2) {
      pairs.add(compact.substring(index, index + 2));
    }
    return pairs.join(':');
  }

  bool get hasBleIdentity => normalizedBtmac.isNotEmpty;

  String get commandImei {
    final type = modelType;
    if (type != null && _gpsModelTypes.contains(type) && imeiGps.isNotEmpty) {
      return imeiGps;
    }
    return imei;
  }

  bool get isLocked => defenceStatus == 1;
  bool get isPowerOn => acc == 1;

  String get onlineLabel => online ? '车辆在线' : '车辆离线';
  String get defenceLabel => isLocked ? '已设防' : '已解防';
  String get powerLabel => isPowerOn ? '车辆已启动' : '车辆未启动';

  static String _string(Object? value) => value?.toString().trim() ?? '';

  static bool _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    return text == 'true' || text == '1';
  }

  static int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _doubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
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
      raw: Map<String, dynamic>.from(json),
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
      raw: Map<String, dynamic>.from(json),
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
    final list = json['deviceTravelDtoList'];
    return OfficialTravelDay(
      raw: Map<String, dynamic>.from(json),
      sec: _clean(json['sec']) ?? '',
      hours: _clean(json['hours']) ?? '',
      min: _clean(json['min']) ?? '',
      travelDate: _clean(json['travelDate']) ?? '',
      totalTime: _clean(json['totalTime']) ?? '',
      records: list is List
          ? list
                .whereType<Map>()
                .map(
                  (item) => OfficialTravelRecord.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
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
      raw: Map<String, dynamic>.from(json),
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

  String get mileageLabel => mileage.isEmpty ? '待读取' : '${mileage}km';
  String get averageSpeedLabel =>
      averageSpeed.isEmpty ? '待读取' : '${averageSpeed}km/h';
  String get maxSpeedLabel => maxSpeed.isEmpty ? '待读取' : '${maxSpeed}km/h';
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
      raw: Map<String, dynamic>.from(json),
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
    final dumpEnergyPercent = _cleanBatteryText(json['dumpEnergyPercent']);
    return OfficialBatteryInfo(
      raw: Map<String, dynamic>.from(json),
      dumpEnergyPercent: dumpEnergyPercent ?? '',
      dumpEnergyPercentLabel:
          _cleanBatteryText(json['dumpEnergyPercentLabel']) ??
          (dumpEnergyPercent == null ? null : '$dumpEnergyPercent%') ??
          '',
      remainingMileage: _cleanBatteryText(json['remainingMileage']) ?? '',
      mileage: _cleanBatteryText(json['mileage']) ?? '',
      capacitance: _cleanBatteryText(json['capacitance']) ?? '',
      consumePowerPercent: _cleanBatteryText(json['consumePowerPercent']) ?? '',
      loopCount: _cleanBatteryText(json['loopCount']) ?? '',
      temperature: _cleanBatteryText(json['temperature']) ?? '',
      batteryScore: _cleanBatteryText(json['batteryScore']) ?? '',
      voltage: _cleanBatteryText(json['voltage']) ?? '',
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

  static String? _cleanBatteryText(Object? value) => _clean(value);
}

String? _clean(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text == '--' || text.toLowerCase() == 'null') {
    return null;
  }
  return text;
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
      raw: Map<String, dynamic>.from(json),
      code: OfficialVehicle._intOrNull(json['code']),
      message: json['msg']?.toString() ?? '',
      data: json['data'],
    );
  }

  bool get hasData => data != null;

  Map<String, dynamic> get dataMap {
    final value = data;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String get displayMessage {
    if (message.trim().isNotEmpty) return message.trim();
    if (code != null) return 'code=$code';
    return '自检已返回';
  }
}
