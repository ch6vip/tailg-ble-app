import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/battery_snapshot.dart';
import 'package:tailg_ble_app/models/official_vehicle.dart';

void main() {
  test('BatterySnapshot uses injected clock for default timestamps', () {
    final generatedAt = DateTime(2026, 6, 9, 10, 30);
    final explicitUpdatedAt = DateTime(2026, 6, 9, 10, 45);

    final defaultTimestamp = BatterySnapshot.fromSources(
      clock: () => generatedAt,
    );
    final explicitTimestamp = BatterySnapshot.fromSources(
      updatedAt: explicitUpdatedAt,
      clock: () => generatedAt,
    );

    expect(defaultTimestamp.updatedAt, generatedAt);
    expect(explicitTimestamp.updatedAt, explicitUpdatedAt);
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

  test('BatterySnapshot uses official battery info fields', () {
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
  });

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
  });

  test('BatterySnapshot falls back to reserved sources without data', () {
    final snapshot = BatterySnapshot.fromSources(
      updatedAt: DateTime(2026, 6, 9, 10, 30),
    );

    expect(snapshot.percentSource, BatteryDataSource.bmsReserved);
    expect(snapshot.voltageSource, BatteryDataSource.bmsReserved);
    expect(snapshot.temperatureSource, BatteryDataSource.bmsReserved);
    expect(snapshot.mileageSource, BatteryDataSource.bmsReserved);
  });

  test('BmsSnapshot exposes official field structure without fake values', () {
    final snapshot = BatterySnapshot.fromSources(
      officialVehicle: _officialVehicle(electricQuantity: 80, voltage: 48.5),
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
    isGps: null,
    mqHost: '',
    mqPort: '',
    mqUsername: '',
    mqPassword: '',
    mileage: mileage,
  );
}
