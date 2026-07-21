import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/command_types.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/official_mqtt_config.dart';
import 'package:tailg_ble_app/services/official_mqtt_service.dart';
import 'package:tailg_ble_app/services/service_locator.dart';

void main() {
  setUp(() async {
    await OfficialMqttService().resetForTest();
    OfficialCloudService().resetForTest();
  });

  tearDown(() async {
    await OfficialMqttService().resetForTest();
    OfficialCloudService().resetForTest();
  });

  group('formatConnectError', () {
    test('includes SocketException code and message', () {
      final err = SocketException(
        'Connection timed out',
        osError: const OSError('Connection timed out', 110),
      );
      final raw = OfficialMqttService.formatConnectError(err);
      expect(raw, contains('SocketException'));
      expect(raw, contains('110'));
      expect(raw, contains('Connection timed out'));
    });

    test('includes TimeoutException message or duration', () {
      final withMessage = OfficialMqttService.formatConnectError(
        TimeoutException('connect', const Duration(seconds: 10)),
      );
      expect(withMessage, contains('TimeoutException'));
      expect(withMessage, contains('connect'));

      final durationOnly = OfficialMqttService.formatConnectError(
        TimeoutException(null, const Duration(seconds: 10)),
      );
      expect(durationOnly, contains('TimeoutException'));
      expect(durationOnly, contains('0:00:10.000000'));
    });

    test('includes OfficialCloudApiException message', () {
      final raw = OfficialMqttService.formatConnectError(
        const OfficialCloudApiException('官方 MQTT 连接失败: state=faulted'),
      );
      expect(raw, contains('OfficialCloudApiException'));
      expect(raw, contains('state=faulted'));
    });
  });

  group('preconnect retry config', () {
    test('exposes bounded retry settings', () {
      expect(OfficialMqttConfig.preconnectMaxRetries, greaterThanOrEqualTo(1));
      expect(
        OfficialMqttConfig.preconnectRetryBaseDelay.inMilliseconds,
        greaterThan(0),
      );
    });
  });

  OfficialCloudService signedInCloud() {
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'car-mqtt',
      'carNickName': 'MQTT车',
      'imei': '860000000000001',
      'modelType': 8,
      'isGps': 1,
    });
    final cloud = OfficialCloudService();
    cloud.setStateForTest(
      OfficialCloudState.initial().copyWith(
        initialized: true,
        token: 'tok',
        userId: 'u1',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
      ),
    );
    cloud.sendCommandOverride = (_) async => 'success';
    return cloud;
  }

  group('sendCommandPreferMqtt (P4-2)', () {
    test('returns mqtt:success when publish override succeeds', () async {
      final mqtt = OfficialMqttService();
      final cloud = signedInCloud();
      mqtt.publishCommandOverride =
          ({
            required OfficialVehicle vehicle,
            required String userId,
            required String commandApiName,
          }) async {
            // no-op success
          };

      final result = await mqtt.sendCommandPreferMqtt(
        command: CommandCode.lock,
        cloud: cloud,
      );

      expect(result, 'mqtt:success');
      expect(mqtt.lastSendPath, OfficialRemoteSendPath.mqtt);
      expect(mqtt.pendingCommandApiName, 'lock');
    });

    test('falls back to HTTP when publish fails', () async {
      final mqtt = OfficialMqttService();
      final cloud = signedInCloud();
      mqtt.publishCommandOverride =
          ({
            required OfficialVehicle vehicle,
            required String userId,
            required String commandApiName,
          }) {
            throw const OfficialCloudApiException('mock broker down');
          };

      final result = await mqtt.sendCommandPreferMqtt(
        command: CommandCode.unlock,
        cloud: cloud,
      );

      expect(result, 'http:success');
      expect(mqtt.lastSendPath, OfficialRemoteSendPath.http);
      expect(mqtt.pendingCommandApiName, isNull);
    });

    test(
      'records official command errors without treating them as ACK',
      () async {
        final mqtt = OfficialMqttService();
        final cloud = signedInCloud();
        mqtt.publishCommandOverride =
            ({
              required OfficialVehicle vehicle,
              required String userId,
              required String commandApiName,
            }) async {};

        await mqtt.sendCommandPreferMqtt(
          command: CommandCode.lock,
          cloud: cloud,
        );
        mqtt.handleStatusPayload(
          '{"imei":"860000000000001","defenceErrorStatus":3,'
          '"bikeSetSourceValue":3}',
        );

        expect(mqtt.pendingCommandApiName, 'lock');
        expect(mqtt.pendingCommandError, '车辆未断电，请勿操作');
      },
    );

    test('ignores status payloads belonging to another vehicle', () async {
      final mqtt = OfficialMqttService();
      final cloud = signedInCloud();
      mqtt.publishCommandOverride =
          ({
            required OfficialVehicle vehicle,
            required String userId,
            required String commandApiName,
          }) async {};

      await mqtt.sendCommandPreferMqtt(command: CommandCode.lock, cloud: cloud);
      mqtt.handleStatusPayload('{"imei":"another-imei","defenceStatus":"1"}');

      expect(mqtt.pendingCommandApiName, 'lock');
      expect(cloud.state.selectedVehicle?.defenceStatus, isNull);
    });
  });

  group('AppServices MQTT lifecycle (P4-1)', () {
    test('production graph holds OfficialMqttService', () {
      final services = AppServices.production();
      expect(services.officialMqttService, isA<OfficialMqttService>());
      expect(
        identical(services.officialMqttService, OfficialMqttService()),
        isTrue,
      );
    });
  });
}
