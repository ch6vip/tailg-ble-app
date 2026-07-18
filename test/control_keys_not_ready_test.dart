import 'package:flutter_test/flutter_test.dart';

import 'helpers/source_scan.dart';

/// P0-A2: six-key path must never silently no-op when channel not ready.
void main() {
  test('vehicle control home surfaces reasons instead of silent no-op', () {
    final source = readSource('lib/pages/vehicle_control_home_page.dart');

    expect(source, contains("AppSnack.error(context, '正在执行控车指令，请稍候')"));
    expect(source, contains('当前不可控车，请检查蓝牙或网络'));
    expect(source, contains('dimmed:'));
    expect(source, isNot(contains('if (_busy) return;')));
    // Shortcuts stay tappable while dimmed so reason snacks can fire.
    expect(source, contains('enabled: true'));
    expect(source, contains('onTap: onTap'));
  });
}
