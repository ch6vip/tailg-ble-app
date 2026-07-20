import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/constants.dart';
import 'package:tailg_ble_app/ble/qgj_protocol.dart';

import 'helpers/source_scan.dart';

void main() {
  group('QGJ proximity payloads (official OpCode / UInt8)', () {
    test('status set OPEN=1 CLOSE=0', () {
      expect(buildQgjProximityStatusPayload(true), [1]);
      expect(buildQgjProximityStatusPayload(false), [0]);
      expect(buildQgjSwitchPayload(true), [1]);
    });

    test('distance set is single uint8', () {
      expect(buildQgjProximityDistancePayload(5), [5]);
      expect(buildQgjProximityDistancePayload(-1), [0]);
      expect(buildQgjProximityDistancePayload(200), [100]);
    });

    test('HID payload uses OpHID ordinals', () {
      expect(buildQgjHidPayload(QgjHidModes.close), [0]);
      expect(buildQgjHidPayload(QgjHidModes.open), [1]);
      expect(buildQgjHidPayload(QgjHidModes.openWithAutoLock), [2]);
    });

    test('parsers read first payload byte', () {
      expect(parseQgjProximityEnabled([1]), isTrue);
      expect(parseQgjProximityEnabled([0]), isFalse);
      expect(parseQgjProximityEnabled(const []), isNull);
      expect(parseQgjProximityDistance([7]), 7);
    });

    test('command ids match official ECU tags 0x2030-0x2033 / HID', () {
      expect(QgjCommandIds.proximityStatusGet, 0x2030);
      expect(QgjCommandIds.proximityStatusSet, 0x2031);
      expect(QgjCommandIds.proximityDistanceGet, 0x2032);
      expect(QgjCommandIds.proximityDistanceSet, 0x2033);
      expect(QgjCommandIds.hidStatusSet, 0x2140);
    });
  });

  group('control home QGJ proximity surface', () {
    test('home hosts proximity card and official command path', () {
      final source = readSource('lib/pages/vehicle_control_home_page.dart');
      expect(source, contains('_ProximityCard'));
      expect(source, contains('_toggleProximity'));
      expect(source, contains('proximityStatusSet'));
      expect(source, contains('hidStatusSet'));
      expect(source, contains('QgjSettingsPage'));
      expect(source, contains('感应解锁'));
    });

    test('settings page can write distance and HID', () {
      final source = readSource('lib/pages/qgj_settings_page.dart');
      expect(source, contains('proximityDistanceSet'));
      expect(source, contains('hidStatusSet'));
      expect(source, contains('感应距离'));
    });
  });
}
