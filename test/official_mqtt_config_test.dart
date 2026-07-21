import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/official_mqtt_config.dart';

void main() {
  OfficialVehicle vehicle({
    int? modelType,
    String imei = '860111',
    String imeiGps = '',
    String mqHost = '',
    String mqPort = '',
  }) {
    return OfficialVehicle.fromJson({
      'carId': 'c1',
      'imei': imei,
      'imeiGps': imeiGps,
      'modelType': modelType,
      'mqHost': mqHost,
      'mqPort': mqPort,
    });
  }

  test('KKS/YJ use tcp broker and app-update topics', () {
    final kks = vehicle(modelType: 1, imei: 'IMEI1');
    final yj = vehicle(modelType: 2, imei: 'IMEI2');

    expect(
      OfficialMqttConfig.brokerUriFor(kks),
      OfficialMqttConfig.kksYjHostUri,
    );
    expect(OfficialMqttConfig.usesKksYjBroker(1), isTrue);
    expect(
      OfficialMqttConfig.publishTopic(vehicle: kks, imei: 'IMEI1'),
      'app-update-kks/IMEI1',
    );
    expect(
      OfficialMqttConfig.publishTopic(vehicle: yj, imei: 'IMEI2'),
      'app-update-yunjia/IMEI2',
    );
  });

  test('QGJ/C18 use ssl broker and APP_S/CMD topic', () {
    final qgj = vehicle(modelType: 8, imei: 'M', imeiGps: 'G');
    expect(OfficialMqttConfig.brokerUriFor(qgj), OfficialMqttConfig.c18HostUri);
    expect(
      OfficialMqttConfig.publishTopic(vehicle: qgj, imei: 'G'),
      'APP_S/CMD/G',
    );
    expect(OfficialMqttConfig.commandImei(qgj), 'G');
  });

  test('vehicle mqHost/mqPort override C18 default', () {
    final v = vehicle(modelType: 8, mqHost: 'mqtt.example.com', mqPort: '8883');
    expect(OfficialMqttConfig.brokerUriFor(v), 'ssl://mqtt.example.com:8883');
  });

  test('KKS uses hardcoded MQTT credentials', () {
    final kks = vehicle(modelType: 1);
    final creds = OfficialMqttConfig.credentialsFor(kks);
    expect(creds.username, OfficialMqttConfig.username);
    expect(creds.password, OfficialMqttConfig.password);
  });

  test('QGJ uses vehicle mqUsername/mqPassword', () {
    final qgj = OfficialVehicle.fromJson({
      'carId': 'c1',
      'modelType': 8,
      'imeiGps': 'G',
      'mqUsername': 'veh_user',
      'mqPassword': 'veh_pass',
    });
    final creds = OfficialMqttConfig.credentialsFor(qgj);
    expect(creds.username, 'veh_user');
    expect(creds.password, 'veh_pass');
  });

  test('QGJ refuses empty MQTT credentials', () {
    final qgj = vehicle(modelType: 8, imeiGps: 'G');
    expect(
      () => OfficialMqttConfig.credentialsFor(qgj),
      throwsA(isA<OfficialCloudApiException>()),
    );
  });

  test('command payload matches MqttCmdBean JSON', () {
    expect(
      OfficialMqttConfig.commandPayload(imei: '860', command: 'lock'),
      '{"imei":"860","command":"lock"}',
    );
  });

  test('client id shapes match official patterns', () {
    final kks = vehicle(modelType: 1, imei: 'ABC');
    final qgj = vehicle(modelType: 8, imeiGps: 'GPS1');
    final kksId = OfficialMqttConfig.clientIdFor(
      vehicle: kks,
      userId: 'u',
      random: _FixedRandom(),
    );
    final qgjId = OfficialMqttConfig.clientIdFor(
      vehicle: qgj,
      userId: '42',
      random: _FixedRandom(),
    );
    expect(kksId, 'app_ABC000');
    expect(qgjId, 'app_GPS1_42_android_000');
  });

  test('parseBrokerUri extracts host/port/secure', () {
    final tcp = OfficialMqttConfig.parseBrokerUri('tcp://www.tailgdd.com:1883');
    final ssl = OfficialMqttConfig.parseBrokerUri('ssl://www.tailgdd.com:6668');
    expect(tcp.secure, isFalse);
    expect(tcp.host, 'www.tailgdd.com');
    expect(tcp.port, 1883);
    expect(ssl.secure, isTrue);
    expect(ssl.port, 6668);
  });
}

class _FixedRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}
