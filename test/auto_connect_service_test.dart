import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/auto_connect_service.dart';

void main() {
  group('AutoConnectRunGate', () {
    test('coalesces concurrent runs into one operation', () async {
      final gate = AutoConnectRunGate();
      final completer = Completer<void>();
      var calls = 0;

      final first = gate.run(() {
        calls += 1;
        return completer.future;
      });
      final second = gate.run(() {
        calls += 1;
        return Future.value();
      });

      expect(identical(first, second), isTrue);
      expect(calls, 1);
      expect(gate.isRunning, isTrue);

      completer.complete();
      await first;

      expect(gate.isRunning, isFalse);
    });

    test('releases the gate after operation failure', () async {
      final gate = AutoConnectRunGate();
      var calls = 0;

      await expectLater(
        gate.run(() {
          calls += 1;
          throw StateError('scan failed');
        }),
        throwsStateError,
      );

      expect(gate.isRunning, isFalse);

      await gate.run(() async {
        calls += 1;
      });

      expect(calls, 2);
    });
  });
}
