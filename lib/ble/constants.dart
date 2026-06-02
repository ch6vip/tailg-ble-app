enum CommandCode {
  lock('01', '设防'),
  unlock('02', '解锁'),
  openSeat('05', '开座桶'),
  powerOn('06', '启动'),
  powerOff('07', '熄火'),
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
  eco(0, '超能跑'),
  standard(1, '全速跑'),
  sport(2, '超速跑');

  final int code;
  final String label;
  const RidingMode(this.code, this.label);

  int get qgjPodgValue => code + 1;

  static RidingMode? fromQgjPodgValue(int value) {
    return switch (value) {
      1 => RidingMode.eco,
      2 => RidingMode.standard,
      3 => RidingMode.sport,
      _ => null,
    };
  }
}

class BleUuids {
  static const serviceFee5 = '0000fee5-0000-1000-8000-00805f9b34fb';
  static const serviceFcc0 = '0000fcc0-0000-1000-8000-00805f9b34fb';
  static const serviceFe01 = '0000fe01-0000-1000-8000-00805f9b34fb';
  static const serviceFeb0 = '0000feb0-0000-1000-8000-00805f9b34fb';
  static const serviceOta = '00002600-0000-1000-8000-00805f9b34fb';
  static const writeChar = '0000feb5-0000-1000-8000-00805f9b34fb';
  static const notifyChar = '0000feb6-0000-1000-8000-00805f9b34fb';
  static const feb1 = '0000feb1-0000-1000-8000-00805f9b34fb';
  static const feb2 = '0000feb2-0000-1000-8000-00805f9b34fb';
  static const feb3 = '0000feb3-0000-1000-8000-00805f9b34fb';
  static const fe02 = '0000fe02-0000-1000-8000-00805f9b34fb';
  static const fe03 = '0000fe03-0000-1000-8000-00805f9b34fb';
  static const fcc1 = '0000fcc1-0000-1000-8000-00805f9b34fb';
  static const fcc2 = '0000fcc2-0000-1000-8000-00805f9b34fb';
  static const fbb1 = '0000fbb1-0000-1000-8000-00805f9b34fb';
  static const fbb2 = '0000fbb2-0000-1000-8000-00805f9b34fb';
  static const otaOrder = '00007000-0000-1000-8000-00805f9b34fb';
  static const otaFile = '00007001-0000-1000-8000-00805f9b34fb';
}

class BleTimings {
  static const connectTimeout = Duration(seconds: 10);
  static const reconnectConnectTimeout = Duration(seconds: 8);
  static const initialConnectRetryDelay = Duration(milliseconds: 500);
  static const failedConnectRecoveryDelay = Duration(milliseconds: 600);
  static const androidGattErrorRecoveryDelay = Duration(milliseconds: 1200);
  static const qgjRequestedMtu = 515;
  static const autoConnectScanTimeout = Duration(seconds: 8);
  static const manualScanTimeout = Duration(seconds: 30);
  static const proximityScanTimeout = Duration(seconds: 30);
  static const serviceSetupDelay = Duration(milliseconds: 500);
  static const heartbeatInitialDelay = Duration(milliseconds: 500);
  static const heartbeatInterval = Duration(seconds: 5);
  static const qgjStatusPollInterval = Duration(seconds: 1);
  static const commandAckTimeout = Duration(seconds: 5);
  static const fccReadbackDelay = Duration(milliseconds: 200);
  static const fccRetryDelay = Duration(milliseconds: 500);
  static const locationCaptureTimeout = Duration(seconds: 8);
  static const silentLocationThrottle = Duration(seconds: 60);
  static const qgjSearchCountdown = Duration(seconds: 30);
  static const gpsSearchCountdown = Duration(seconds: 6);
}

class QgjCommandHeaders {
  static const checkSound = [0x85, 0x03, 0x4A, 0x3C];
  static const setSound = [0x85, 0x06, 0x4A, 0x3C];
  static const checkSensitivity = [0x85, 0x03, 0x4A, 0x36];
  static const setSensitivity = [0x85, 0x04, 0x4A, 0x36];
  static const inductionStatus = [0x85, 0x03, 0x4A, 0x33];
  static const inductionSet = [0x85, 0x04, 0x4A, 0x33];
  static const autoLockSearch = [0x85, 0x03, 0x4A, 0x30];
  static const autoLockSet = [0x85, 0x05, 0x4A, 0x30];
}

class QgjCommandIds {
  static const login = 0x1001;
  static const setStatus = 0x1002;
  static const autoLockTimeGet = 0x2000;
  static const autoLockTimeSet = 0x2001;
  static const autoLockGet = autoLockTimeGet;
  static const autoLockSet = autoLockTimeSet;
  static const powerOnAutoLockTimeGet = 0x2010;
  static const powerOnAutoLockTimeSet = 0x2011;
  static const proximityStatusGet = 0x2030;
  static const proximityStatusSet = 0x2031;
  static const proximityDistanceGet = 0x2032;
  static const proximityDistanceSet = 0x2033;
  static const handlebarLockSet = 0x2050;
  static const handlebarLockGet = 0x2051;
  static const vibrateSensitivityGet = 0x2060;
  static const vibrateSensitivitySet = 0x2061;
  static const postureDetectionSet = 0x2070;
  static const postureDetectionGet = 0x2071;
  static const passwordUnlockGet = 0x2080;
  static const passwordUnlockSet = 0x2081;
  static const hidStatusSet = 0x2140;
  static const hidStatusGet = 0x2142;
  static const safeLockSet = 0x2360;
  static const safeLockGet = 0x2361;
  static const kickstandSet = 0x2370;
  static const kickstandGet = 0x2371;
  static const seatSensorSet = 0x2400;
  static const seatSensorGet = 0x2401;
  static const lightSensorSet = 0x2410;
  static const lightSensorGet = 0x2411;
  static const soundAdjustGet = 0x2420;
  static const soundAdjustSet = 0x2421;
  static const enterOtaMode = 0x5004;
}

class QgjHidModes {
  static const close = 0;
  static const open = 1;
  static const openWithAutoLock = 2;
}

class QgjSoundIndexes {
  static const lock = 1;
  static const unlock = 3;
  static const start = 14;
  static const stop = 15;
  static const speed = 17;
  static const all = 255;

  static const known = <int>[lock, unlock, start, stop, speed];
}

class QgjControlOpCodes {
  static const byCommandCode = <String, int>{
    '01': 0x02, // lock
    '02': 0x01, // unlock
    '05': 0x07, // open seat
    '06': 0x03, // power on
    '07': 0x04, // power off
    '08': 0x08, // find
  };
}

List<int>? extractFcc1StatusBytes(List<int> data) {
  if (data.length >= 11) {
    return [data[8], data[9], data[10]];
  }
  if (data.length >= 7 && data[0] == 0x00 && data[1] == 0x07) {
    return [data[4], data[5], data[6]];
  }
  return null;
}

RidingMode? parseQgjRidingMode(List<int> data) {
  final status = extractFcc1StatusBytes(data);
  if (status == null) return null;
  return RidingMode.fromQgjPodgValue(status[1] & 0x07);
}

List<int>? buildQgjRidingModeFrame(List<int> readback, RidingMode mode) {
  final status = extractFcc1StatusBytes(readback);
  if (status == null) return null;
  final state2 = (status[1] & 0xF8) | mode.qgjPodgValue;
  return [0x00, 0x07, 0x00, 0x02, status[0], state2, status[2]];
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
    if (data.length < 6) return null;

    final status1 = data[0];
    final isLocked = (status1 & 0x01) != 0;
    final isPowerOn = (status1 & 0x02) != 0;
    final isMuted = (status1 & 0x04) != 0;

    final voltageRaw = (data[3] << 8) | data[4];
    final voltage = voltageRaw / 10.0;

    final faults = data[5];
    final faultMotor = (faults & 0x01) != 0;
    final faultController = (faults & 0x04) != 0;
    final faultBrake = (faults & 0x10) != 0;
    final faultLowVoltage = (faults & 0x20) != 0;

    final batteryRaw = data.length > 6 ? data[6] : null;
    final batteryValue = batteryRaw == null ? null : batteryRaw & 0x7F;
    final batteryPercent = batteryRaw != null && (batteryRaw & 0x80) != 0
        ? (batteryValue! > 100 ? 100 : batteryValue)
        : null;

    return BikeState(
      isLocked: isLocked,
      isPowerOn: isPowerOn,
      isMuted: isMuted,
      voltage: voltage > 0 ? voltage : null,
      temperature: null,
      batteryPercent: batteryPercent,
      faultMotor: faultMotor,
      faultController: faultController,
      faultBrake: faultBrake,
      faultLowVoltage: faultLowVoltage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BikeState &&
          runtimeType == other.runtimeType &&
          isLocked == other.isLocked &&
          isPowerOn == other.isPowerOn &&
          isMuted == other.isMuted &&
          voltage == other.voltage &&
          temperature == other.temperature &&
          batteryPercent == other.batteryPercent &&
          signalStrength == other.signalStrength &&
          faultMotor == other.faultMotor &&
          faultController == other.faultController &&
          faultBrake == other.faultBrake &&
          faultLowVoltage == other.faultLowVoltage;

  @override
  int get hashCode => Object.hash(
    isLocked,
    isPowerOn,
    isMuted,
    voltage,
    temperature,
    batteryPercent,
    signalStrength,
    faultMotor,
    faultController,
    faultBrake,
    faultLowVoltage,
  );
}
