import '../ble/constants.dart';

class BatterySnapshot {
  final int? percent;
  final double? voltage;
  final double? temperature;
  final int? signalStrength;
  final List<String> faults;
  final DateTime updatedAt;

  const BatterySnapshot({
    required this.percent,
    required this.voltage,
    required this.temperature,
    required this.signalStrength,
    required this.faults,
    required this.updatedAt,
  });

  bool get hasData =>
      percent != null ||
      voltage != null ||
      temperature != null ||
      signalStrength != null;

  double? get estimatedRangeKm =>
      percent == null ? null : (percent!.clamp(0, 100) * 0.65);

  BmsSnapshot get bms => BmsSnapshot.fromBatterySnapshot(this);

  String get healthLabel {
    if (faults.isNotEmpty) return '异常';
    final value = percent;
    if (value == null) return '等待数据';
    if (value <= 20) return '低电量';
    return '正常';
  }

  factory BatterySnapshot.fromBikeState(BikeState? state) {
    final faults = <String>[];
    if (state != null) {
      if (state.faultMotor) faults.add('电机故障');
      if (state.faultController) faults.add('控制器故障');
      if (state.faultBrake) faults.add('刹车故障');
      if (state.faultLowVoltage) faults.add('欠压保护');
    }
    return BatterySnapshot(
      percent: state?.batteryPercent,
      voltage: state?.voltage,
      temperature: state?.temperature,
      signalStrength: state?.signalStrength,
      faults: faults,
      updatedAt: DateTime.now(),
    );
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
  });

  factory BmsSnapshot.fromBatterySnapshot(BatterySnapshot snapshot) {
    return BmsSnapshot(
      soc: snapshot.percent?.toString(),
      currentBatteryVoltage: snapshot.voltage?.toStringAsFixed(1),
      batteryTemperature: snapshot.temperature?.toStringAsFixed(1),
    );
  }

  List<BmsField> get fields => [
    BmsField('估算容量', estimateBatteryCapacity, source: 'BMS'),
    BmsField('SOC', soc, unit: '%', source: 'feb3'),
    BmsField('SOH', soh, unit: '%', source: 'BMS'),
    BmsField('当前电压', currentBatteryVoltage, unit: 'V', source: 'feb3'),
    BmsField('充电状态', batteryChargeStatus, source: 'BMS'),
    BmsField('电池容量', batteryCapacity, source: 'BMS'),
    BmsField('电池电流', batteryCurrent, unit: 'A', source: 'BMS'),
    BmsField('环境温度', ambientTemperature, unit: '°C', source: 'BMS'),
    BmsField('循环次数', batteryCyclesNum, source: 'BMS'),
    BmsField('电池温度', batteryTemperature, unit: '°C', source: 'feb3'),
    BmsField('电池类型', batteryType, source: 'BMS'),
    BmsField('硬件版本', hwVer, source: 'BMS'),
    BmsField('软件版本', swVer, source: 'BMS'),
  ];
}

class BmsField {
  final String label;
  final String? value;
  final String? unit;
  final String source;

  const BmsField(this.label, this.value, {this.unit, required this.source});

  bool get hasValue => value != null && value!.trim().isNotEmpty;

  String get displayValue {
    if (!hasValue) return '待读取';
    return unit == null ? value! : '$value$unit';
  }
}
