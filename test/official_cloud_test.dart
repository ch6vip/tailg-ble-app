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
      expect(vehicle.normalizedBtmac, 'AA:BB:CC:DD:EE:FF');
      expect(vehicle.hasBleIdentity, isTrue);
    });

    test('falls back to main imei for non GPS model type', () {
      final vehicle = OfficialVehicle.fromJson({
        'imei': 'IMEI_MAIN',
        'imeiGps': 'IMEI_GPS',
        'modelType': 2,
      });

      expect(vehicle.commandImei, 'IMEI_MAIN');
    });

    test('normalizes compact official bluetooth mac', () {
      final vehicle = OfficialVehicle.fromJson({'btmac': 'aabbccddeeff'});

      expect(vehicle.normalizedBtmac, 'AA:BB:CC:DD:EE:FF');
      expect(vehicle.hasBleIdentity, isTrue);
    });

    test('rejects invalid official bluetooth mac', () {
      final vehicle = OfficialVehicle.fromJson({'btmac': 'not-a-mac'});

      expect(vehicle.normalizedBtmac, isEmpty);
      expect(vehicle.hasBleIdentity, isFalse);
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

  group('OfficialVehicleSelfCheck', () {
    test('keeps raw official status response without guessing meanings', () {
      final result = OfficialVehicleSelfCheck.fromResponse({
        'code': '200',
        'msg': '成功',
        'data': {'imei': '123456789012345', 'voltage': 52.6, 'fault': 0},
      });

      expect(result.code, 200);
      expect(result.displayMessage, '成功');
      expect(result.dataMap['voltage'], 52.6);
      expect(result.raw['msg'], '成功');
    });
  });

  group('Official map replica models', () {
    test('parses official parking location and fence fields', () {
      final location = OfficialVehicleLocation.fromJson({
        'extendId': 'ext-1',
        'bleConnectTime': '2026-05-29 10:00:00',
        'bleConnectLat': '25.123456',
        'bleConnectLng': '104.654321',
        'carId': 'car-1',
        'bleConnectAddress': '停车点',
      });
      final fence = OfficialFenceData.fromJson({
        'fenceRadius': '5',
        'fenceRadiusMax': '10',
        'fenceRadiusMin': '1',
        'fenceSwitch': '1',
        'fenceTimeFr': '08:00',
        'fenceTimeTo': '22:00',
      });

      expect(location.hasData, isTrue);
      expect(location.latitude, 25.123456);
      expect(location.longitude, 104.654321);
      expect(fence.enabled, isTrue);
      expect(fence.statusLabel, '已开启');
      expect(fence.radiusLabel, '500m');
      expect(fence.radiusMeters, 500);
      expect(fence.timeLabel, '08:00 - 22:00');
    });

    test('parses official travel list and track points', () {
      final day = OfficialTravelDay.fromJson({
        'travelDate': '2026-05-29',
        'totalTime': '1800',
        'totalMileage': '12.5',
        'deviceTravelDtoList': [
          {
            'deviceTravelId': 'travel-1',
            'travelDate': '2026-05-29',
            'startTime': '10:00',
            'endTime': '10:30',
            'mileage': '12.5',
            'averageSpeed': '25',
            'maxSpeed': '42',
            'min': '30',
          },
        ],
      });
      final point = OfficialTravelPoint.fromJson({
        'lat': '25.1',
        'lng': '104.1',
        'heading': '90',
        'speed': '20',
        'starsNum': '8',
        'reportTime': '2026-05-29 10:01:00',
      });

      expect(day.hasData, isTrue);
      expect(day.records, hasLength(1));
      expect(day.records.first.deviceTravelId, 'travel-1');
      expect(day.records.first.mileageLabel, '12.5km');
      expect(day.records.first.averageSpeedLabel, '25km/h');
      expect(point.hasCoordinate, isTrue);
      expect(point.latitude, 25.1);
      expect(point.longitude, 104.1);
    });
  });
}
