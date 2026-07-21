import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/coulomb_meter_service.dart';

void main() {
  group('CoulombMeterService', () {
    test('isSupported hides lithium 208', () {
      expect(
        CoulombMeterService.isSupported(modelType: 8, bmsTlvType: '208'),
        isFalse,
      );
      expect(
        CoulombMeterService.isSupported(modelType: 8, bmsTlvType: '176'),
        isTrue,
      );
      expect(
        CoulombMeterService.isSupported(modelType: 8, bmsTlvType: ''),
        isTrue,
      );
    });

    test('parseSocVisible reads bit0 of status byte', () {
      // Official setSocVisible: length 24, prefix D0010A08, status at [10..12).
      // D0010A08 (8) + pad (2) + status (2) + tail ...
      expect(
        CoulombMeterService.parseSocVisible('D0010A08FF01000000000000'),
        isTrue,
      );
      expect(
        CoulombMeterService.parseSocVisible('D0010A08FF00000000000000'),
        isFalse,
      );
      // wrong prefix / short => null (need power-on path)
      expect(CoulombMeterService.parseSocVisible('AABBCC'), isNull);
      expect(CoulombMeterService.parseSocVisible('B0010A080100'), isNull);
    });

    test('command frames match official constants', () {
      expect(CoulombMeterService.queryFrame, 'D0018A00');
      expect(CoulombMeterService.turnOnFrame, 'D0018A020500');
      expect(CoulombMeterService.turnOffFrame, 'D0018A020600');
    });
  });
}
