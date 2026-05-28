import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/constants.dart';
import 'package:tailg_ble_app/ble/qgj_protocol.dart';
import 'package:tailg_ble_app/services/vehicle_settings_service.dart';

void main() {
  test(
    'VehicleSettingsSnapshot does not treat short fcc1 state as light state',
    () {
      final snapshot = VehicleSettingsSnapshot.parse([
        0x00,
        0x07,
        0x00,
        0x02,
        0x03,
        0x00,
        0x00,
      ]);

      expect(snapshot, isNull);
    },
  );

  test(
    'VehicleSettingsSnapshot does not treat long fcc1 readback as light state',
    () {
      final snapshot = VehicleSettingsSnapshot.parse([
        0x00,
        0x07,
        0x00,
        0x08,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0x03,
        0x02,
        0x00,
        0x00,
      ]);

      expect(snapshot, isNull);
    },
  );

  test('QGJ official setting command frames use decompiled command ids', () {
    expect(
      buildQgjCommand(QgjCommandIds.lightSensorSet, Uint8List.fromList([1])),
      [0xA7, 0x00, 0x00, 0x03, 0x24, 0x10, 0x01],
    );
    expect(
      buildQgjCommand(
        QgjCommandIds.soundAdjustGet,
        Uint8List.fromList(buildSoundAdjustGetPayload()),
      ),
      [0xA7, 0x00, 0x00, 0x03, 0x24, 0x20, 0xFF],
    );
    expect(
      buildQgjCommand(
        QgjCommandIds.vibrateSensitivitySet,
        Uint8List.fromList([85]),
      ),
      [0xA7, 0x00, 0x00, 0x03, 0x20, 0x61, 0x55],
    );
  });

  test('QGJ light sensor response maps SwitchState values', () {
    final response = parseQgjResponse(
      Uint8List.fromList([0xA7, 0x00, 0x00, 0x03, 0x24, 0x11, 0x01]),
    );

    expect(response?.cmdId, QgjCommandIds.lightSensorGet);
    expect(
      VehicleSettingsSnapshot.fromLightSensorPayload(
        response!.payload,
      ).lightSensor,
      isTrue,
    );
  });

  test('QGJ sound adjust payload parses official index volume pairs', () {
    final snapshot = VehicleSettingsSnapshot.fromSoundPayload([
      QgjSoundIndexes.lock,
      100,
      QgjSoundIndexes.unlock,
      0,
      QgjSoundIndexes.start,
      100,
      QgjSoundIndexes.stop,
      0,
      QgjSoundIndexes.speed,
      100,
      QgjSoundIndexes.all,
      60,
    ]);

    expect(snapshot.lockSound, isTrue);
    expect(snapshot.unlockSound, isFalse);
    expect(snapshot.startSound, isTrue);
    expect(snapshot.stopSound, isFalse);
    expect(snapshot.speedSound, isTrue);
    expect(snapshot.hasSoundState, isTrue);
  });

  test('QGJ sound adjust set payload writes target states as 0 or 100', () {
    final payload = buildSoundAdjustSetPayload([
      const QgjSoundAdjust(QgjSoundIndexes.lock, 100),
      const QgjSoundAdjust(QgjSoundIndexes.unlock, 0),
      const QgjSoundAdjust(QgjSoundIndexes.start, 100),
    ]);

    expect(payload, [
      QgjSoundIndexes.lock,
      100,
      QgjSoundIndexes.unlock,
      0,
      QgjSoundIndexes.start,
      100,
    ]);
  });

  test('QGJ vibrate sensitivity uses official four level values', () {
    expect(sensitivityLevelToValue(1), 0);
    expect(sensitivityLevelToValue(2), 15);
    expect(sensitivityLevelToValue(3), 50);
    expect(sensitivityLevelToValue(4), 85);
    expect(sensitivityValueToLevel(0), 1);
    expect(sensitivityValueToLevel(15), 2);
    expect(sensitivityValueToLevel(50), 3);
    expect(sensitivityValueToLevel(85), 4);
  });
}
