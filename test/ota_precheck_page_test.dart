import 'package:flutter_test/flutter_test.dart';

import 'helpers/source_scan.dart';

void main() {
  test('OTA precheck waits for ready state before reading GATT data', () {
    final source = readSource('lib/pages/ota_precheck_page.dart');
    final methodStart = source.indexOf('Future<void> _runCheck() async');
    final readyGuard = source.indexOf(
      'if (connectionManager.state != ble.ConnectionState.ready) return;',
      methodStart,
    );
    final gattRead = source.indexOf(
      'connectionManager.runGattOperation',
      methodStart,
    );

    expect(methodStart, greaterThanOrEqualTo(0));
    expect(readyGuard, greaterThan(methodStart));
    expect(gattRead, greaterThan(readyGuard));
    expect(
      source,
      isNot(
        contains(
          'if (connectionManager.state == ble.ConnectionState.disconnected) return;',
        ),
      ),
    );
  });
}
