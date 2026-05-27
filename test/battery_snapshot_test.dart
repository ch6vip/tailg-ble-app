import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/constants.dart';
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
}
