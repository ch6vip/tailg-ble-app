import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/vehicle_settings_service.dart';

void main() {
  test('VehicleSettingsSnapshot parses light state', () {
    final snapshot = VehicleSettingsSnapshot.parse([
      0x00,
      0x07,
      0x00,
      0x02,
      0x03,
      0x00,
      0x00,
    ]);

    expect(snapshot?.headlight, isTrue);
    expect(snapshot?.turnSignal, isTrue);
    expect(snapshot?.hasLightState, isTrue);
  });

  test('VehicleSettingsSnapshot parses sound state', () {
    final snapshot = VehicleSettingsSnapshot.parse([
      0x85,
      0x06,
      0x4A,
      0x3C,
      0x02,
      0x01,
      0x00,
      0x01,
      0x00,
      0x01,
      0x04,
    ]);

    expect(snapshot?.powerOnSound, isTrue);
    expect(snapshot?.startupSound, isFalse);
    expect(snapshot?.unlockSound, isTrue);
    expect(snapshot?.lockSound, isFalse);
    expect(snapshot?.buzzerVolume, 4);
    expect(snapshot?.hasSoundState, isTrue);
  });
}
