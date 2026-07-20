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

    test('parses official control errors and exposes policy state', () {
      final moving = OfficialMqttStatusPayload.tryParse(
        '{"accErrorStatus":4,"defenceErrorStatus":0}',
      );
      final keyed = OfficialMqttStatusPayload.tryParse('{"accErrorStatus":8}');
      final notPoweredOff = OfficialMqttStatusPayload.tryParse(
        '{"defenceErrorStatus":3,"bikeSetSourceValue":3}',
      );

      expect(moving?.isMoving, isTrue);
      expect(moving?.controlErrorMessage('start'), '车辆行驶中，请勿操作');
      expect(keyed?.isKeyStarted, isTrue);
      expect(keyed?.controlErrorMessage('stop'), '您已使用钥匙启动车辆，当前不支持此操作');
      expect(notPoweredOff?.isNotPoweredOff, isTrue);
      expect(notPoweredOff?.controlErrorMessage('lock'), '车辆未断电，请勿操作');
    });
  });
}
