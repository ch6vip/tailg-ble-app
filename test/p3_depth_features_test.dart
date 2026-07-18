import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';

import 'helpers/source_scan.dart';

void main() {
  group('P3 bind/unbind APIs', () {
    test('bindVehicleByImei and unbindVehicle honor overrides', () async {
      final service = OfficialCloudService();
      service.resetForTest();
      service.setStateForTest(
        OfficialCloudState.initial().copyWith(
          initialized: true,
          token: 't',
          vehicles: [
            OfficialVehicle.fromJson({
              'carId': 'c1',
              'carNickName': '车',
              'imei': '8601',
            }),
          ],
          selectedVehicleKey: 'c1',
        ),
      );

      String? bound;
      String? unbound;
      service.bindVehicleByImeiOverride = (imei) async {
        bound = imei;
      };
      service.unbindVehicleOverride = (carId, type) async {
        unbound = '$carId:$type';
      };

      await service.bindVehicleByImei(' 860123456789012 ');
      await service.unbindVehicle(carId: 'c1', unbindType: 1);

      expect(bound, '860123456789012');
      expect(unbound, 'c1:1');
    });
  });

  group('P3 surface pages exist', () {
    test('IMEI bind / QGJ / OTA pages and PORT_TO_NEXT checklist', () {
      expect(
        readSource('lib/pages/bind_imei_page.dart'),
        contains('app/car/bikeBind'),
      );
      expect(
        readSource('lib/pages/qgj_settings_page.dart'),
        contains('proximityStatusGet'),
      );
      expect(
        readSource('lib/pages/firmware_ota_page.dart'),
        contains('writeOtaOrder'),
      );
      expect(
        readSource('lib/pages/firmware_ota_page.dart'),
        isNot(contains('injectDemoFirmware')),
      );
      expect(
        readSource('lib/pages/vehicle_settings_page.dart'),
        isNot(contains('FirmwareOtaPage')),
      );
      expect(
        readSource('lib/services/firmware_ota_service.dart'),
        contains('writeOtaFileChunk'),
      );
      expect(
        readSource('lib/ble/nfc_ble_frames.dart'),
        contains('headerNfcAddMode'),
      );
      expect(
        readSource('lib/services/ble_nfc_service.dart'),
        contains('canWriteOfficialNfc'),
      );
      expect(readSource('PORT_TO_NEXT.md'), contains('P4-6'));
      expect(
        readSource('lib/pages/add_vehicle_page.dart'),
        contains('IMEI 绑车'),
      );
      expect(
        readSource('lib/pages/vehicle_settings_page.dart'),
        contains('解绑车辆'),
      );
    });
  });
}
