import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/connection_manager.dart';
import 'package:tailg_ble_app/ble/nfc_ble_frames.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';
import 'package:tailg_ble_app/services/firmware_ota_service.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

void main() {
  group('OfficialNfcBleFrames (P3-6)', () {
    test('builds official header prefixes from TailgBleConfig', () {
      expect(
        OfficialNfcBleFrames.addUserKeyHex(keyType: 1, type: '1'),
        startsWith(OfficialNfcBleFrames.headerAddUserKey),
      );
      expect(
        OfficialNfcBleFrames.checkNfcHex('01'),
        startsWith(OfficialNfcBleFrames.headerNfcCheck),
      );
      expect(
        OfficialNfcBleFrames.delNfcHex('02'),
        startsWith(OfficialNfcBleFrames.headerNfcDel),
      );
      expect(
        OfficialNfcBleFrames.addCardHex('03'),
        startsWith(OfficialNfcBleFrames.headerNfcAddMode),
      );
      expect(OfficialNfcBleFrames.toBytes('8504').length, 2);
    });
  });

  group('FirmwareOtaService e2e pipeline (P3-5)', () {
    test('query + inject firmware + chunk transfer completes', () async {
      final cloud = OfficialCloudService()..resetForTest();
      final vehicle = OfficialVehicle.fromJson({
        'carId': 'ota-1',
        'carNickName': 'OTA车',
        'imei': '860000000000999',
        'imeiGps': '860000000000999',
      });
      cloud.setStateForTest(
        OfficialCloudState.initial().copyWith(
          token: 't',
          vehicles: [vehicle],
          selectedVehicleKey: vehicle.key,
        ),
      );
      cloud.getFirmVersionOverride = (_) async => {
        'version': '1.0.0-demo',
        'url': 'https://example.invalid/fw.bin',
      };

      final manager = ConnectionManager();
      addTearDown(manager.dispose);
      manager.enterReadyForTest();

      final orders = <List<int>>[];
      final chunks = <List<int>>[];
      final ota = FirmwareOtaService(cloud: cloud, connectionManager: manager);
      ota.downloadOverride = (_) async =>
          Uint8List.fromList(List<int>.generate(400, (i) => i & 0xFF));
      ota.writeOrderOverride = (order) async {
        orders.add(order);
        return true;
      };
      ota.writeChunkOverride = (chunk) async {
        chunks.add(chunk);
        return true;
      };

      final progress = await ota.run(chunkSize: 100).toList();
      expect(progress.last.phase, FirmwareOtaPhase.completed);
      expect(orders, isNotEmpty);
      expect(chunks.length, 4);
      expect(chunks.fold<int>(0, (a, b) => a + b.length), 400);
    });

    test('fails when not LOGIN', () async {
      final cloud = OfficialCloudService()..resetForTest();
      final vehicle = OfficialVehicle.fromJson({
        'carId': 'ota-2',
        'imei': '8601',
      });
      cloud.setStateForTest(
        OfficialCloudState.initial().copyWith(
          token: 't',
          vehicles: [vehicle],
          selectedVehicleKey: vehicle.key,
        ),
      );
      cloud.getFirmVersionOverride = (_) async => {'url': 'x'};
      final manager = ConnectionManager();
      addTearDown(manager.dispose);
      final ota = FirmwareOtaService(cloud: cloud, connectionManager: manager);
      ota.downloadOverride = (_) async => Uint8List(16);

      final progress = await ota.run().toList();
      expect(progress.last.phase, FirmwareOtaPhase.failed);
      expect(progress.last.message, contains('协议登录'));
    });
  });
}
