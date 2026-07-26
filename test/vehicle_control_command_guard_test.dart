import 'package:flutter_test/flutter_test.dart';

import 'helpers/source_scan.dart';

void main() {
  test('control home uses local BLE state and locks the command target', () {
    final source = readSource('lib/pages/cyber_vehicle_control_page_v2.dart');

    expect(source, contains('connectionManager.bikeStateStream.listen'));
    expect(source, contains('_ensureKnownControlState'));
    expect(source, contains('vehicleKeyAtSend'));
    expect(source, contains('车辆或控车渠道已变化，本次指令已取消'));
    // Official 3.5.9 keeps power slide and defence toggle as separate actions.
    expect(source, contains('_sendPowerToggle'));
    expect(source, contains('onPowerToggle'));
    expect(source, contains('onArmToggle'));
    expect(source, contains('SlidePowerButton'));
    expect(source, isNot(contains('SlideToUnlockButton')));
    // The power slider sends directly without an extra confirmation sheet.
    expect(source, isNot(contains('_PowerConfirmationSheet')));
    expect(source, isNot(contains('滑动启动')));
    expect(source, contains('resolveSelectedRemoteControlServiceDecision'));
    expect(source, contains('syncCarOperatorAfterCommand'));
  });
}
