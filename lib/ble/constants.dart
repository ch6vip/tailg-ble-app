enum CommandCode {
  lock('01', '设防'),
  unlock('02', '解锁'),
  openSeat('05', '开座桶'),
  powerOn('06', '通电'),
  powerOff('07', '断电'),
  find('08', '寻车'),
  readState('0D', '读取状态'),
  readAntiTheft('0E', '读取防盗');

  final String code;
  final String label;
  const CommandCode(this.code, this.label);
}

enum ModelType {
  KKS('3A60432A5C01211F291E0F4E0C132825'),
  BB('1AF78CD35BE92F4CA06DB89EC2D7EF01'),
  AX('1AF78CD35BE92F4CA06DB89E7C4B1E6A'),
  JD('1AF78CD35BE92F4CA06DB89E5F3D2A8C'),
  HJ('1AF78CD35BE92F4CA06DB89E9E6C4B1A'),
  JW('1AF78CD35BE92F4CA06DB89E6F8B39A5'),
  XL('1AF78CD35BE92F4CA06DB89E1E6C8A9A'),
  YY('1AF78CD35BE92F4CA06DB89E2A8C3F5D');

  final String aesKey;
  const ModelType(this.aesKey);
}

enum RidingMode {
  eco(0, '节能'),
  standard(1, '标准'),
  sport(2, '强力');

  final int code;
  final String label;
  const RidingMode(this.code, this.label);
}

class BleUuids {
  static const serviceFee5 = '0000fee5-0000-1000-8000-00805f9b34fb';
  static const serviceFcc0 = '0000fcc0-0000-1000-8000-00805f9b34fb';
  static const serviceFe01 = '0000fe01-0000-1000-8000-00805f9b34fb';
  static const serviceFeb0 = '0000feb0-0000-1000-8000-00805f9b34fb';
  static const writeChar = '0000feb5-0000-1000-8000-00805f9b34fb';
  static const notifyChar = '0000feb6-0000-1000-8000-00805f9b34fb';
  static const feb1 = '0000feb1-0000-1000-8000-00805f9b34fb';
  static const feb2 = '0000feb2-0000-1000-8000-00805f9b34fb';
  static const feb3 = '0000feb3-0000-1000-8000-00805f9b34fb';
  static const fcc1 = '0000fcc1-0000-1000-8000-00805f9b34fb';
}

class BikeState {
  final bool isLocked;
  final bool isPowerOn;
  final bool isMuted;
  final double? voltage;
  final double? temperature;
  final int? batteryPercent;
  final int? signalStrength;
  final bool faultMotor;
  final bool faultController;
  final bool faultBrake;
  final bool faultLowVoltage;

  const BikeState({
    required this.isLocked,
    required this.isPowerOn,
    this.isMuted = false,
    this.voltage,
    this.temperature,
    this.batteryPercent,
    this.signalStrength,
    this.faultMotor = false,
    this.faultController = false,
    this.faultBrake = false,
    this.faultLowVoltage = false,
  });

  static BikeState? fromFeb3(List<int> data) {
    if (data.length < 10) return null;

    final status1 = data[0];
    final isLocked = (status1 & 0x01) != 0;
    final isPowerOn = (status1 & 0x02) != 0;
    final isMuted = (status1 & 0x04) != 0;

    final voltageRaw = (data[3] << 8) | data[4];
    final voltage = voltageRaw / 10.0;

    final tempRaw = (data[5] << 8) | data[6];
    final temperature = tempRaw / 10.0;

    final signalStrength = data[7].toSigned(8);

    final faults = data[8];
    final faultMotor = (faults & 0x01) == 0;
    final faultController = (faults & 0x04) == 0;
    final faultBrake = (faults & 0x10) == 0;
    final faultLowVoltage = (faults & 0x20) == 0;

    final batteryPercent = data[9].clamp(0, 100);

    return BikeState(
      isLocked: isLocked,
      isPowerOn: isPowerOn,
      isMuted: isMuted,
      voltage: voltage > 0 ? voltage : null,
      temperature: temperature > 0 ? temperature : null,
      batteryPercent: batteryPercent,
      signalStrength: signalStrength,
      faultMotor: faultMotor,
      faultController: faultController,
      faultBrake: faultBrake,
      faultLowVoltage: faultLowVoltage,
    );
  }
}
