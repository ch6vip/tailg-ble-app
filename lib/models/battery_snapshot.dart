import 'official_vehicle.dart';

enum BatteryDataSource {
  officialVehicle('官方车辆状态'),
  officialBattery('官方电池接口'),
  bmsReserved('官方字段预留');

  final String label;

  const BatteryDataSource(this.label);
}

class BatterySnapshot {
  static const _kmPerPercent = 0.65;
  static final RegExp _numberPattern = RegExp(r'-?\d+(\.\d+)?');

  final int? percent;
  final double? voltage;
  final double? temperature;
  final int? signalStrength;
  final List<String> faults;
  final DateTime updatedAt;
  final String? remainingMileage;
  final String? totalMileage;
  final String? capacitance;
  final String? consumePowerPercent;
  final String? loopCount;
  final String? batteryScore;
  final OfficialVehicle? officialVehicle;
  final OfficialBatteryInfo? officialBatteryInfo;
  final BatteryDataSource percentSource;
  final BatteryDataSource voltageSource;
  final BatteryDataSource temperatureSource;
  final BatteryDataSource mileageSource;

  const BatterySnapshot({
    required this.percent,
    required this.voltage,
    required this.temperature,
    required this.signalStrength,
    required this.faults,
    required this.updatedAt,
    required this.remainingMileage,
    required this.totalMileage,
    required this.capacitance,
    required this.consumePowerPercent,
    required this.loopCount,
    required this.batteryScore,
    required this.officialVehicle,
    required this.officialBatteryInfo,
    required this.percentSource,
    required this.voltageSource,
    required this.temperatureSource,
    required this.mileageSource,
  });

  bool get hasData =>
      percent != null ||
      voltage != null ||
      temperature != null ||
      signalStrength != null ||
      hasOfficialBatteryInfo ||
      officialVehicle != null;

  bool get hasOfficialBatteryInfo => officialBatteryInfo?.hasData == true;

  String get dataSourceLabel {
    final labels = <String>{};
    if (percent != null) labels.add(percentSource.label);
    if (voltage != null) labels.add(voltageSource.label);
    if (temperature != null) labels.add(temperatureSource.label);
    if (hasOfficialBatteryInfo) {
      labels.add(BatteryDataSource.officialBattery.label);
    }
    if (officialVehicle != null) {
      labels.add(BatteryDataSource.officialVehicle.label);
    }
    if (labels.isEmpty) return '等待数据';
    return labels.join(' / ');
  }

  double? get estimatedRangeKm {
    final officialRange = _parseNumber(remainingMileage);
    if (officialRange != null) return officialRange;
    final value = percent;
    return value == null ? null : value.clamp(0, 100) * _kmPerPercent;
  }

  BmsSnapshot get bms => BmsSnapshot.fromBatterySnapshot(this);

  String get healthLabel {
    if (faults.isNotEmpty) return '异常';
    final value = percent;
    if (value == null) return '等待数据';
    if (value <= 20) return '低电量';
    return '正常';
  }

  factory BatterySnapshot.fromSources({
    OfficialVehicle? officialVehicle,
    OfficialBatteryInfo? officialBatteryInfo,
    DateTime? updatedAt,
    DateTime Function()? clock,
  }) {
    final officialPercent = _parsePercent(
      officialBatteryInfo?.dumpEnergyPercent,
    );
    final vehiclePercent = officialVehicle?.electricQuantity;
    final officialVoltage = _parseNumber(officialBatteryInfo?.voltage);
    final vehicleVoltage = officialVehicle?.voltage;
    final officialTemperature = _parseNumber(officialBatteryInfo?.temperature);
    final vehicleMileage = officialVehicle?.mileage;
    final officialRemainingMileage = _cleanText(
      officialBatteryInfo?.remainingMileage,
    );

    final percent = (officialPercent ?? vehiclePercent)?.clamp(0, 100);
    final voltage = officialVoltage ?? vehicleVoltage;
    final temperature = officialTemperature;
    final remainingMileage = _firstText([
      officialRemainingMileage,
      _estimatedMileageText(percent),
    ]);
    final totalMileage = _firstText([
      officialBatteryInfo?.mileage,
      vehicleMileage?.toStringAsFixed(1),
    ]);

    return BatterySnapshot(
      percent: percent,
      voltage: voltage,
      temperature: temperature,
      signalStrength: null,
      faults: const [],
      updatedAt: updatedAt ?? (clock ?? DateTime.now)(),
      remainingMileage: remainingMileage,
      totalMileage: totalMileage,
      capacitance: _cleanText(officialBatteryInfo?.capacitance),
      consumePowerPercent: _cleanText(officialBatteryInfo?.consumePowerPercent),
      loopCount: _cleanText(officialBatteryInfo?.loopCount),
      batteryScore: _cleanText(officialBatteryInfo?.batteryScore),
      officialVehicle: officialVehicle,
      officialBatteryInfo: officialBatteryInfo,
      percentSource: _dataSource(
        officialBatteryValue: officialPercent,
        officialVehicleValue: vehiclePercent,
      ),
      voltageSource: _dataSource(
        officialBatteryValue: officialVoltage,
        officialVehicleValue: vehicleVoltage,
      ),
      temperatureSource: _dataSource(officialBatteryValue: officialTemperature),
      mileageSource: _mileageSource(
        officialRemainingMileage: officialRemainingMileage,
        vehicleMileage: vehicleMileage,
        percent: percent,
      ),
    );
  }

  static int? _parsePercent(String? value) {
    final parsed = _parseNumber(value?.replaceAll('%', ''));
    return parsed?.round().clamp(0, 100);
  }

  static double? _parseNumber(String? value) {
    final cleaned = _cleanText(value);
    if (cleaned == null) return null;
    final match = _numberPattern.firstMatch(cleaned);
    if (match == null) return null;
    final text = match.group(0);
    return text == null ? null : double.tryParse(text);
  }

  static String? _firstText(List<String?> values) {
    for (final value in values) {
      final cleaned = _cleanText(value);
      if (cleaned != null) return cleaned;
    }
    return null;
  }

  static String? _cleanText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty || text == '--') return null;
    return text;
  }

  static String? _estimatedMileageText(int? percent) {
    final value = percent?.clamp(0, 100).toDouble();
    return value == null ? null : (value * _kmPerPercent).toStringAsFixed(1);
  }
}

BatteryDataSource _dataSource({
  Object? officialBatteryValue,
  Object? officialVehicleValue,
}) {
  if (officialBatteryValue != null) return BatteryDataSource.officialBattery;
  if (officialVehicleValue != null) return BatteryDataSource.officialVehicle;
  return BatteryDataSource.bmsReserved;
}

BatteryDataSource _mileageSource({
  required String? officialRemainingMileage,
  required double? vehicleMileage,
  required int? percent,
}) {
  if (officialRemainingMileage != null) {
    return BatteryDataSource.officialBattery;
  }
  if (vehicleMileage != null) return BatteryDataSource.officialVehicle;
  return BatteryDataSource.bmsReserved;
}

class BmsSnapshot {
  final String? estimateBatteryCapacity;
  final String? soc;
  final String? soh;
  final String? currentBatteryVoltage;
  final String? batteryChargeStatus;
  final String? batteryCapacity;
  final String? batteryCurrent;
  final String? ambientTemperature;
  final String? batteryCyclesNum;
  final String? batteryTemperature;
  final String? batteryType;
  final String? hwVer;
  final String? swVer;
  final String? remainingMileage;
  final String? totalMileage;
  final String? consumePowerPercent;
  final String? batteryScore;
  final BatteryDataSource socSource;
  final BatteryDataSource voltageSource;
  final BatteryDataSource temperatureSource;

  const BmsSnapshot({
    this.estimateBatteryCapacity,
    this.soc,
    this.soh,
    this.currentBatteryVoltage,
    this.batteryChargeStatus,
    this.batteryCapacity,
    this.batteryCurrent,
    this.ambientTemperature,
    this.batteryCyclesNum,
    this.batteryTemperature,
    this.batteryType,
    this.hwVer,
    this.swVer,
    this.remainingMileage,
    this.totalMileage,
    this.consumePowerPercent,
    this.batteryScore,
    this.socSource = BatteryDataSource.bmsReserved,
    this.voltageSource = BatteryDataSource.bmsReserved,
    this.temperatureSource = BatteryDataSource.bmsReserved,
  });

  factory BmsSnapshot.fromBatterySnapshot(BatterySnapshot snapshot) {
    return BmsSnapshot(
      estimateBatteryCapacity: snapshot.capacitance,
      soc: snapshot.percent?.toString(),
      currentBatteryVoltage: snapshot.voltage?.toStringAsFixed(1),
      batteryCapacity: snapshot.capacitance,
      batteryCyclesNum: snapshot.loopCount,
      batteryTemperature: snapshot.temperature?.toStringAsFixed(1),
      remainingMileage: snapshot.remainingMileage,
      totalMileage: snapshot.totalMileage,
      consumePowerPercent: snapshot.consumePowerPercent,
      batteryScore: snapshot.batteryScore,
      socSource: snapshot.percentSource,
      voltageSource: snapshot.voltageSource,
      temperatureSource: snapshot.temperatureSource,
    );
  }

  List<BmsField> get fields => _bmsFields(this);
}

List<BmsField> _bmsFields(BmsSnapshot snapshot) {
  return [
    BmsField(
      '估算容量',
      snapshot.estimateBatteryCapacity,
      source: BatteryDataSource.officialBattery,
    ),
    BmsField('SOC', snapshot.soc, unit: '%', source: snapshot.socSource),
    BmsField(
      'SOH',
      snapshot.soh,
      unit: '%',
      source: BatteryDataSource.bmsReserved,
    ),
    BmsField(
      '当前电压',
      snapshot.currentBatteryVoltage,
      unit: 'V',
      source: snapshot.voltageSource,
    ),
    BmsField(
      '充电状态',
      snapshot.batteryChargeStatus,
      source: BatteryDataSource.bmsReserved,
    ),
    BmsField(
      '电池容量',
      snapshot.batteryCapacity,
      source: BatteryDataSource.officialBattery,
    ),
    BmsField(
      '电池电流',
      snapshot.batteryCurrent,
      unit: 'A',
      source: BatteryDataSource.bmsReserved,
    ),
    BmsField(
      '环境温度',
      snapshot.ambientTemperature,
      unit: '°C',
      source: BatteryDataSource.bmsReserved,
    ),
    BmsField(
      '循环次数',
      snapshot.batteryCyclesNum,
      source: BatteryDataSource.officialBattery,
    ),
    BmsField(
      '电池温度',
      snapshot.batteryTemperature,
      unit: '°C',
      source: snapshot.temperatureSource,
    ),
    BmsField(
      '电池类型',
      snapshot.batteryType,
      source: BatteryDataSource.bmsReserved,
    ),
    BmsField('硬件版本', snapshot.hwVer, source: BatteryDataSource.bmsReserved),
    BmsField('软件版本', snapshot.swVer, source: BatteryDataSource.bmsReserved),
  ];
}

class BmsField {
  final String label;
  final String? value;
  final String? unit;
  final BatteryDataSource source;

  const BmsField(this.label, this.value, {this.unit, required this.source});

  bool get hasValue {
    final text = value?.trim();
    return text != null && text.isNotEmpty;
  }

  String get displayValue {
    final text = value;
    if (text == null || text.trim().isEmpty) return '待读取';
    return unit == null ? text : '$text$unit';
  }
}
