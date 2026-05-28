import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/constants.dart';
import 'package:tailg_ble_app/ble/qgj_protocol.dart';
import 'package:tailg_ble_app/models/battery_snapshot.dart';

void main() {
  test('BatterySnapshot maps bike state into battery details', () {
    final snapshot = BatterySnapshot.fromBikeState(
      const BikeState(
        isLocked: true,
        isPowerOn: false,
        voltage: 48.5,
        temperature: 26.2,
        batteryPercent: 80,
        signalStrength: -55,
      ),
    );

    expect(snapshot.hasData, isTrue);
    expect(snapshot.healthLabel, '正常');
    expect(snapshot.estimatedRangeKm, 52);
    expect(snapshot.faults, isEmpty);
    expect(snapshot.bms.soc, '80');
    expect(snapshot.bms.currentBatteryVoltage, '48.5');
  });

  test('BmsSnapshot exposes official field structure without fake values', () {
    final snapshot = BatterySnapshot.fromBikeState(
      const BikeState(
        isLocked: true,
        isPowerOn: false,
        voltage: 48.5,
        batteryPercent: 80,
      ),
    );

    final fields = snapshot.bms.fields;
    expect(fields.map((field) => field.label), [
      '估算容量',
      'SOC',
      'SOH',
      '当前电压',
      '充电状态',
      '电池容量',
      '电池电流',
      '环境温度',
      '循环次数',
      '电池温度',
      '电池类型',
      '硬件版本',
      '软件版本',
    ]);
    expect(fields.first.displayValue, '待读取');
    expect(fields[1].displayValue, '80%');
    expect(fields[3].displayValue, '48.5V');
    expect(fields[8].displayValue, '待读取');
  });

  test('BikeState compares by value', () {
    const first = BikeState(
      isLocked: true,
      isPowerOn: false,
      voltage: 48.5,
      temperature: 26.2,
      batteryPercent: 80,
      signalStrength: -55,
    );
    const second = BikeState(
      isLocked: true,
      isPowerOn: false,
      voltage: 48.5,
      temperature: 26.2,
      batteryPercent: 80,
      signalStrength: -55,
    );

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('BikeState parses feb3 fault bits as active high', () {
    final normal = BikeState.fromFeb3([
      0x00,
      0x00,
      0x00,
      0x01,
      0xE5,
      0x00,
      0xD0,
    ]);
    final faulted = BikeState.fromFeb3([
      0x00,
      0x00,
      0x00,
      0x01,
      0xE5,
      0x35,
      0xD0,
    ]);

    expect(normal?.voltage, 48.5);
    expect(normal?.batteryPercent, 80);
    expect(normal?.faultMotor, isFalse);
    expect(normal?.faultController, isFalse);
    expect(normal?.faultBrake, isFalse);
    expect(normal?.faultLowVoltage, isFalse);
    expect(faulted?.faultMotor, isTrue);
    expect(faulted?.faultController, isTrue);
    expect(faulted?.faultBrake, isTrue);
    expect(faulted?.faultLowVoltage, isTrue);
  });

  test('QGJ riding mode frame preserves fcc1 status bytes', () {
    final frame = buildQgjRidingModeFrame([
      0x00,
      0x07,
      0x00,
      0x02,
      0xA0,
      0xF8,
      0x05,
    ], RidingMode.sport);

    expect(frame, [0x00, 0x07, 0x00, 0x02, 0xA0, 0xFB, 0x05]);
    expect(parseQgjRidingMode(frame!), RidingMode.sport);
  });

  test('QGJ login frame carries password and user id', () {
    final frame = buildQgjLoginFrame(password: 0x01020304, userId: 0x05060708);

    expect(frame, [
      0xA7,
      0x00,
      0x00,
      0x0A,
      0x10,
      0x01,
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
    ]);
  });
}
