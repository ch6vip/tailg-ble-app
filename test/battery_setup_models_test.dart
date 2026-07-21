import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/models/battery_setup_models.dart';
import 'package:tailg_ble_app/services/official_cloud_service.dart';

void main() {
  test('OfficialBatteryType parses type/name and custom flag', () {
    final type = OfficialBatteryType.fromJson({'type': '0', 'name': '自定义'});
    expect(type.isCustom, isTrue);
    expect(type.isValid, isTrue);

    final lead = OfficialBatteryType.fromJson({'type': '2', 'name': '铅酸电池'});
    expect(lead.isCustom, isFalse);
  });

  test('OfficialBatterySpec parses code/spec', () {
    final spec = OfficialBatterySpec.fromJson({
      'code': 'S48-20',
      'spec': '48V20AH',
    });
    expect(spec.isValid, isTrue);
    expect(spec.code, 'S48-20');
  });

  test('AffirmBatteryInfoRequest builds official body keys', () {
    final catalog = AffirmBatteryInfoRequest(
      carId: 'car-1',
      batteryCode: 'S48-20',
      bindDate: '2026-07-01',
    ).toBody();
    expect(catalog['carId'], 'car-1');
    expect(catalog['batteryCode'], 'S48-20');
    expect(catalog['bindDate'], '2026-07-01');
    expect(catalog.containsKey('batteryType'), isFalse);

    final custom = AffirmBatteryInfoRequest(
      carId: 'car-1',
      batteryType: '0',
      batteryVoltage: '48',
      batteryCapacity: '20',
    ).toBody();
    expect(custom['batteryType'], '0');
    expect(custom['batteryVoltage'], '48');
    expect(custom['batteryCapacity'], '20');
  });

  test('OfficialCloudDataParser.batteryTypes filters invalid rows', () {
    final types = OfficialCloudDataParser.batteryTypes([
      {'type': '1', 'name': '锂电'},
      {'type': '', 'name': '坏数据'},
      {'type': '0', 'name': '自定义'},
    ]);
    expect(types.map((e) => e.type), ['1', '0']);
  });
}
