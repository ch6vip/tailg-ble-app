import '../ble/constants.dart';
import 'official_vehicle.dart';

enum BatteryDataSource {
  ble('BLE feb3 已确认'),
  officialVehicle('官方车辆状态'),
  officialBattery('官方电池接口'),
  bmsReserved('官方字段预留');

  final String label;

  const BatteryDataSource(this.label);
}

class BatterySnapshot {
  static const _kmPerPercent = 0.65;

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
    return percent == null ? null : (percent!.clamp(0, 100) * _kmPerPercent);
  }

  BmsSnapshot get bms => BmsSnapshot.fromBatterySnapshot(this);

  String get healthLabel {
    if (faults.isNotEmpty) return '异常';
    final value = percent;
    if (value == null) return '等待数据';
    if (value <= 20) return '低电量';
    return '正常';
  }

  factory BatterySnapshot.fromBikeState(BikeState? state) {
    return BatterySnapshot.fromSources(bikeState: state);
  }

  factory BatterySnapshot.fromSources({
    BikeState? bikeState,
    OfficialVehicle? officialVehicle,
    OfficialBatteryInfo? officialBatteryInfo,
  }) {
    final faults = <String>[];
    if (bikeState != null) {
      if (bikeState.faultMotor) faults.add('电机故障');
      if (bikeState.faultController) faults.add('控制器故障');
      if (bikeState.faultBrake) faults.add('刹车故障');
      if (bikeState.faultLowVoltage) faults.add('欠压保护');
    }

    final officialPercent = _parsePercent(
      officialBatteryInfo?.dumpEnergyPercent,
    );
    final vehiclePercent = officialVehicle?.electricQuantity;
    final officialVoltage = _parseNumber(officialBatteryInfo?.voltage);
    final vehicleVoltage = officialVehicle?.voltage;
    final officialTemperature = _parseNumber(officialBatteryInfo?.temperature);
    final vehicleMileage = officialVehicle?.mileage;

    final rawPercent =
        bikeState?.batteryPercent ?? officialPercent ?? vehiclePercent;
    final percent = rawPercent?.clamp(0, 100);
    final voltage = bikeState?.voltage ?? officialVoltage ?? vehicleVoltage;
    final temperature = bikeState?.temperature ?? officialTemperature;
    final remainingMileage = _firstText([
      officialBatteryInfo?.remainingMileage,
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
      signalStrength: bikeState?.signalStrength,
      faults: faults,
      updatedAt: DateTime.now(),
      remainingMileage: remainingMileage,
      totalMileage: totalMileage,
      capacitance: _cleanText(officialBatteryInfo?.capacitance),
      consumePowerPercent: _cleanText(officialBatteryInfo?.consumePowerPercent),
      loopCount: _cleanText(officialBatteryInfo?.loopCount),
      batteryScore: _cleanText(officialBatteryInfo?.batteryScore),
      officialVehicle: officialVehicle,
      officialBatteryInfo: officialBatteryInfo,
      percentSource: bikeState?.batteryPercent != null
          ? BatteryDataSource.ble
          : officialPercent != null
          ? BatteryDataSource.officialBattery
          : vehiclePercent != null
          ? BatteryDataSource.officialVehicle
          : BatteryDataSource.bmsReserved,
      voltageSource: bikeState?.voltage != null
          ? BatteryDataSource.ble
          : officialVoltage != null
          ? BatteryDataSource.officialBattery
          : vehicleVoltage != null
          ? BatteryDataSource.officialVehicle
          : BatteryDataSource.bmsReserved,
      temperatureSource: bikeState?.temperature != null
          ? BatteryDataSource.ble
          : officialTemperature != null
          ? BatteryDataSource.officialBattery
          : BatteryDataSource.bmsReserved,
      mileageSource:
          _cleanText(officialBatteryInfo?.remainingMileage)?.isNotEmpty == true
          ? BatteryDataSource.officialBattery
          : vehicleMileage != null
          ? BatteryDataSource.officialVehicle
          : percent != null
          ? BatteryDataSource.ble
          : BatteryDataSource.bmsReserved,
    );
  }

  static int? _parsePercent(String? value) {
    final parsed = _parseNumber(value?.replaceAll('%', ''));
    return parsed?.round().clamp(0, 100).toInt();
  }

  static double? _parseNumber(String? value) {
    final cleaned = _cleanText(value);
    if (cleaned == null) return null;
    final match = RegExp(r'-?\d+(\.\d+)?').firstMatch(cleaned);
    if (match == null) return null;
    return double.tryParse(match.group(0)!);
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

  List<BmsField> get fields => [
    BmsField(
      '估算容量',
      estimateBatteryCapacity,
      source: BatteryDataSource.officialBattery,
    ),
    BmsField('SOC', soc, unit: '%', source: socSource),
    BmsField('SOH', soh, unit: '%', source: BatteryDataSource.bmsReserved),
    BmsField('当前电压', currentBatteryVoltage, unit: 'V', source: voltageSource),
    BmsField(
      '充电状态',
      batteryChargeStatus,
      source: BatteryDataSource.bmsReserved,
    ),
    BmsField(
      '电池容量',
      batteryCapacity,
      source: BatteryDataSource.officialBattery,
    ),
    BmsField(
      '电池电流',
      batteryCurrent,
      unit: 'A',
      source: BatteryDataSource.bmsReserved,
    ),
    BmsField(
      '环境温度',
      ambientTemperature,
      unit: '°C',
      source: BatteryDataSource.bmsReserved,
    ),
    BmsField(
      '循环次数',
      batteryCyclesNum,
      source: BatteryDataSource.officialBattery,
    ),
    BmsField('电池温度', batteryTemperature, unit: '°C', source: temperatureSource),
    BmsField('电池类型', batteryType, source: BatteryDataSource.bmsReserved),
    BmsField('硬件版本', hwVer, source: BatteryDataSource.bmsReserved),
    BmsField('软件版本', swVer, source: BatteryDataSource.bmsReserved),
  ];
}

class BmsField {
  final String label;
  final String? value;
  final String? unit;
  final BatteryDataSource source;

  const BmsField(this.label, this.value, {this.unit, required this.source});

  bool get hasValue => value != null && value!.trim().isNotEmpty;

  String get displayValue {
    if (!hasValue) return '待读取';
    return unit == null ? value! : '$value$unit';
  }
}
