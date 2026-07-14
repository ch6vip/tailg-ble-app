import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailg_ble_app/services/sms_countdown.dart';

void main() {
  test('SmsCountdown ticks down to zero', () {
    FakeAsync().run((async) {
      final countdown = SmsCountdown(durationSeconds: 3);

      expect(countdown.isActive, isFalse);
      countdown.start();
      expect(countdown.remaining.value, 3);
      expect(countdown.isActive, isTrue);

      async.elapse(const Duration(seconds: 1));
      expect(countdown.remaining.value, 2);

      async.elapse(const Duration(seconds: 2));
      expect(countdown.remaining.value, 0);
      expect(countdown.isActive, isFalse);

      countdown.dispose();
    });
  });

  test('SmsCountdown cancels timer when isMounted is false', () {
    FakeAsync().run((async) {
      final countdown = SmsCountdown(durationSeconds: 5);

      var mounted = true;
      countdown.start(isMounted: () => mounted);
      expect(countdown.remaining.value, 5);

      mounted = false;
      async.elapse(const Duration(seconds: 1));
      // Timer cancelled on unmount, so value stays at the last set value.
      expect(countdown.remaining.value, 5);

      countdown.dispose();
    });
  });
}
