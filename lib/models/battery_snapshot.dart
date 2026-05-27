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
