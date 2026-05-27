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
      0x01,
      0x06,
      0xC9,
      0x00,
      80,
    ]);
    final faulted = BikeState.fromFeb3([
      0x00,
      0x00,
      0x00,
      0x01,
      0xE5,
      0x01,
      0x06,
      0xC9,
      0x35,
      80,
    ]);

    expect(normal?.faultMotor, isFalse);
    expect(normal?.faultController, isFalse);
    expect(normal?.faultBrake, isFalse);
    expect(normal?.faultLowVoltage, isFalse);
    expect(faulted?.faultMotor, isTrue);
    expect(faulted?.faultController, isTrue);
    expect(faulted?.faultBrake, isTrue);
    expect(faulted?.faultLowVoltage, isTrue);
  });
}
