import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/services/control_channel_resolver.dart';
import 'package:tailg_ble_app/services/control_channel_status.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/services/official_mqtt_service.dart';

void main() {
  ControlChannelAvailability availability({
    bool bleReady = false,
    bool signedIn = true,
    bool withVehicle = true,
    int modelType = 3,
    int isGps = 1,
    OfficialControlChannel channel = OfficialControlChannel.automatic,
  }) {
    final vehicle = OfficialVehicle.fromJson({
      'carId': 'v1',
      'carNickName': '测试',
      'modelType': modelType,
      'isGps': isGps,
      'btmac': 'AABBCCDDEEFF',
    });
    final state = OfficialCloudState.initial().copyWith(
      token: signedIn ? 'tok' : '',
      vehicles: withVehicle ? [vehicle] : const [],
      selectedVehicleKey: withVehicle ? vehicle.key : null,
    );
    return ControlChannelResolver.resolve(
      cloudState: state,
      bleReady: bleReady,
      channel: channel,
    );
  }

  group('ControlTopBarChannel (P0-A3 / P0-C3)', () {
    test('BLE 直连 only when protocol LOGIN and willUseBle', () {
      final ch = ControlTopBarChannel.resolve(
        availability: availability(bleReady: true, isGps: 0),
        bleState: ConnectionState.ready,
        bleProtocolLoggedIn: true,
        mqttLinkState: OfficialMqttLinkState.disconnected,
        mqttPreconnectInFlight: false,
      );
      expect(ch.kind, ControlTopBarChannelKind.bleDirect);
      expect(ch.label, 'BLE 直连');
      expect(ch.isActive, isTrue);
    });

    test('GATT connected without LOGIN is not BLE 直连', () {
      final ch = ControlTopBarChannel.resolve(
        availability: availability(bleReady: false, isGps: 0),
        bleState: ConnectionState.connected,
        bleProtocolLoggedIn: false,
        mqttLinkState: OfficialMqttLinkState.disconnected,
        mqttPreconnectInFlight: false,
      );
      expect(ch.kind, ControlTopBarChannelKind.bleConnecting);
      expect(ch.label, '蓝牙连接中');
      expect(ch.isActive, isFalse);
    });

    test('MQTT 远程 when broker connected', () {
      final ch = ControlTopBarChannel.resolve(
        availability: availability(bleReady: false, isGps: 1),
        bleState: ConnectionState.disconnected,
        bleProtocolLoggedIn: false,
        mqttLinkState: OfficialMqttLinkState.connected,
        mqttPreconnectInFlight: false,
      );
      expect(ch.kind, ControlTopBarChannelKind.mqttRemote);
      expect(ch.label, 'MQTT 远程');
      expect(ch.isActive, isTrue);
    });

    test('MQTT 连接中 during preconnect', () {
      final ch = ControlTopBarChannel.resolve(
        availability: availability(bleReady: false, isGps: 1),
        bleState: ConnectionState.disconnected,
        bleProtocolLoggedIn: false,
        mqttLinkState: OfficialMqttLinkState.connecting,
        mqttPreconnectInFlight: true,
      );
      expect(ch.kind, ControlTopBarChannelKind.mqttConnecting);
      expect(ch.label, 'MQTT 连接中');
    });

    test('云端待命 when cloud ok but MQTT idle', () {
      final ch = ControlTopBarChannel.resolve(
        availability: availability(bleReady: false, isGps: 1),
        bleState: ConnectionState.disconnected,
        bleProtocolLoggedIn: false,
        mqttLinkState: OfficialMqttLinkState.disconnected,
        mqttPreconnectInFlight: false,
      );
      expect(ch.kind, ControlTopBarChannelKind.cloudStandby);
      expect(ch.label, '云端待命');
    });

    test('MQTT 待重连 after preconnect error', () {
      final ch = ControlTopBarChannel.resolve(
        availability: availability(bleReady: false, isGps: 1),
        bleState: ConnectionState.disconnected,
        bleProtocolLoggedIn: false,
        mqttLinkState: OfficialMqttLinkState.disconnected,
        mqttPreconnectInFlight: false,
        mqttLastPreconnectError: '手机网络异常，请检查网络后重试',
      );
      expect(ch.kind, ControlTopBarChannelKind.mqttRetry);
      expect(ch.label, 'MQTT 待重连');
    });

    test('disconnected BLE never claims active channel alone', () {
      final ch = ControlTopBarChannel.resolve(
        availability: availability(
          bleReady: false,
          signedIn: false,
          withVehicle: false,
        ),
        bleState: ConnectionState.disconnected,
        bleProtocolLoggedIn: false,
        mqttLinkState: OfficialMqttLinkState.disconnected,
        mqttPreconnectInFlight: false,
      );
      expect(ch.isActive, isFalse);
      expect(ch.kind, ControlTopBarChannelKind.unavailable);
    });
  });
}
