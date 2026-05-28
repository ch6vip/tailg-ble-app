import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/constants.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';

void main() {
  group('OfficialVehicle', () {
    test('parses official car status fields', () {
      final vehicle = OfficialVehicle.fromJson({
        'imei': 'IMEI_MAIN',
        'imeiGps': 'IMEI_GPS',
        'carId': 'car-1',
        'carName': 'Tailg',
        'carNickName': 'My Bike',
        'carPhoto': 'https://example.com/bike.png',
        'frame': 'FRAME123',
        'defenceStatus': 1,
        'acc': 0,
        'electricQuantity': '87',
        'voltage': '52.5',
        'online': true,
        'btname': 'Q_BASH_TEST',
        'btmac': 'AA:BB:CC:DD:EE:FF',
        'longitude': '104.1',
        'latitude': '25.1',
        'modelType': 1501,
        'mileage': '12.5',
      });

      expect(vehicle.displayName, 'My Bike');
      expect(vehicle.isLocked, isTrue);
      expect(vehicle.isPowerOn, isFalse);
      expect(vehicle.electricQuantity, 87);
      expect(vehicle.voltage, 52.5);
      expect(vehicle.mileage, 12.5);
      expect(vehicle.commandImei, 'IMEI_GPS');
    });

    test('falls back to main imei for non GPS model type', () {
      final vehicle = OfficialVehicle.fromJson({
        'imei': 'IMEI_MAIN',
        'imeiGps': 'IMEI_GPS',
        'modelType': 2,
      });

      expect(vehicle.commandImei, 'IMEI_MAIN');
    });
  });

  group('OfficialCloudCommand', () {
    test('maps supported command codes', () {
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.lock)?.apiName,
        'lock',
      );
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.unlock)?.apiName,
        'unlock',
      );
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.powerOn)?.apiName,
        'start',
      );
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.powerOff)?.apiName,
        'stop',
      );
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.find)?.apiName,
        'search',
      );
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.openSeat)?.apiName,
        'openCushion',
      );
    });

    test('rejects unsupported read commands', () {
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.readState),
        isNull,
      );
      expect(
        OfficialCloudCommand.fromCommandCode(CommandCode.readAntiTheft),
        isNull,
      );
    });
  });
}
