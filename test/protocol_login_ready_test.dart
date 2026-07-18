import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/services/control_channel_resolver.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

/// P0-A1: ConnectionState.ready alone is not official LOGIN.
/// Routing must use isProtocolLoggedIn (ready + credential latch).
void main() {
  group('ConnectionManager.isProtocolLoggedIn (LoginStatus.LOGIN)', () {
    test('starts false while disconnected', () {
      final manager = ConnectionManager();
      addTearDown(manager.dispose);

      expect(manager.state, ConnectionState.disconnected);
      expect(manager.isProtocolLoggedIn, isFalse);
      expect(manager.protocolLoginUnavailableReason, '蓝牙未连接');
    });

    test('GATT connected without handshake is not LOGIN', () {
      final manager = ConnectionManager();
      addTearDown(manager.dispose);

      manager.enterConnectedWithoutLoginForTest();

      expect(manager.state, ConnectionState.connected);
      expect(manager.token, isNull);
      expect(manager.isProtocolLoggedIn, isFalse);
      expect(manager.protocolLoginUnavailableReason, '蓝牙未完成协议登录');
    });

    test('enterReadyForTest latches LOGIN with credential', () {
      final manager = ConnectionManager();
      addTearDown(manager.dispose);

      manager.enterConnectedForTest();
      expect(manager.isProtocolLoggedIn, isFalse);

      manager.enterReadyForTest(token: 'tok-abc');

      expect(manager.state, ConnectionState.ready);
      expect(manager.token, 'tok-abc');
      expect(manager.isProtocolLoggedIn, isTrue);
      expect(manager.protocolLoginUnavailableReason, isEmpty);
    });

    test('disconnect/reset clears LOGIN latch', () async {
      final manager = ConnectionManager();
      addTearDown(manager.dispose);

      manager.enterReadyForTest();
      expect(manager.isProtocolLoggedIn, isTrue);

      await manager.disconnect();

      expect(manager.state, ConnectionState.disconnected);
      expect(manager.token, isNull);
      expect(manager.isProtocolLoggedIn, isFalse);
      expect(manager.protocolLoginUnavailableReason, '蓝牙未连接');
    });
  });

  group('ControlChannelResolver uses LOGIN not mere connected', () {
    OfficialCloudState signedInWithVehicle({int modelType = 3, int isGps = 0}) {
      final vehicle = OfficialVehicle.fromJson({
        'carId': 'official-1',
        'carNickName': '测试车辆',
        'modelType': modelType,
        'isGps': isGps,
        'btmac': 'AABBCCDDEEFF',
      });
      return OfficialCloudState.initial().copyWith(
        token: 'token',
        vehicles: [vehicle],
        selectedVehicleKey: vehicle.key,
      );
    }

    test('willUseBle false when GATT connected but not LOGIN', () {
      final manager = ConnectionManager();
      addTearDown(manager.dispose);
      manager.enterConnectedWithoutLoginForTest();

      final availability = ControlChannelResolver.resolve(
        cloudState: signedInWithVehicle(modelType: 3, isGps: 0),
        bleReady: manager.isProtocolLoggedIn,
        bleNotReadyReason: manager.protocolLoginUnavailableReason,
        channel: OfficialControlChannel.automatic,
      );

      expect(manager.isProtocolLoggedIn, isFalse);
      expect(availability.willUseBle, isFalse);
      expect(availability.canUseBle, isFalse);
      expect(availability.bleUnavailableReason, '蓝牙未完成协议登录');
      expect(availability.disabledReason, contains('协议登录'));
    });

    test('willUseBle true only after protocol LOGIN', () {
      final manager = ConnectionManager();
      addTearDown(manager.dispose);
      manager.enterReadyForTest();

      final availability = ControlChannelResolver.resolve(
        cloudState: signedInWithVehicle(modelType: 3, isGps: 0),
        bleReady: manager.isProtocolLoggedIn,
        bleNotReadyReason: manager.protocolLoginUnavailableReason,
        channel: OfficialControlChannel.automatic,
      );

      expect(manager.isProtocolLoggedIn, isTrue);
      expect(availability.willUseBle, isTrue);
      expect(availability.canUseBle, isTrue);
      expect(availability.bleUnavailableReason, isEmpty);
    });

    test('forced BLE channel still refuses pre-LOGIN connected', () {
      final manager = ConnectionManager();
      addTearDown(manager.dispose);
      manager.enterConnectedWithoutLoginForTest();

      final availability = ControlChannelResolver.resolve(
        cloudState: signedInWithVehicle(),
        bleReady: manager.isProtocolLoggedIn,
        bleNotReadyReason: manager.protocolLoginUnavailableReason,
        channel: OfficialControlChannel.ble,
      );

      expect(availability.enabled, isFalse);
      expect(availability.willUseBle, isFalse);
      expect(availability.disabledReason, '蓝牙未完成协议登录');
    });
  });
}
