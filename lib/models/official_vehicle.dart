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

  String get commandImei {
    final type = modelType;
    if (type != null && _gpsModelTypes.contains(type) && imeiGps.isNotEmpty) {
      return imeiGps;
    }
    return imei;
  }

  bool get isLocked => defenceStatus == 1;
  bool get isPowerOn => acc == 1;

  String get onlineLabel => online ? '在线' : '离线';
  String get defenceLabel => isLocked ? '已设防' : '已解防';
  String get powerLabel => isPowerOn ? '已上电' : '已断电';

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
