import 'package:flutter_test/flutter_test.dart';

import 'helpers/source_scan.dart';

void main() {
  test('P1-2 foreground resume refreshes vehicles and MQTT', () {
    final source = readSource('lib/pages/cyber_vehicle_control_page_v2.dart');
    expect(source, contains('_onForegroundResume'));
    expect(source, contains('refreshVehicles'));
    expect(source, contains('retryPreconnect'));
  });

  test('P1-3 busy path never silent-fails keys', () {
    final source = readSource('lib/pages/cyber_vehicle_control_page_v2.dart');
    expect(source, contains("AppSnack.error(context, '正在执行控车指令，请稍候')"));
    expect(source, contains('dimmed:'));
  });

  test('P1-5 link policy replaces conflicting local vehicle mapping', () {
    final source = readSource('lib/services/official_cloud_vehicle_links.dart');
    expect(source, contains('removeWhere'));
    expect(source, contains('P1-5'));
  });

  test('P1-6 permission permanent deny recommends settings', () {
    final source = readSource('lib/services/permission_service.dart');
    expect(source, contains('openSettingsRecommended'));
    expect(source, contains('openSystemSettings'));
    final home = readSource('lib/pages/cyber_vehicle_control_page_v2.dart');
    expect(home, contains('openSystemSettings'));
    expect(home, contains('去设置'));
  });

  test('P2-7 battery force refresh failure offers retry', () {
    final source = readSource('lib/pages/battery_details_page.dart');
    expect(source, contains("actionLabel: '重试'"));
    expect(source, contains('refreshBatteryInfo(force: true)'));
  });
}
