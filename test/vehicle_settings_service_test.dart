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

  test('QGJ response parser rejects frames with invalid declared length', () {
    expect(
      parseQgjResponse(
        Uint8List.fromList([0xA7, 0x00, 0x00, 0x03, 0x24, 0x11]),
      ),
      isNull,
    );
    expect(
      parseQgjResponse(
        Uint8List.fromList([0xA7, 0x00, 0x00, 0x02, 0x24, 0x11, 0x01]),
      ),
      isNull,
    );
  });

  test('QGJ advanced command ids match official V3 registry', () {
    expect(QgjCommandIds.autoLockGet, 0x2000);
    expect(QgjCommandIds.autoLockSet, 0x2001);
    expect(QgjCommandIds.autoLockTimeGet, 0x2000);
    expect(QgjCommandIds.autoLockTimeSet, 0x2001);
    expect(QgjCommandIds.powerOnAutoLockTimeGet, 0x2010);
    expect(QgjCommandIds.powerOnAutoLockTimeSet, 0x2011);
    expect(QgjCommandIds.proximityStatusGet, 0x2030);
    expect(QgjCommandIds.proximityStatusSet, 0x2031);
    expect(QgjCommandIds.proximityDistanceGet, 0x2032);
    expect(QgjCommandIds.proximityDistanceSet, 0x2033);
    expect(QgjCommandIds.handlebarLockSet, 0x2050);
    expect(QgjCommandIds.handlebarLockGet, 0x2051);
    expect(QgjCommandIds.postureDetectionSet, 0x2070);
    expect(QgjCommandIds.postureDetectionGet, 0x2071);
    expect(QgjCommandIds.passwordUnlockGet, 0x2080);
    expect(QgjCommandIds.passwordUnlockSet, 0x2081);
    expect(QgjCommandIds.hidStatusSet, 0x2140);
    expect(QgjCommandIds.hidStatusGet, 0x2142);
    expect(QgjCommandIds.safeLockSet, 0x2360);
    expect(QgjCommandIds.safeLockGet, 0x2361);
    expect(QgjCommandIds.kickstandSet, 0x2370);
    expect(QgjCommandIds.kickstandGet, 0x2371);
    expect(QgjCommandIds.seatSensorSet, 0x2400);
    expect(QgjCommandIds.seatSensorGet, 0x2401);
    expect(QgjCommandIds.enterOtaMode, 0x5004);
  });

  test('QGJ common payload helpers match official common codec', () {
    expect(buildQgjUInt8Payload(0x123), [0x23]);
    expect(buildQgjUInt16Payload(30), [0x00, 0x1E]);
    expect(buildQgjSwitchPayload(false), [0x00]);
    expect(buildQgjSwitchPayload(true), [0x01]);
    expect(buildQgjAutoLockPayload(false), [0x00, 0x00]);
    expect(buildQgjAutoLockPayload(true), [0x00, 0x2D]);
    expect(buildQgjHidPayload(QgjHidModes.openWithAutoLock), [0x02]);
  });

  test('QGJ advanced command frames stay readback-safe', () {
    expect(buildQgjCommand(QgjCommandIds.autoLockTimeGet), [
      0xA7,
      0x00,
      0x00,
      0x02,
      0x20,
      0x00,
    ]);
    expect(
      buildQgjCommand(QgjCommandIds.autoLockTimeSet, buildQgjUInt16Payload(30)),
      [0xA7, 0x00, 0x00, 0x04, 0x20, 0x01, 0x00, 0x1E],
    );
    expect(
      buildQgjCommand(QgjCommandIds.autoLockSet, buildQgjAutoLockPayload(true)),
      [0xA7, 0x00, 0x00, 0x04, 0x20, 0x01, 0x00, 0x2D],
    );
    expect(
      buildQgjCommand(
        QgjCommandIds.proximityDistanceSet,
        buildQgjUInt8Payload(2),
      ),
      [0xA7, 0x00, 0x00, 0x03, 0x20, 0x33, 0x02],
    );
    expect(
      buildQgjCommand(
        QgjCommandIds.handlebarLockSet,
        buildQgjSwitchPayload(true),
      ),
      [0xA7, 0x00, 0x00, 0x03, 0x20, 0x50, 0x01],
    );
    expect(
      buildQgjCommand(
        QgjCommandIds.hidStatusSet,
        buildQgjHidPayload(QgjHidModes.openWithAutoLock),
      ),
      [0xA7, 0x00, 0x00, 0x03, 0x21, 0x40, 0x02],
    );
    expect(
      buildQgjCommand(QgjCommandIds.passwordUnlockGet, buildQgjUInt8Payload(0)),
      [0xA7, 0x00, 0x00, 0x03, 0x20, 0x80, 0x00],
    );
    expect(
      buildQgjCommand(
        QgjCommandIds.passwordUnlockSet,
        Uint8List.fromList([0, 0]),
      ),
      [0xA7, 0x00, 0x00, 0x04, 0x20, 0x81, 0x00, 0x00],
    );
  });

  test('QGJ advanced read-only snapshot parses official payloads', () {
    final snapshot = const VehicleAdvancedSettingsSnapshot()
        .merge(
          VehicleAdvancedSettingsSnapshot.fromAutoLockPayload([0x00, 0x2D]),
        )
        .merge(
          VehicleAdvancedSettingsSnapshot.fromPowerOnAutoLockPayload([
            0x00,
            0x3C,
          ]),
        )
        .merge(
          VehicleAdvancedSettingsSnapshot.fromProximityStatusPayload([0x01]),
        )
        .merge(
          VehicleAdvancedSettingsSnapshot.fromProximityDistancePayload([0x02]),
        )
        .merge(VehicleAdvancedSettingsSnapshot.fromHandlebarLockPayload([0x01]))
        .merge(VehicleAdvancedSettingsSnapshot.fromPostureDetectionPayload([0]))
        .merge(VehicleAdvancedSettingsSnapshot.fromHidPayload([0x02]))
        .merge(VehicleAdvancedSettingsSnapshot.fromSafeLockPayload([0x01]))
        .merge(VehicleAdvancedSettingsSnapshot.fromKickstandPayload([0x00]))
        .merge(VehicleAdvancedSettingsSnapshot.fromSeatSensorPayload([0x01]));

    expect(snapshot.hasAnyState, isTrue);
    expect(snapshot.autoLockEnabled, isTrue);
    expect(snapshot.autoLockTimeSeconds, 45);
    expect(snapshot.powerOnAutoLockTimeSeconds, 60);
    expect(snapshot.proximityEnabled, isTrue);
    expect(snapshot.proximityDistance, 2);
    expect(snapshot.handlebarLockEnabled, isTrue);
    expect(snapshot.postureDetectionEnabled, isFalse);
    expect(snapshot.hidMode, QgjHidModes.openWithAutoLock);
    expect(snapshot.safeLockEnabled, isTrue);
    expect(snapshot.kickstandEnabled, isFalse);
    expect(snapshot.seatSensorEnabled, isTrue);
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
