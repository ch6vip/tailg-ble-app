import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/ble/constants.dart';
import 'package:tailg_ble_app/ble/qgj_protocol.dart';
import 'package:tailg_ble_app/models/battery_snapshot.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';

void main() {
  test('BatterySnapshot maps bike state into battery details', () {
    final snapshot = BatterySnapshot.fromBikeState(
      const BikeState(
        isLocked: true,
        isPowerOn: false,
        voltage: 48.5,
        temperature: 26.2,
        batteryPercent: 80,
        signalStrength: -55,
      ),
    );

    expect(snapshot.hasData, isTrue);
    expect(snapshot.healthLabel, '正常');
    expect(snapshot.estimatedRangeKm, 52);
    expect(snapshot.faults, isEmpty);
    expect(snapshot.bms.soc, '80');
    expect(snapshot.bms.currentBatteryVoltage, '48.5');
    expect(snapshot.bms.socSource, BatteryDataSource.ble);
  });

  test('BatterySnapshot handles missing bike state without faults', () {
    final updatedAt = DateTime(2026, 6, 9, 10, 30);
    final snapshot = BatterySnapshot.fromBikeState(null, updatedAt: updatedAt);

    expect(snapshot.hasData, isFalse);
    expect(snapshot.faults, isEmpty);
    expect(snapshot.healthLabel, '等待数据');
    expect(snapshot.updatedAt, updatedAt);
  });

  test('BatterySnapshot uses injected clock for default timestamps', () {
    final generatedAt = DateTime(2026, 6, 9, 10, 30);
    final explicitUpdatedAt = DateTime(2026, 6, 9, 10, 45);

    final defaultTimestamp = BatterySnapshot.fromBikeState(
      null,
      clock: () => generatedAt,
    );
    final explicitTimestamp = BatterySnapshot.fromSources(
      updatedAt: explicitUpdatedAt,
      clock: () => generatedAt,
    );

    expect(defaultTimestamp.updatedAt, generatedAt);
    expect(explicitTimestamp.updatedAt, explicitUpdatedAt);
  });

  test('BatterySnapshot lists active bike faults in display order', () {
    final snapshot = BatterySnapshot.fromBikeState(
      const BikeState(
        isLocked: true,
        isPowerOn: false,
        faultMotor: true,
        faultController: true,
        faultBrake: true,
        faultLowVoltage: true,
      ),
    );

    expect(snapshot.faults, ['电机故障', '控制器故障', '刹车故障', '欠压保护']);
    expect(snapshot.healthLabel, '异常');
  });

  test('BmsSnapshot exposes official field structure without fake values', () {
    final snapshot = BatterySnapshot.fromBikeState(
      const BikeState(
        isLocked: true,
        isPowerOn: false,
        voltage: 48.5,
        batteryPercent: 80,
      ),
    );

    final fields = snapshot.bms.fields;
    expect(fields.map((field) => field.label), [
      '估算容量',
      'SOC',
      'SOH',
      '当前电压',
      '充电状态',
      '电池容量',
      '电池电流',
      '环境温度',
      '循环次数',
      '电池温度',
      '电池类型',
      '硬件版本',
      '软件版本',
    ]);
    expect(fields.first.displayValue, '待读取');
    expect(fields[1].displayValue, '80%');
    expect(fields[3].displayValue, '48.5V');
    expect(fields[8].displayValue, '待读取');
    fields.removeLast();
    expect(snapshot.bms.fields, hasLength(13));
  });

  test('BatterySnapshot uses official cloud vehicle as fallback', () {
    final snapshot = BatterySnapshot.fromSources(
      officialVehicle: _officialVehicle(
        electricQuantity: 66,
        voltage: 52.4,
        mileage: 1234.5,
      ),
    );

    expect(snapshot.percent, 66);
    expect(snapshot.voltage, 52.4);
    expect(snapshot.remainingMileage, '42.9');
    expect(snapshot.totalMileage, '1234.5');
    expect(snapshot.percentSource, BatteryDataSource.officialVehicle);
    expect(snapshot.voltageSource, BatteryDataSource.officialVehicle);
  });

  test(
    'BatterySnapshot uses official battery info and keeps BLE preferred',
    () {
      final officialBattery = OfficialBatteryInfo.fromJson({
        'dumpEnergyPercent': '68',
        'remainingMileage': '45',
        'mileage': '2000',
        'capacitance': '24Ah',
        'consumePowerPercent': '8',
        'loopCount': '12',
        'temperature': '31',
        'batteryScore': '95',
        'voltage': '52.2',
      });

      final cloudOnly = BatterySnapshot.fromSources(
        officialBatteryInfo: officialBattery,
      );
      expect(cloudOnly.percent, 68);
      expect(cloudOnly.voltage, 52.2);
      expect(cloudOnly.temperature, 31);
      expect(cloudOnly.remainingMileage, '45');
      expect(cloudOnly.capacitance, '24Ah');
      expect(cloudOnly.consumePowerPercent, '8');
      expect(cloudOnly.loopCount, '12');
      expect(cloudOnly.batteryScore, '95');
      expect(cloudOnly.percentSource, BatteryDataSource.officialBattery);
      expect(cloudOnly.bms.fields[0].displayValue, '24Ah');
      expect(cloudOnly.bms.fields[8].displayValue, '12');

      final blePreferred = BatterySnapshot.fromSources(
        bikeState: const BikeState(
          isLocked: true,
          isPowerOn: false,
          voltage: 48.5,
          temperature: 26.2,
          batteryPercent: 80,
        ),
        officialBatteryInfo: officialBattery,
      );
      expect(blePreferred.percent, 80);
      expect(blePreferred.voltage, 48.5);
      expect(blePreferred.temperature, 26.2);
      expect(blePreferred.percentSource, BatteryDataSource.ble);
      expect(blePreferred.voltageSource, BatteryDataSource.ble);
      expect(blePreferred.temperatureSource, BatteryDataSource.ble);
    },
  );

  test('BatterySnapshot selects mileage source by available data', () {
    final officialBattery = OfficialBatteryInfo.fromJson({
      'remainingMileage': '45',
    });

    final fromOfficialBattery = BatterySnapshot.fromSources(
      officialBatteryInfo: officialBattery,
      officialVehicle: _officialVehicle(mileage: 1234.5),
    );
    expect(fromOfficialBattery.remainingMileage, '45');
    expect(
      fromOfficialBattery.mileageSource,
      BatteryDataSource.officialBattery,
    );

    final fromOfficialVehicle = BatterySnapshot.fromSources(
      officialVehicle: _officialVehicle(mileage: 1234.5),
    );
    expect(fromOfficialVehicle.remainingMileage, isNull);
    expect(fromOfficialVehicle.totalMileage, '1234.5');
    expect(
      fromOfficialVehicle.mileageSource,
      BatteryDataSource.officialVehicle,
    );

    final fromBlePercent = BatterySnapshot.fromBikeState(
      const BikeState(isLocked: true, isPowerOn: false, batteryPercent: 80),
    );
    expect(fromBlePercent.remainingMileage, '52.0');
    expect(fromBlePercent.mileageSource, BatteryDataSource.ble);
  });

  test('BatterySnapshot falls back to reserved sources without data', () {
    final snapshot = BatterySnapshot.fromBikeState(
      null,
      updatedAt: DateTime(2026, 6, 9, 10, 30),
    );

    expect(snapshot.percentSource, BatteryDataSource.bmsReserved);
    expect(snapshot.voltageSource, BatteryDataSource.bmsReserved);
    expect(snapshot.temperatureSource, BatteryDataSource.bmsReserved);
    expect(snapshot.mileageSource, BatteryDataSource.bmsReserved);
  });

  test('BikeState compares by value', () {
    const first = BikeState(
      isLocked: true,
      isPowerOn: false,
      voltage: 48.5,
      temperature: 26.2,
      batteryPercent: 80,
      signalStrength: -55,
    );
    const second = BikeState(
      isLocked: true,
      isPowerOn: false,
      voltage: 48.5,
      temperature: 26.2,
      batteryPercent: 80,
      signalStrength: -55,
    );

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('BikeState parses feb3 fault bits as active high', () {
    final normal = BikeState.fromFeb3([
      0x00,
      0x00,
      0x00,
      0x01,
      0xE5,
      0x00,
      0xD0,
    ]);
    final faulted = BikeState.fromFeb3([
      0x00,
      0x00,
      0x00,
      0x01,
      0xE5,
      0x35,
      0xD0,
    ]);

    expect(normal?.voltage, 48.5);
    expect(normal?.batteryPercent, 80);
    expect(normal?.faultMotor, isFalse);
    expect(normal?.faultController, isFalse);
    expect(normal?.faultBrake, isFalse);
    expect(normal?.faultLowVoltage, isFalse);
    expect(faulted?.faultMotor, isTrue);
    expect(faulted?.faultController, isTrue);
    expect(faulted?.faultBrake, isTrue);
    expect(faulted?.faultLowVoltage, isTrue);
  });

  test('QGJ riding mode frame preserves fcc1 status bytes', () {
    final frame = buildQgjRidingModeFrame([
      0x00,
      0x07,
      0x00,
      0x02,
      0xA0,
      0xF8,
      0x05,
    ], RidingMode.sport);

    expect(frame, [0x00, 0x07, 0x00, 0x02, 0xA0, 0xFB, 0x05]);
    expect(parseQgjRidingMode(frame!), RidingMode.sport);
  });

  test('QGJ riding mode frame reads long fcc1 status notifications', () {
    final frame = buildQgjRidingModeFrame([
      0x85,
      0x08,
      0x4A,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0xB0,
      0xFA,
      0x06,
    ], RidingMode.eco);

    expect(frame, [0x00, 0x07, 0x00, 0x02, 0xB0, 0xF9, 0x06]);
    expect(parseQgjRidingMode(frame!), RidingMode.eco);
  });

  test('QGJ riding mode frame rejects incomplete fcc1 state', () {
    final incomplete = [0x00, 0x07, 0x00, 0x02, 0xA0, 0xF8];

    expect(buildQgjRidingModeFrame(incomplete, RidingMode.sport), isNull);
    expect(parseQgjRidingMode(incomplete), isNull);
  });

  test('QGJ login frame carries password and user id', () {
    final frame = buildQgjLoginFrame(password: 0x01020304, userId: 0x05060708);

    expect(frame, [
      0xA7,
      0x00,
      0x00,
      0x0A,
      0x10,
      0x01,
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
    ]);
  });
}

OfficialVehicle _officialVehicle({
  int? electricQuantity,
  double? voltage,
  double? mileage,
}) {
  return OfficialVehicle(
    imei: 'imei-1',
    imeiGps: '',
    carId: 'car-1',
    carName: 'TAILG',
    carNickName: '',
    carPhoto: '',
    frame: '',
    defenceStatus: 1,
    acc: 0,
    electricQuantity: electricQuantity,
    voltage: voltage,
    online: true,
    btname: '',
    btmac: '',
    longitude: '',
    latitude: '',
    modelType: null,
    mileage: mileage,
  );
}
