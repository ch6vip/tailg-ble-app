import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/official_mqtt_payload.dart';

void main() {
  group('OfficialMqttStatusPayload', () {
    test('parses ACC and defenceStatus fields', () {
      final payload = OfficialMqttStatusPayload.tryParse(
        '{"imei":"860","ACC":"1","defenceStatus":"0","muteStatus":0}',
      );

      expect(payload, isNotNull);
      expect(payload!.acc, '1');
      expect(payload.defenceStatus, '0');
      expect(payload.accInt, 1);
      expect(payload.defenceStatusInt, 0);
      expect(payload.hasVehicleState, isTrue);
    });

    test('confirms pending commands like ControlFragment', () {
      final startOk = OfficialMqttStatusPayload(acc: '1', defenceStatus: '0');
      final lockOk = OfficialMqttStatusPayload(acc: '0', defenceStatus: '1');
      final unlockOk = OfficialMqttStatusPayload(acc: '0', defenceStatus: '0');

      expect(startOk.confirmsCommand('start'), isTrue);
      expect(startOk.confirmsCommand('stop'), isFalse);
      expect(lockOk.confirmsCommand('lock'), isTrue);
      expect(unlockOk.confirmsCommand('unlock'), isTrue);
    });

    test('returns null for non-json payloads', () {
      expect(OfficialMqttStatusPayload.tryParse('not-json'), isNull);
      expect(OfficialMqttStatusPayload.tryParse(''), isNull);
    });
  });
}
