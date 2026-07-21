import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/constants.dart';
import 'package:tailg_ble_app/ble/qgj_protocol.dart';
import 'package:tailg_ble_app/ble/tlink_protocol.dart';
import 'package:tailg_ble_app/services/induction_mode_service.dart';

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

  group('TLink induction frames', () {
    test('official open/close/check/distance plaintexts', () {
      expect(tlinkInductionOpenPlain, startsWith('85054A330201'));
      expect(tlinkInductionClosePlain, startsWith('85054A330202'));
      expect(tlinkInductionCheckPlain, startsWith('85034A3301'));
      expect(buildTLinkInductionDistancePlain(7), contains('85044A3303'));
    });
  });

  group('control home induction surface', () {
    test('home hosts channel card; unlock lives in induction settings', () {
      final home = readSource('lib/pages/vehicle_control_home_page.dart');
      final card = readSource('lib/widgets/control_and_unlock_card.dart');
      final settings = readSource('lib/pages/induction_settings_page.dart');
      expect(home, contains('ControlAndUnlockCard'));
      expect(home, contains('InductionSettingsPage'));
      expect(home, isNot(contains('_selectUnlockMode')));
      expect(card, contains('控车渠道'));
      expect(card, isNot(contains('解锁模式')));
      expect(card, isNot(contains('SegmentedButton<bool>')));
      expect(settings, contains('解锁模式'));
      expect(settings, contains('感应'));
      expect(settings, contains('手动'));
    });

    test('settings page is product-facing and stack-aware', () {
      final source = readSource('lib/pages/induction_settings_page.dart');
      expect(source, contains('InductionModeService'));
      expect(source, contains('InductionStack'));
      expect(source, contains('感应解锁'));
      expect(source, isNot(contains('0x2031')));
      expect(source, isNot(contains('4A33')));
    });

    test('control card is channel-only widget', () {
      final source = readSource('lib/widgets/control_and_unlock_card.dart');
      expect(source, contains('class ControlAndUnlockCard'));
      expect(source, contains('onOpenInductionSettings'));
      expect(source, isNot(contains('unlockSelection')));
    });

    test('connection manager exposes bond + tlink induction APIs', () {
      final source = readSource('lib/ble/connection_manager.dart');
      expect(source, contains('openTlinkInduction'));
      expect(source, contains('closeTlinkInduction'));
      expect(source, contains('checkTlinkInduction'));
      expect(source, contains('setTlinkInductionDistance'));
      expect(source, contains('createBond'));
      expect(source, contains('removeBond'));
      expect(source, contains('readRemoteRssi'));
    });

    test('induction service routes model types', () {
      expect(InductionModeService.stackForModelType(8), InductionStack.qgj);
      expect(InductionModeService.stackForModelType(3), InductionStack.tlink);
      expect(InductionModeService.stackForModelType(1), InductionStack.rssi);
    });
  });
}
