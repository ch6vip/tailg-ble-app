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
}
