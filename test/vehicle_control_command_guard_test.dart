import 'package:flutter_test/flutter_test.dart';

import 'helpers/source_scan.dart';

void main() {
  test('control home uses local BLE state and locks the command target', () {
    final source = readSource('lib/pages/vehicle_control_home_page.dart');

    expect(source, contains('connectionManager.bikeStateStream.listen'));
    expect(source, contains('_ensureKnownControlState'));
    expect(source, contains('vehicleKeyAtSend'));
    expect(source, contains('车辆或控车渠道已变化，本次指令已取消'));
    // Power on/off is immediate — no slide-to-start confirmation sheet.
    expect(source, isNot(contains('_PowerConfirmationSheet')));
    expect(source, isNot(contains('滑动启动')));
  });
}
